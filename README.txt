mod is a tool that allows you to embed data files and modules inside your python script. This is in stark contrast to other tools like py2exe, PyInstaller, and Nuitka that output executables, rather than scripts.

To get started, simply add # < include "name_of_module.py" > to wherever you import a module. Then, run "mod build <file>.py" and it will output <your file>.pyo, which can be run with no dependencies other than a standard Python install.

To include data files, add # < include "data_file" var >. This will add the contents of data_file in the vairable var. Keep in mind that var will be a bytes object (in the future, mod may use the extension to decide whether to add it as a string or bytes, but by default, will encode the data as bytes).

To include modules, add # < include module.py >. If module.py does not have quotes around it, it will look in MODULES_ROOT (by default, $HOME/Modules). Otherwise, it will look inside the directory of the script (not $PWD). It will add it as a module of the same name that can be imported.

mod-convert is a tool that takes traditional python modules (ie, ones that are multi-file) and turns them into single-file modules that can be called with mod. However, a note of warning: these are not suitable to be called by ordinary scripts that are not built with mod. If you have such a need, I suggest to use pinliner. Run with mod-convert module_directory.

mod-comment is a tool to automaticlly add #include to 3rd-party module imports in your traditional modules, so that it can be automatically converted with mod-convert.
