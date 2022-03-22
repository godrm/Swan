Swan
====

Swan is **SW**ift static code **AN**anlyzer from xcode derived data.

### 프로젝트 목표

- 클래스, 구조체, 함수, 프로토콜 참조를 분석합니다
- 참조/호출 관계를 분석해서 그래프로 시각화합니다
- 아키텍처 관점에서 모듈, 파일, 함수 단위 구조를 표시합니다 (아직 할 게 많아요ㅜㅜ)


[Pecker](https://github.com/woshiccm/Pecker) 와 [Sitrep](https://github.com/twostraws/Sitrep) 프로젝트에서 영감을 받았습니다.
명령 기반이 아니라 시각화에 촛점을 맞추고 있습니다.

Swan 프로젝트는 애플의 오픈소스 [SwiftSyntax](https://github.com/apple/swift-syntax) 와 [IndexStoreDB](https://github.com/apple/indexstore-db)를 활용해서 Xcode가 빌드한 인덱스 파일을 분석합니다. 그래서 프로젝트 빌드하는 Xcode 버전과 Swift 버전을 맞춰서 실행해야 합니다.

---


### Goals

- Summary of Class, Function, Protocol references
- Visualization for dependencies of references
- Provides architecture's view of modules, files, functions

It inspired from [Pecker](https://github.com/woshiccm/Pecker) and [Sitrep](https://github.com/twostraws/Sitrep). 

Swan is built using Apple’s [SwiftSyntax](https://github.com/apple/swift-syntax) and [IndexStoreDB](https://github.com/apple/indexstore-db) for analyzing. 


Screenshot
-------------
- Window for dragging project

![Swan Window Screenshot](https://github.com/godrm/Swan/blob/main/Screenshots/Swan-Window.png)

- Result graph of SwanApp Project

![Swan Window Screenshot](https://github.com/godrm/Swan/blob/main/Screenshots/swan-graph-byfile.png)

Features (한글)
----------

- 우선 Xcode 버전(스위프트 언어 버전에 맞춰서)에 맞춰서 프로젝트를 빌드하세요 (그래야 indexStore를 탐색할 수 있습니다)
- Swan 앱을 실행하고 파인더에서 Xcode 프로젝트 파일을 드래그 앤 드롭하세요
- 워크스페이스라면 프로젝트 단위로 indexStore를 읽어서 의존성 그래프를 그려줍니다
- Graph 파일은 image/PDF 파일로 생성합니다

- 단, Swan은 GraphViz 라는 오픈소스 도구를 사용합니다. 꼭 $PATH에 graphviz 도구를 설치하셔야 합니다. 
[GraphViz 다운로드 바로가기](https://graphviz.org/download/)

---

- First of all, Build your project (It makes indexStores for project to derived folder)
- Just Drag and drop Xcode project file from Finder to Swan window
- Draw Dependency graph of selected project or workspace
- Open image/PDF for graph

- Swan use GraphViz to draw graph. It should be installed graphviz in running $PATH.
[GraphViz Download](https://graphviz.org/download/)



Contributions
----------------
If you are interested in contributing `Swan`, submit ideas or submit Pull Request!
It's developed fully opened.


License
---------
Swan is under [MIT] License. See [LICENSE](LICENSE) file for more info.
