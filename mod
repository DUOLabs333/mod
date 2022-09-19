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
        
    
        files=[os.path.join(dp, f) for dp, dn, filenames in os.walk(os.path.join(project_root,real_folder)) for f in filenames]
        
        files=[os.path.relpath(_,os.path.join(project_root,real_folder)) for _ in files]
        
        for file in files:
            file_zip.write(os.path.join(project_root,real_folder,file),arcname=os.path.join(zip_folder,file))
    
    add_folder_to_zip("_vendor")
    add_folder_to_zip("src","")
    
    def main_py_template():
        import os, sys
        import zipfile
        import copy
        import builtins
        zip_path=os.path.dirname(__file__)
        Zipfile=zipfile.ZipFile(zip_path)
        
        old_open=copy.copy(open)
        def new_open(path,mode='r'):
            path=os.path.abspath(path)
            if path.startswith(zip_path) or path.startswith(zip_path+os.sep):
                path=os.path.relpath(path,zip_app)
                return Zipfile.open(path)
            else:
                return old_open(path,mode)
        
        builtins.open=new_open
        
        sys.path.insert(0,os.path.join(zip_path,"_vendor"))
        
        import NAME
        
        if __name__=="__main__":
            NAME.main()
    
    def init_py_template():
        import NAME
        globals().update(NAME)
        
    def write_function_to_file(function,file):
        import inspect
        import textwrap
        source=inspect.getsourcelines(function)[0][1:]
        source=textwrap.dedent("".join(source).replace("NAME",project_name))
        file_zip.writestr(file,source)
    
    write_function_to_file(main_py_template,"__main__.py")
    write_function_to_file(init_py_template,"__init__.py")

globals()[args.action]()