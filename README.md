Swan
====

Swan is **SW**ift static code **AN**anlyzer from xcode derived data.

### Goals

- A count of Class, Function, Protocol references
- Visualization for dependencies of references
- Provides architecture's view of modules, files, functions.

It inspired from [Pecker](https://github.com/woshiccm/Pecker) and [Sitrep](https://github.com/twostraws/Sitrep). 

Swan is built using Apple’s [SwiftSyntax](https://github.com/apple/swift-syntax) and [IndexStoreDB](https://github.com/apple/indexstore-db) for analyzing. 


Screenshot
-------------
- Window for dragging project

![Swan Window Screenshot](https://github.com/godrm/Swan/blob/main/Screenshots/Swan-Window.png)

- Result graph of SwanApp Project

![Swan Window Screenshot](https://github.com/godrm/Swan/blob/main/Screenshots/swan-graph-byfile.png)

Features
----------

- Drag xcode project from Finder to window
- Draw Dependency graph of this project
- Save to image from graph

`Now Workspace supports only first project scheme only`

- Swan use GraphViz to draw graph. It should be installed graphviz in running $PATH.


Contributions
----------------
If you are interested in contributing `Swan`, submit ideas or submit Pull Request!
It's developed fully opened.


License
---------
Swan is under [MIT] License. See [LICENSE](LICENSE) file for more info.
