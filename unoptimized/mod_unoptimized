#!/usr/bin/env python

import sys
import os
import pathlib
import string
import random
import re
import hashlib
import textwrap
import itertools
import base64
MODULES_PATH=os.getenv("MODULES_PATH",f"{os.environ['HOME']}/Modules")
def split_string_by_char(string,char=':'):
    PATTERN = re.compile(rf'''((?:[^\{char}"']|"[^"]*"|'[^']*')+)''')
    return [_ for _ in list(PATTERN.split(string)) if _ not in ['', char]]

def extract_arguments():
    arguments=sys.argv[1:]
    try:
        FUNCTION=arguments[0]
    except IndexError:
        print("No function specified!")
        exit()
    if arguments[0].startswith("--"):
        print("No function specified!")
        exit()
    arguments=arguments[1:]
    NAMES=[]
    FLAGS=arguments
    for i in range(len(arguments)):
        if not arguments[i].startswith("--"):
            FLAGS=arguments[:i]
            NAMES=arguments[i:]
            break
    return (NAMES,FLAGS,FUNCTION)

#Get files to compile
files, flags, function = extract_arguments()

#Get absolute path of files
files=[os.path.abspath(_) for _ in files]

def make_executable(path):
    mode = os.stat(path).st_mode
    mode |= (mode & 0o444) >> 2    # copy R bits to X
    os.chmod(path, mode)

#Check if line is an "include" line
def check_if_include_line(string):
    prefix="# < include "
    indentation=''.join(itertools.takewhile(str.isspace,string))
    string=string.strip()
    if string.startswith(prefix) and string.endswith(" >"):
        string=string.removeprefix(prefix).removesuffix(" >")
        return indentation, split_string_by_char(string," ")
    else:
        return '',False
def check_if_module_is_already_compiled(path,module_type):
    name=pathlib.Path(path).stem
    if module_type=="absolute":
        if os.path.isfile(f"./{name}.pyo"):
            with open(f"./{name}.pyo") as module:
                return module.read()
        else:
            return False
    else:
        if os.path.isfile(f"./{name}-{hash_string(path)}.pyo"):
            with open(f"./{name}-{hash_string(path)}.pyo") as module:
                return module.read()
        else:
            return False
def hash_string(string):
    return hashlib.sha1(string.encode()).hexdigest()
def compile_file(path,module_type):
    path=path.strip()
    pwd=os.path.dirname(path)
    compiled_strings=[]
    with open(path,'r') as file_to_compile:
        for line in file_to_compile:
            indentation, include_line=check_if_include_line(line)
            if not include_line:
                compiled_strings.append(line)
                continue
            else:
               submodule_to_include=include_line[0]
               if any(submodule_to_include.startswith(quote) and submodule_to_include.endswith(quote) for quote in ['"',"'"]):
                   submodule_type="relative"
                   submodule_to_include=submodule_to_include[1:-1]
               else:
                   submodule_type="absolute"
               
               submodule_to_include=os.path.expanduser(submodule_to_include)
               
               if submodule_type=="relative":
                   if os.path.isabs(submodule_to_include):
                       submodule_path=submodule_to_include
                   else:
                       submodule_path=os.path.join(pwd,submodule_to_include)
               else:
                   submodule_path=os.path.expanduser(os.path.join(MODULES_PATH.submodule_to_include))
                   
               if not submodule_path.endswith(".py"):
                   #Assume arbitrary data and save it to be used later
                   with open(submodule_path,"rb") as resource:
                       resource_data=base64.b64encode(resource.read())
                       submodule=f"""
                            import base64
                            {include_line[1]} = base64.b64decode({resource_data})
                       """
                       submodule=textwrap.dedent(submodule)
                       submodule=textwrap.indent(submodule,indentation)
                       compiled_strings.append(submodule)
                   continue
               submodule_name=pathlib.Path(submodule_path).stem
               submodule_path=os.path.realpath(submodule_path)
               submodule=check_if_module_is_already_compiled(submodule_path,submodule_type)
               
               if not submodule:
                   if os.path.isfile(submodule_path):
                       submodule=compile_file(submodule_path,submodule_type)
                   else:
                       continue
               
               submodule_function=''.join(random.choices(string.ascii_uppercase + string.ascii_lowercase, k=10))
               submodule=textwrap.dedent("""
               
               import types
               import sys
               import base64
               {c}_module=types.ModuleType("{c}")
               #setattr({c}_module,"__file__",__file__)
               exec(base64.b64decode({b}).decode("utf-8"),{c}_module.__dict__)
               sys.modules["{c}"]={c}_module
               """).format(a=submodule_function,b=base64.b64encode(submodule.encode("utf-8")),c=submodule_name)
               
               
               #Indent as much as the original include line
               submodule=textwrap.indent(submodule,indentation)
               compiled_strings.append(submodule)
    if module_type == "absolute":
       module_output_name=f"./{pathlib.Path(path).stem}.pyo"
    else:
       module_output_name=f"./{pathlib.Path(path).stem}-{hash_string(path)}.pyo"
    compiled_strings=''.join(compiled_strings)
    with open(module_output_name,"w+") as module_output_file:
       module_output_file.write(compiled_strings)
    return compiled_strings

def clean(file=None):
    for item in os.listdir("."):
        if file:
            if item==file:
                continue
        if item.endswith(".pyo"):
            os.remove("./"+item)
if function=='build':
    for py in files:
        compile_file(py,"absolute")
        if '--make-script' in flags:
            make_executable(py.removesuffix(".py")+".pyo")
            os.rename(py.removesuffix(".py")+".pyo",py.removesuffix(".py"))
            if '--no-clean' not in flags:
                clean()
        elif '--make-module' in flags:
            if '--no-clean' not in flags:
                clean(os.path.basename(py.removesuffix(".py")+".pyo"))


elif function=="clean":
    clean()
                       
                   
                   
               
