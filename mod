#!/usr/bin/env python

import argparse
import zipfile
import os, shutil
import py_compile

parser = argparse.ArgumentParser(description='Bundle a Python application')

parser.add_argument(dest='action',metavar='ACTION',type=str,help='Action mod should take')
parser.add_argument(dest='root', metavar='PROJECT', type=str, help='Project path',nargs='?', default='.')
parser.add_argument('-o','--output',metavar='OUTPUT FILE',dest='file_name',type=str,default=None)
parser.add_argument('--extensions','--ext',action='store_const',metavar='EXTENSIONS',dest='extensions',const=True,default=False,help='Whether to allow the importing of C extensions (not needed if C extensions are optional')

args = parser.parse_args()

project_root=os.path.abspath(args.root) #Path of the project directory

project_name=os.path.relpath(project_root,os.path.dirname(project_root)) #Name of the main module in the project. Defined as the name of the project folder (last part of its path)

if not args.file_name:
    args.file_name=os.path.join(project_root,project_name) #By default, the output file has the same name as the project_name, and will be in the project directory 
    
file_name=args.file_name

extensions=args.extensions #Whether to support C extensions. By default, it will not

def build():
    
    output_file=open(file_name,"w+")
    output_file.write("#! /usr/bin/env python\n") #Add shebang to support running without prefixing python
    output_file.close() #Can't open file with zipfile without closing the file first
    
    def make_executable(path):
        mode = os.stat(path).st_mode
        mode |= (mode & 0o444) >> 2    # copy R bits to X
        os.chmod(path, mode)
        
    make_executable(file_name) #So you can actually run it
    
    output_file=zipfile.ZipFile(file_name,'a') #Append, as otherwise, it will overwrite the shebang
    
    def add_folder_to_zipapp(real_folder,zip_folder=None): #real_folder is the directory in the project root, and zip_folder is where the folder the file should be in the zip
    
        if zip_folder is None:
            zip_folder=real_folder #Default to using real_folder
        
        files=[os.path.join(dp, f) for dp, dn, filenames in os.walk(os.path.join(project_root,real_folder),followlinks=True) for f in filenames] #Get all files in real_folder
        
        files=[os.path.relpath(_,os.path.join(project_root,real_folder)) for _ in files if os.path.splitext(_)[1] not in [".pyc",".whl"] and not os.path.dirname(_).endswith(".dist-info")] #Remove unneccessary folders and files
        
        for file in files:
            _input_file=os.path.join(project_root,real_folder,file)
            _output_file=os.path.join(project_name,zip_folder,file)
            
            if extensions: #Make _extensions folder to put Cython modules in, according to the paths 
                if file.endswith(".so") or ".so." in file:
                    os.makedirs(os.path.join(project_root,"_extensions",zip_folder,os.path.dirname(file)),exist_ok=True)
                    shutil.copyfile(_input_file,os.path.join(project_root,"_extensions",zip_folder,file))
                    continue
                
            #Compile py to pyc to start up faster (otherwise, zipimport will compile all the files again)
            if file.endswith(".py"):
                
                py_compile.compile(_input_file,cfile="temp.pyc",dfile=os.path.join("$ROOT$",project_name,zip_folder,file)) #Possibly replace this with joining the path with r'/\' for dfile. This is so that tracebacks will look at the correct .py file instead of finding nothing
                
                _input_file="temp.pyc"
                _output_file=_output_file[:-3]+".pyc"
            output_file.write(_input_file,arcname=_output_file)
    
            if file.endswith(".py"): #Add the py files for tracebacks
                _input_file=os.path.join(project_root,real_folder,file)
                _output_file=os.path.join(project_name,zip_folder,file)
                output_file.write(_input_file,arcname=_output_file)
                
    add_folder_to_zipapp("_vendor")
    add_folder_to_zipapp("src","")
    
    def init_template():
        import os, sys
        
        dir_path=os.path.abspath(os.path.dirname(__file__)) #Path of the folder of _vendor and wrapped module
        
        zip_path=os.path.dirname(os.path.abspath(os.path.dirname(__file__))) #Path of zip file
        
        
        import zipfile
        from copy import copy
        import builtins
        import importlib
        from importlib import abc
        import types
        
        Zipfile=zipfile.ZipFile(zip_path)
        
        def is_path_in_zipfile(path):
            #Maybe support parameter mode, so redirect to empty file if writing. Make wrapper around common os functions all just getting new file and passing it in.
            result=[]
            if not isinstance(path,int):
                path=os.path.abspath(path)
                
            if not isinstance(path,int) and path!=zip_path and path.startswith(zip_path+os.sep):
                path=os.path.relpath(path,zip_path)
                result.append(True) #Whether path is in zipfile
            else:
                result.append(False)
                
            result.append(path)
            return result
            
        old_open=copy(open)
        @staticmethod #Allows for use in classes
        def new_open(*args,**kwargs):
            path=args[0]
            if len(args)>1:
                mode=args[1]
            elif 'mode' in kwargs:
                mode=kwargs['mode']
            else:
                mode='r'
                
            path=is_path_in_zipfile(path)
            if not path[0]:
                return old_open(*args,**kwargs)
            else:
                return zipfile.Path(Zipfile,path[1]).open(mode)
        
        builtins.open=new_open
        import io
        io.open=new_open
        importlib.reload(sys.modules['pathlib']) #So it picks up new io
        importlib.reload(sys.modules['tokenize']) #So it picks up new io
        
        
        
        old_makedirs=os.makedirs
        @staticmethod
        def new_makedirs(*args,**kwargs):
            path=args[0]
            path=is_path_in_zipfile(path)
            
            if not path[0]:
                return old_makedirs(*args,**kwargs)
            else:
                return old_makedirs(path[1],exist_ok=True)
        #os.makedirs=new_makedirs
        
        old_listdir=os.listdir
        @staticmethod
        def new_listdir(*args,**kwargs):
            path=args[0]
            path=is_path_in_zipfile(path)
            
            if not path[0]:
                return old_listdir(*args,**kwargs)
            else:
                return [os.path.relpath(_,path[1]) for _ in Zipfile.namelist() if _.startswith(path[1]) ]
        #os.listdir=new_listdir
        
        old_stat=copy(os.stat)
        @staticmethod
        def new_stat(*args,**kwargs):
            path=args[0]
            path=is_path_in_zipfile(path)
            if not path[0]:
                return old_stat(*args,**kwargs)
            else:
                if path[1] in Zipfile.namelist():
                    return old_stat(zip_path)
                else:
                    raise FileNotFoundError
        os.stat=new_stat
        

        old_unmarshal=sys.modules['zipimport']._unmarshal_code
        def new_unmarshal(*args,**kwargs): #Rewrite co_filename to match path inside zip for tracebacks
            code=old_unmarshal(*args,**kwargs)
            def _overwrite_co_filename(_code):
                filename=_code.co_filename
                if filename.startswith("$ROOT$"):
                    filename=filename.replace("$ROOT$",zip_path,1)
                else:
                    return _code
                _code=_code.replace(co_filename=filename.replace("$ROOT$",zip_path,1))
                consts=list(_code.co_consts)
                for i,const in enumerate(consts):
                    if isinstance(const,types.CodeType):
                        consts[i]=_overwrite_co_filename(const)
                _code=_code.replace(co_consts=tuple(consts))
                return _code
            code=_overwrite_co_filename(code)
            return code
        sys.modules['zipimport']._unmarshal_code=new_unmarshal

        #Finds C extensions in 'extensions' folder and returns it 
        class ExtensionLoader(importlib.abc.Loader):
            def create_module(spec):
                self.spec=spec
                return importlib.util.module_from_spec(spec)
            
            def exec_module(module):
                self.spec.loader.exec_module(module)
        
        class ExtensionFinder():
            def find_spec(self,fullname, path, target=None):
                extensions_dir=os.path.join(os.path.dirname(zip_path),"_extensions")
                extension_filter=os.path.join(extensions_dir,'**',fullname.replace(".",os.sep)+".*.so")
                import fnmatch
                try:
                    extensions_dir_files=[os.path.join(dp, f) for dp, dn, fn in os.walk(extensions_dir) for f in fn]
                    extension_path=fnmatch.filter(extensions_dir_files,extension_filter)[0]
                except:
                    return
                
                if os.path.exists(extension_path):
                    return importlib.util.spec_from_file_location(fullname,extension_path)
        sys.meta_path.append(ExtensionFinder())
        
        def mod_main():
            import importlib,sys
            try:
                import runpy
                runpy.run_module("NAME.__main__",run_name="__main__") #Run function provided in __main__.py
            except: #__main__.py doesn't exist
                import NAME
                NAME.main() #Run main function provided in the actual module
                
        import importlib,sys
        sys.path.insert(0,os.path.join(dir_path,"_vendor")) #So third-party modules can be imported
        sys.path.insert(0,dir_path)
        importlib.reload(sys.modules['NAME']) #Load actual module
        globals().update(sys.modules['NAME'].__dict__)
    
    def main_template(): #Just runs __init__.py
        import os,sys,traceback
        sys.excepthook = traceback.print_exception #Arcane incantation required to get tracebacks working. Python's C traceback doesn't work, but the Python traceback module does, so use that.
        
        sys.path.insert(0,os.path.abspath(os.path.dirname(__file__))) #So the wrapper module is imported instead.
        
        import NAME #Import wrapper
        NAME.mod_main() #Run function
    
    def write_function_to_zip(function,file):
        import inspect
        import textwrap
        source=inspect.getsourcelines(function)[0][1:]
        source=textwrap.dedent("".join(source).replace("NAME",project_name))
        output_file.writestr(file,source)
    write_function_to_zip(main_template,"__main__.py")
    
    write_function_to_zip(init_template,os.path.join(project_name,"__init__.py"))
    

globals()[args.action]()