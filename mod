#!/usr/bin/env python

import argparse
import zipfile
import os, shutil
import py_compile

parser = argparse.ArgumentParser(description='Bundle a Python application')
parser.add_argument('-o','--output',metavar='OUTPUT FILE',dest='file_name',type=str,default=None)
parser.add_argument('--extensions','--ext',action='store_const',dest='extensions',const=True,default=False,help='Whether to allow the importing of C extensions (not needed if C extensions are optional')

actions_parser=parser.add_subparsers(dest='action',metavar='ACTION',help='Action mod should take')
actions_parser.required=True

build_parser=actions_parser.add_parser("build")
build_parser.add_argument(dest='root', metavar='PROJECT', type=str, help='Project path',nargs='?', default='.')

get_parser=actions_parser.add_parser("get")
get_parser.add_argument(dest='module', metavar='MODULE', type=str, help='Module to download')
get_parser.add_argument('--bin',dest='bin',type=str,help='Binary from module to install',default=None)
get_parser.add_argument('--no-deps',action='store_const',dest='deps',const=False,default=True)
get_parser.add_argument('--setup-only',action='store_const',dest='setup_only',const=True,default=False)

args = parser.parse_args()





def build():
    project_root=os.path.abspath(args.root) #Path of the project directory
    
    project_name=os.path.relpath(project_root,os.path.dirname(project_root)) #Name of the main module in the project. Defined as the name of the project folder (last part of its path)
    
    if not args.file_name:
        args.file_name=os.path.join(project_root,project_name) #By default, the output file has the same name as the project_name, and will be in the project directory 
         
    file_name=args.file_name
     
    extensions=args.extensions #Whether to support C extensions. By default, it will not
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
        
        subfolders=[os.path.join(project_root,real_folder)]
        files=[]
        
        for folder in subfolders:
            for path in os.scandir(folder):
                if path.is_dir() and not os.path.dirname(path.path).endswith(".dist-info"):
                    subfolders.append(path.path)
                elif path.is_file() and os.path.splitext(path.path)[1] not in [".pyc",".whl"]:
                    files.append(os.path.relpath(path.path,os.path.join(project_root,real_folder)))
        
        
        subfolders=[os.path.relpath(_,os.path.join(project_root,real_folder)) for _ in subfolders]
        subfolders[0]=""
        for file in files:
            _input_file=os.path.join(project_root,real_folder,file)
            _output_file=os.path.join(project_name,zip_folder,file)
            
           
            if file.endswith(".so") or ".so." in file:
                 if extensions: #Make _extensions folder to put Cython modules in, according to the paths
                    os.makedirs(os.path.join(project_root,"_extensions",zip_folder,os.path.dirname(file)),exist_ok=True)
                    shutil.copyfile(_input_file,os.path.join(project_root,"_extensions",zip_folder,file))
                 continue
                
            #Compile py to pyc to start up faster (otherwise, zipimport will compile all the files again)
            if file.endswith(".py"):
                try:
                    py_compile.compile(_input_file,cfile="temp.pyc",dfile=os.path.join("$ROOT$",project_name,zip_folder,file),doraise=True) #Possibly replace this with joining the path with r'/\' for dfile. This is so that tracebacks will look at the correct .py file instead of finding nothing
                    
                    _input_file="temp.pyc"
                    _output_file=_output_file[:-3]+".pyc"
                except py_compile.PyCompileError:
                    _input_file=''
            if _input_file:
                output_file.write(_input_file,arcname=_output_file)
    
            if file.endswith(".py"): #Add the py files for tracebacks
                _input_file=os.path.join(project_root,real_folder,file)
                _output_file=os.path.join(project_name,zip_folder,file)
                output_file.write(_input_file,arcname=_output_file)

        for folder in subfolders: #Add empty directories to zip files to support namespace packages
            output_file.writestr(zipfile.ZipInfo(os.path.join(project_name,zip_folder,folder)+("" if folder=="" else "/")),"")
            pass     
    add_folder_to_zipapp("_vendor")
    add_folder_to_zipapp("src","")
    
    def setup_template():
        import os, sys
        
        dir_path=os.path.abspath(os.path.dirname(__file__)) #Path of the folder of _vendor and wrapped module
        
        zip_path=os.path.dirname(os.path.abspath(os.path.dirname(__file__))) #Path of zip file
        zip_stat=os.stat(zip_path)
        zip_stat_class=type(zip_stat)
        zip_stat=list(zip_stat)
        
        import zipfile
        from copy import copy
        import builtins
        import importlib
        from importlib import abc
        import types
        import stat
        import errno
        import glob
        
        Zipfile=zipfile.ZipFile(zip_path)
        
        zip_filelist=set(Zipfile.namelist())
        
        old_stat=copy(os.stat)
        import functools
        
        def is_path_in_zipfile(path):
            #Maybe support parameter mode, so redirect to empty file if writing. Make wrapper around common os functions all just getting new file and passing it in.
            result=[]
            _path=path
            if isinstance(path,int):
                return [False,path]
                
            path=os.path.abspath(path)
                
            if (path!=zip_path and path.startswith(zip_path+os.sep)):
                path=os.path.relpath(path,zip_path)
                result.append(True) #Whether path is in zipfile
            else:
                result.append(False)
                
            result.append(path)
            
            if result[0]:
                if result[1] not in zip_filelist:
                    if result[1]+'/' in zip_filelist:
                        result[1]+='/'
                    else:
                       raise FileNotFoundError(errno.ENOENT, os.strerror(errno.ENOENT), os.path.join(zip_path,result[1]))
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
        sys.modules['_io'].open=new_open
        
        old_listdir=os.listdir
        zip_listdir=[_.rstrip('/') for _ in zip_filelist]
        
        @staticmethod
        @functools.cache
        def new_listdir(*args,**kwargs):
            path=args[0]
            path=is_path_in_zipfile(path)
            
            if not path[0]:
                return old_listdir(*args,**kwargs)
            else:
                return [os.path.relpath(_,path[1]) for _ in zip_listdir if _.startswith(path[1]) and _.rstrip('/').count('/')==path[1].count('/') ]
        os.listdir=new_listdir
        
        file_stats={} #Cache stat of files in Zipfile
        old_stat=copy(os.stat)

        @staticmethod
        def new_stat(*args,**kwargs):
            path=args[0]
            path=is_path_in_zipfile(path)
            if not path[0]:
                args=list(args)
                args[0]=path[1]
                args=tuple(args)
                return old_stat(*args,**kwargs)
            else:
                if path[1] not in file_stats:
                    file_stats[path[1]]=[]
                    fileobj=Zipfile.open(path[1])
                    fileobj.seek(0,os.SEEK_END)
                    fileSize=fileobj.tell()
                    file_stats[path[1]].append([stat.ST_SIZE,fileSize])
                    fileobj.close()
                    
                    file_stats[path[1]].append([stat.ST_MODE, stat.S_IFDIR if zipfile.Path(Zipfile,path[1]).is_dir() else stat.S_IFREG])
                filestat=zip_stat.copy()
                for i in file_stats[path[1]]:
                    filestat[i[0]]=i[1]
            
                return zip_stat_class(filestat)
        os.stat=new_stat
        
        importlib.reload(sys.modules['pathlib']) #So it picks up new io and os
        importlib.reload(sys.modules['tokenize']) #So it picks up new io and os

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
                    if isinstance(const,types.CodeType) and const.co_filename.startswith("$ROOT$"):
                        consts[i]=_overwrite_co_filename(const)
                _code=_code.replace(co_consts=tuple(consts))
                return _code
            code=_overwrite_co_filename(code)
            return code
        sys.modules['zipimport']._unmarshal_code=new_unmarshal
        
        import runpy
        old_run_module=copy(runpy._run_module_as_main)
        def new_run_module(*args,**kwargs):
            if not is_path_in_zipfile(sys.path[0]):
                old_run_module(*args,**kwargs)
            else:
                exec(open(sys.path[0]).read(),globals())
        runpy._run_module_as_main=new_run_module
        del sys.modules['importlib._bootstrap_external']
        importlib.reload(sys.modules['importlib']) #Reload runpy
        
        #Finds C extensions in 'extensions' folder and returns the path to be used to be imported by normal Python machinery
        class ExtensionFinder():
            def find_spec(self,fullname, path, target=None):
                extensions_dir=os.path.join(os.path.dirname(zip_path),"_extensions")
                extension_filter=os.path.join('*',fullname.replace(".",os.sep)+".*.so")
                try:
                    extension_path=os.path.join(extensions_dir,glob.glob(extension_filter,root_dir=extensions_dir)[0])
                except:
                    return
                if os.path.exists(extension_path):
                    return importlib.util.spec_from_file_location(fullname,extension_path)
        if 1:
            import importlib.metadata
            class CustomDistribution(importlib.metadata.Distribution):
                def __init__(self,name):
                    import fnmatch
                    self.dist_path=fnmatch.filter(new_listdir(dir_path+"/_vendor"),name.replace("-","_")+"-*.dist-info")[0]
                def read_text(self, filename):
                    return open('/'.join([dir_path,"_vendor",self.dist_path,filename])).read()
    
            class DistributionFinder(importlib.metadata.DistributionFinder):
                def find_spec(self,*args,**kwargs): #There's nothing to offer here, so just return nothing
                    return
                def find_distributions(self,context): #Since importlib.metadata doesn't support subdirectories
                    if context.name:
                        return [CustomDistribution(context.name)]
                    else:
                        return []
            sys.meta_path.insert(0,DistributionFinder())
            
        class UnionException(ImportError):
            def __init__(self,oserror):
                self.oserror=oserror
                super().__init__()
            def __repr__(self):
                return repr(self.oserror)
            def __str__(self):
                return str(self.oserror)
                
        old_exec_module=copy(__loader__.__class__.exec_module)
        def new_exec_module(*args,**kwargs):
            try:
                return old_exec_module(*args,**kwargs)
            except OSError as e: #So that modules that fail to import due to missing so files will just recieve an ImportError
                raise UnionException(e)
        __loader__.__class__.exec_module=new_exec_module
        sys.meta_path.insert(0,ExtensionFinder()) #Run this before anything else, otherwise, some extensions will not be imported
        sys.path.append(os.path.join(dir_path,"_vendor")) #So third-party modules can be imported
        sys.path.insert(0,dir_path)
        def mod_main():
            import importlib,sys,os
            if os.path.isfile(os.path.join(dir_path,"NAME","__main__.py")):
                import runpy
                runpy.run_module("NAME.__main__",run_name="__main__") #Run function provided in __main__.py
            else: #__main__.py doesn't exist
                import NAME
                NAME.main() #Run main function provided in the actual module
        os.environ['PYTHONPATH']=os.getenv('PYTHONPATH','')+os.pathsep+dir_path #So subprocesses will pick up the setup code

    def init_template():
        import NAME.usercustomize
        mod_main=NAME.usercustomize.mod_main                  
        import importlib,sys
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
    write_function_to_zip(setup_template,os.path.join(project_name,"usercustomize.py"))
    
