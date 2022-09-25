mod is a tool that allows you to build your script into a single file.

To start, make a folder, and make a `src` folder. 
In this `src` folder, write your python module. 
In its `__init__.py`, define your app's entrypoint as `main`

In the project's root, make a `_vendor` folder.
In this `_vendor` folder, install all of your dependencies.

Run `mod build`.
You will get a file with the same name as your project's name. You can run this to run your app.
You can also import your module from this file if you add it to `sys.path` or `PYTHONPATH`.
