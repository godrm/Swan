//
//  ViewController.swift
//  SwanApp
//
//  Created by JK on 2020/10/09.
//
import Cocoa
import SwanKit
import IndexStoreDB

class ViewController: NSViewController {
    enum Constant {
        static let XCODEBUILD = "file:///usr/bin/xcodebuild"
        static let OPEN = "file:///usr/bin/open"
        static let INDEX = "Index"
        static let DATASTORE = "DataStore"
        static let TARGET_DIR = "TARGET_BUILD_DIR"
        static let PROJECT_DIR = "PROJECT_DIR"
        static let XC_PROJECT = ".xcodeproj"
        static let XC_WORKSPACE = ".xcworkspace"
    }
    enum Argument {
        static let SHOW_SETTING = "-showBuildSettings"
        static let PROJECT = "-project"
        static let LIST = "-list"
        static let WORKSPACE = "-workspace"
        static let SCHEME = "-scheme"
        static let PREVIEW = "Preview.app"
    }
    
    
    private var outputObserver : NSObjectProtocol? = nil
    private var readData = Data()
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(forName: ProjectDragView.NotificationName.didDropURL, object: nil, queue: nil) { (notification) in
            guard let url = notification.userInfo?["url"] as? URL else { return }
            self.grepBuildDirectory(for: url) { (target, project) in
                guard target.count > 0, project.count > 0 else { return }
                var options = CommandLineOptions()
                var targetURL = URL(fileURLWithPath: target)
                targetURL.deleteLastPathComponent()
                targetURL.deleteLastPathComponent()
                targetURL.deleteLastPathComponent()
                targetURL.appendPathComponent(Self.Constant.INDEX)
                targetURL.appendPathComponent(Self.Constant.DATASTORE)
                options.indexStorePath = targetURL.path
                options.path = project
                options.mode = .graphvizBinary
                let sources = self.analyze(with: options)
                self.report(for: sources, with: options)
            }
        }
    }
    
    fileprivate func analyze(with options : CommandLineOptions) -> [SourceDetail:[SymbolOccurrence]] {
        do {
            let configuration = try createConfiguration(options: options, outputFile: "swan.func.pdf")
            let analyzer = try Analyzer(configuration: configuration)
            return try analyzer.analyze()
        } catch {
            log(error.localizedDescription, level: .error)
        }
        return [:]
    }
    
    private func report(for sources: [SourceDetail:[SymbolOccurrence]], with options: CommandLineOptions) {
        do {
            let configuration = try createConfiguration(options: options, outputFile: "swan.func.pdf")
            let outputs = configuration.reporter.report(configuration, sources: sources)
            if options.mode != .console {
                preview(outputs)
            }
            
            var options = options
            options.mode = .graphvizFile
            let fileConfiguration = try createConfiguration(options: options, outputFile: "swan.file.pdf")
            let fileOutputs = fileConfiguration.reporter.report(fileConfiguration, sources: sources)
            if options.mode != .console {
                preview(fileOutputs)
            }
        } catch {
            log(error.localizedDescription, level: .error)
        }
    }

    private func preview(_ outputs: [String]) {
        guard outputs.count > 0,
              let output = outputs.first else { return }
        let aTask = Process()
        aTask.executableURL = URL(string: Self.Constant.OPEN)
        aTask.arguments = ["-a", Self.Argument.PREVIEW, output]
        aTask.launch()
    }
    
    private func runProcess(fileurl: String, arguments:[String], terminationHandler:  @escaping ()->()) {
        let aTask = Process()
        aTask.executableURL = URL(string: fileurl)
        let outputPipe = Pipe()
        aTask.standardOutput = outputPipe
        let fileHandle = outputPipe.fileHandleForReading
        fileHandle.waitForDataInBackgroundAndNotify()
        readData.removeAll()
        
        outputObserver = NotificationCenter.default.addObserver(forName: Notification.Name.NSFileHandleDataAvailable, object: fileHandle, queue: nil) { (notification) in
                let pipeHandle = notification.object as! FileHandle
                self.readData.append(pipeHandle.availableData)
                pipeHandle.waitForDataInBackgroundAndNotify()
        }
        aTask.terminationHandler = { (_) in
            terminationHandler()
        }
        aTask.arguments = arguments
        try? aTask.run()
    }
    
    private func grepProjectSetting(for url:URL, completeHandler: @escaping (String, String) -> Void ) {
        runProcess(fileurl: Self.Constant.XCODEBUILD, arguments: [Self.Argument.SHOW_SETTING, Self.Argument.PROJECT, url.path]) {
            guard let observer = self.outputObserver else { return }
            NotificationCenter.default.removeObserver(observer)
            let builds = String.init(data: self.readData, encoding: .utf8)
            guard let settings = builds?.split(separator: "\n") else { return }
            var target_build_dir = ""
            var project_dir = ""
            for setting in settings {
                if setting.contains(Self.Constant.TARGET_DIR){
                    target_build_dir = String(setting.split(separator: "=").last ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
                else if setting.contains(Self.Constant.PROJECT_DIR) {
                    project_dir = String(setting.split(separator: "=").last ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
            }
            completeHandler(target_build_dir, project_dir)
        }
    }
    
    private func grepWorkspaceScheme(for url:URL, completeHandler: @escaping ([String]) -> Void ) {
        runProcess(fileurl: Self.Constant.XCODEBUILD, arguments: [Self.Argument.LIST, Self.Argument.WORKSPACE, url.path]) {
            guard let observer = self.outputObserver else { return }
            NotificationCenter.default.removeObserver(observer)
            let builds = String.init(data: self.readData, encoding: .utf8)
            guard let settings = builds?.split(separator: "\n") else { return }
            var hasSchemes = false
            var schemes = [String]()
            for setting in settings {
                if hasSchemes {
                    let scheme = setting.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    if scheme == "Pods" || scheme.hasPrefix("Pods-") || scheme == "SwiftLint" { continue }
                    schemes.append(setting.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
                    continue
                }
                hasSchemes = setting.contains("Schemes:")
            }
            completeHandler(schemes)
        }
    }
    
    private func grepWorkspaceSchemeSetting(for url:URL, scheme: String, completeHandler: @escaping (String, String) -> Void ) {
        runProcess(fileurl: Self.Constant.XCODEBUILD, arguments: [Self.Argument.SHOW_SETTING, Self.Argument.WORKSPACE, url.path, Self.Argument.SCHEME, scheme]) {
            guard let observer = self.outputObserver else { return }
            NotificationCenter.default.removeObserver(observer)
            let builds = String.init(data: self.readData, encoding: .utf8)
            guard let settings = builds?.split(separator: "\n") else { return }
            var target_build_dir = ""
            var project_dir = ""
            for setting in settings {
                if setting.contains(Self.Constant.TARGET_DIR){
                    target_build_dir = String(setting.split(separator: "=").last ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
                else if setting.contains(Self.Constant.PROJECT_DIR) {
                    project_dir = String(setting.split(separator: "=").last ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
            }
            completeHandler(target_build_dir, project_dir)
        }
    }

    private func grepBuildDirectory(for project:URL, completeHandler: @escaping (String, String) -> Void ) {
        let isWorkspace = project.lastPathComponent.contains(Self.Constant.XC_WORKSPACE)
        let isProject = project.lastPathComponent.contains(Self.Constant.XC_PROJECT)
        guard isWorkspace || isProject else { return }

        if isProject {
            grepProjectSetting(for: project) { (target_dir, project_dir) in
                completeHandler(target_dir, project_dir)
            }
        }
        else if isWorkspace {
            grepWorkspaceScheme(for: project) { (schemes) in
                //TODO:- Select scheme UI for workspace
                DispatchQueue.main.async {
                    let selectButton = NSPopUpButton(title: "shemes", target: self, action: #selector(ViewController.selectScheme))
                    selectButton.title = schemes.first!
                    selectButton.frame = CGRect(x: 0, y: 0, width: 200, height: 50)
                    selectButton.addItems(withTitles: schemes)
                    
                    let alert = NSAlert()
                    alert.accessoryView = selectButton
                    alert.messageText = "Select scheme to analyze"
                    alert.addButton(withTitle: "Analyze")
                    alert.addButton(withTitle: "Cancel")
                    let selected = alert.runModal()
                    
                    guard selected == .alertFirstButtonReturn,
                          let scheme = selectButton.selectedItem?.title else { return }
                    self.grepWorkspaceSchemeSetting(for: project, scheme: scheme) { (target_dir, project_dir) in
                        completeHandler(target_dir, project_dir)
                    }
                }
            }
        }
    }
    
    @objc private func selectScheme(_ sender: NSPopUpButton) {
        sender.title = sender.selectedItem?.title ?? ""
    }
}

