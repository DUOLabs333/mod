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

MODULES_PATH=os.getenv("MODULES_PATH",f"{os.environ['HOME']}/Modules")
def split_string_by_char(string,char=':'):
    PATTERN = re.compile(rf'''((?:[^\{char}"']|"[^"]*"|'[^']*')+)''')
    return [_ for _ in list(PATTERN.split(string)) if _ not in ['', char]]

#Get files to compile
files = sys.argv[1:]

#Get absolute path of files
files=[os.path.realpath(_) for _ in files]

#Check if line is an "include" line
def check_if_include_line(string):
    indentation=''.join(itertools.takewhile(str.isspace,string))
    string=string.strip()
    if string.startswith("< include") and string.endswith(" >"):
        string=string.removeprefix("< include").removesuffix(" >")
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
def compile_file(path,module_type="absolute"):
    path=path.strip()
    compiled_strings=[]
    with open(path,'r') as file_to_compile:
        for line in file_to_compile:
            indentation, include_line=check_if_include_line(line)
            if not include_line:
                compiled_strings.append(line)
                continue
            else:
               submodule_to_include=include_line[0]
               if submodule_to_include.startswith('"') and submodule_to_include.endswith('"'):
                   submodule_type="relative"
               else:
                   submodule_type="absolute"
               submodule_to_include=submodule_to_include[1:-1]
               submodule_path=os.path.abspath(os.path.expanduser(submodule_to_include))
               submodule_name=pathlib.Path(submodule_path).stem
               submodule_path=os.path.realpath(submodule_path)
               submodule=check_if_module_is_already_compiled(submodule_path,submodule_type)
               
               if not submodule:
                   submodule=compile_file(submodule_path,submodule_type)
               
               submodule_function=''.join(random.choices(string.ascii_uppercase + string.ascii_lowercase, k=10))
               submodule="\n     ".join(submodule.splitlines())
               submodule_template="""
               import types
               
               {submodule_name} = types.SimpleNamespace()
               def {submodule_function}():
                    {submodule}
                    local_variables=locals().copy()
                    for key in local_variables:
                       exec(f"{submodule_name}.{{key}} = {{key}}")
               
               {submodule_function}()
               """
               # Remove leading spaces that is present in the source code
               submodule_template=textwrap.dedent(submodule_template)
               
               # Do this so I won't have to deal with str.format
               submodule=eval(f"f{repr(submodule_template)}")
               
               #Indent as much as the original include line
               submodule=textwrap.indent(submodule,indentation)
               compiled_strings.append(submodule)
    if module_type == "absolute":
       module_output_name=f"./{pathlib.Path(path).stem}.pyo"
    else:
       module_output_name=f"./{pathlib.Path(path).stem}-{hash_string(path)}.pyo"
    compiled_strings='\n'.join(compiled_strings)
    with open(module_output_name,"w+") as module_output_file:
       module_output_file.write(compiled_strings)
    return compiled_strings


for pyx in files:
    compile_file(pyx,"absolute")

                       
                   
                   
               