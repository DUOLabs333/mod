#!/usr/bin/env python

import argparse
import zipfile
import os
parser = argparse.ArgumentParser(description='Bundle a Python application')

parser.add_argument(dest='action',metavar='VERB',type=str,help='Action mod should take')
parser.add_argument(dest='root', metavar='FOLDER', type=str, help='Root of folder',nargs='?', default='.')
parser.add_argument(dest='file_name',metavar='APP',type=str,nargs='?',default=None)
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
        
        files=[os.path.relpath(_,os.path.join(project_root,real_folder)) for _ in files]
        
        for file in files:
            file_zip.write(os.path.join(project_root,real_folder,file),arcname=os.path.join(zip_folder,file))
    
    add_folder_to_zip("_vendor")
    add_folder_to_zip("src","")
    
    def template():
        import os, sys
        
        zip_path=os.path.abspath(os.path.dirname(__file__))
        sys.path.insert(0,os.path.join(zip_path,"_vendor"))
        
        import zipfile
        import copy
        import builtins
        import importlib
        
        Zipfile=zipfile.ZipFile(zip_path)
        
        old_open=open
        import pathlib
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
                
        new_open=staticmethod(new_open) #Allows for use in functions
        
        builtins.open=new_open
        import io
        io.open=new_open
        
        importlib.reload(sys.modules['pathlib']) #So it picks up new io

        import NAME
        
        if __name__=="__main__":
            NAME.main()
        else:
             globals().update(NAME.__dict__)
        
    import inspect
    import textwrap
    source=inspect.getsourcelines(template)[0][1:]
    source=textwrap.dedent("".join(source).replace("NAME",project_name))
    file_zip.writestr("__main__.py",source)
    file_zip.writestr("__init__.py",source)
    

globals()[args.action]()