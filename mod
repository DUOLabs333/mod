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
import types
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
def check_include_line(string,pwd):
    prefix="# < include "
    indentation=''.join(itertools.takewhile(str.isspace,string))
    string=string.strip()
    if string.startswith(prefix) and string.endswith(" >"):
        string=string.removeprefix(prefix).removesuffix(" >")
        string=split_string_by_char(string," ")
        path=string[0]
        if any(path.startswith(quote) and path.endswith(quote) for quote in ['"',"'"]):
            type="relative"
            path=path[1:-1]
        else:
            type="absolute"
            
        path=os.path.expanduser(path)
        
        if type=="relative":
            if os.path.isabs(path):
                path=path
            else:
                path=os.path.join(pwd,path)
        else:
            path=os.path.expanduser(os.path.join(MODULES_PATH,path))
            path=os.path.realpath(path)
        
        #Get variable if there is one
        if len(string)==2:
            variable=string[1]
        else:
            variable=os.path.basename(path).removesuffix(".py")
            
        return types.SimpleNamespace(variable=variable,path=path,type=type,indentation=indentation)
    else:
        return None
def hash_string(string):
    return hashlib.sha1(string.encode()).hexdigest()

def compile_file(path,header,visited):
    path=path.strip()
    pwd=os.path.dirname(path)
    lines=[]
    #header=[] #Join with \n when done
    #visited={} #If name in visited, ignore
    with open(path,'r') as file_to_compile:
        for line in file_to_compile:
            include_line=check_include_line(line,pwd)
            if not include_line:
                lines.append(line)
                continue
            else:
               if not include_line.path.endswith(".py"):
                   #Assume arbitrary data and save it to be used later
                   with open(include_line.path,"rb") as resource:
                       resource_data=base64.b64encode(resource.read())
                       submodule=f"""
                            import base64
                            {include_line.variable} = base64.b64decode({resource_data})
                       """
                       submodule=textwrap.dedent(submodule)
                       submodule=textwrap.indent(submodule,include_line.indentation)
                       lines.append(submodule)
                   continue
               
               if os.path.isfile(include_line.path): #Skip if file doesn't exist
                   compile_file(include_line.path,lines,visited)
               else:
                   continue
               if include_line.path in visited:
                   continue #Don't have duplicates
               else:
                   with open(include_line.path,"r") as f:
                       submodule_function=''.join(random.choices(string.ascii_uppercase + string.ascii_lowercase, k=10))
                       submodule=textwrap.dedent("""
                       
                       import types
                       import sys
                       import base64
                       {c}_module=types.ModuleType("{c}")
                       #setattr({c}_module,"__file__",__file__)
                       exec(base64.b64decode({b}).decode("utf-8"),{c}_module.__dict__)
                       sys.modules["{c}"]={c}_module
                       """).format(a=submodule_function,b=base64.b64encode(f.read().encode("utf-8")),c=include_line.variable)
                       
                       header.append(submodule)
                   visited[include_line.path]=None
                   
    module_output_name=f"./{pathlib.Path(path).stem}.pyo"
    lines=''.join(lines)
    with open(module_output_name,"w+") as module_output_file:
        module_output_file.write(''.join(header))
        module_output_file.write(lines)

def clean(file=None):
    for item in os.listdir("."):
        if file:
            if item==file:
                continue
        if item.endswith(".pyo"):
            os.remove("./"+item)
if function=='build':
    for py in files:
        compile_file(py,[],{})
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
                       
                   
                   
               
