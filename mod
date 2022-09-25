#!/usr/bin/env python

import argparse
import zipfile
import os
import py_compile

parser = argparse.ArgumentParser(description='Bundle a Python application')

parser.add_argument(dest='action',metavar='ACTION',type=str,help='Action mod should take')
parser.add_argument(dest='root', metavar='PROJECT', type=str, help='Project path',nargs='?', default='.')
parser.add_argument('--output',metavar='OUTPUT FILE',dest='file_name',type=str,default=None)
args = parser.parse_args()

project_root=os.path.abspath(args.root)

project_name=os.path.relpath(project_root,os.path.dirname(project_root))

if not args.file_name:
    args.file_name=os.path.join(project_root,project_name)
    
file_name=args.file_name
def build():
    
    file_zip=open(file_name,"w+")
    file_zip.write("#! /usr/bin/env python\n")
    file_zip.close()
    
    def make_executable(path):
        mode = os.stat(path).st_mode
        mode |= (mode & 0o444) >> 2    # copy R bits to X
        os.chmod(path, mode)
    make_executable(file_name)
    file_zip=zipfile.ZipFile(file_name,'a')
    def add_folder_to_zip(real_folder,zip_folder=None):
        if zip_folder is None:
            zip_folder=real_folder
        
    
        files=[os.path.join(dp, f) for dp, dn, filenames in os.walk(os.path.join(project_root,real_folder),followlinks=True) for f in filenames]
        
        files=[os.path.relpath(_,os.path.join(project_root,real_folder)) for _ in files if os.path.splitext(_)[1] not in [".pyc",".whl"] and not os.path.dirname(_).endswith(".dist-info")] #Unneccessary
        
        for file in files:
            input_file=os.path.join(project_root,real_folder,file)
            output_file=os.path.join(zip_folder,file)
            
            #Compile py to pyc to start up faster (otherwise, zipimport will compile all the files again)
            if file.endswith(".py"):
                py_compile.compile(input_file,cfile="temp.pyc")
                input_file="temp.pyc"
                output_file=output_file[:-3]+".pyc"
            file_zip.write(input_file,arcname=output_file)
    
    add_folder_to_zip("_vendor",os.path.join(project_name,"_vendor"))
    add_folder_to_zip("src",project_name)
    
    def init_template():
        import os, sys
        
        dir_path=os.path.abspath(os.path.dirname(__file__)) #Path of the modules and main module
        zip_path=os.path.dirname(os.path.abspath(os.path.dirname(__file__))) #Path of zip file
        
        sys.path.insert(0,os.path.join(dir_path,"_vendor"))
        sys.path.insert(0,dir_path)
        
        import zipfile
        import copy
        import builtins
        import importlib
        
        Zipfile=zipfile.ZipFile(zip_path)
        
        old_open=open
        import pathlib
        
        @staticmethod #Allows for use in classes
        def new_open(*args,**kwargs):
            path=args[0]
            if len(args)>1:
                mode=args[1]
            elif 'mode' in kwargs:
                mode=kwargs['mode']
            else:
                mode='r'
            if not isinstance(path,int):
                path=os.path.abspath(path)
            if not isinstance(path,int) and path!=zip_path and path.startswith(zip_path+os.sep):
                path=os.path.relpath(path,zip_path)
                return Zipfile.open(path,mode=mode)
            else:
                return old_open(*args,**kwargs)
        
        builtins.open=new_open
        import io
        io.open=new_open
        
        importlib.reload(sys.modules['pathlib']) #So it picks up new io
        
        def main():
            #Switch to actual module
            import importlib,sys
            importlib.reload(sys.modules['NAME'])
            sys.path.insert(0,dir_path)
            import NAME
            NAME.main()
        
        import importlib,sys
        importlib.reload(sys.modules['NAME'])
        sys.path.insert(0,dir_path)
        import NAME
        globals().update(NAME.__dict__)
    
    def main_template(): #Just runs __init__.py
        import os,sys
        sys.path.insert(0,os.path.abspath(os.path.dirname(__file__)))
        import NAME
        NAME.main()  
    
    def write_function_to_zip(function,file):
        import inspect
        import textwrap
        source=inspect.getsourcelines(function)[0][1:]
        source=textwrap.dedent("".join(source).replace("NAME",project_name))
        file_zip.writestr(file,source)
    write_function_to_zip(main_template,"__main__.py")
    
    write_function_to_zip(init_template,os.path.join(project_name,"__init__.py"))
    

globals()[args.action]()