def get():
    import tempfile, shutil
    import subprocess
    with tempfile.TemporaryDirectory() as buildpath:
        module=args.module.split("[")[0]
        normalized_module=module.replace("-","_")
        old_cwd=os.getcwd()
        os.chdir(buildpath)
        binary=args.bin or module
        subprocess.run(["pip","install"]+(["--no-deps"] if not args.deps else [])+["-t",os.path.join(normalized_module,"_vendor"),args.module])
        os.chdir(normalized_module)
        if os.path.isdir(os.path.join("_vendor",normalized_module)):
            os.makedirs("src")
            shutil.move(os.path.join("_vendor",normalized_module),"src")
        elif os.path.isfile(os.path.join("_vendor",normalized_module+".py")): #Support packages that is a single file
            os.makedirs(os.path.join("src",normalized_module),exist_ok=True)
            os.rename(os.path.join("_vendor",normalized_module+".py"),os.path.join("src",normalized_module,"__init__.py"))
        if os.path.isfile(os.path.join("_vendor","bin",binary)): #Support packages that don't have a __main__ file
            os.makedirs(os.path.join("src",normalized_module),exist_ok=True)
            if not os.path.isfile(os.path.join("src",normalized_module,"__main__.py")): #Don't overwrite __main__.py --- it is the priority
                os.rename(os.path.join("_vendor","bin",binary),os.path.join("src",normalized_module,"__main__.py"))
            with open(os.path.join("src",normalized_module,"__init__.py"),"a+") as f: #Makes file if it doesn't exist
                pass
        if args.setup_only:
            os.chdir(buildpath)
            shutil.copytree(normalized_module,os.path.join(old_cwd,normalized_module))
        else:
            args.root='.'
            args.module=module
            build()
            shutil.move(normalized_module,os.path.join(old_cwd,binary))
            if args.extensions:
                shutil.copytree("_extensions",os.path.join(old_cwd,"_extensions"))
globals()[args.action]()
