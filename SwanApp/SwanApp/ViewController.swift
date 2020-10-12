//
//  ViewController.swift
//  SwanApp
//
//  Created by JK on 2020/10/09.
//
import Cocoa
import SwanKit

class ViewController: NSViewController {
    static let XCODEBUILD = "file:///usr/bin/xcodebuild"
    private var outputObserver : NSObjectProtocol? = nil
    private var readData = Data()
    
    fileprivate func analyze(with options : CommandLineOptions) {
        do {
            let configuration = try createConfiguration(options: options)
            let analyzer = try Analyzer(configuration: configuration)
            let sources = try analyzer.analyze()
            configuration.reporter.report(configuration, sources: sources)
        } catch {
            log(error.localizedDescription, level: .error)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.init("DroppedURL"), object: nil, queue: nil) { (notification) in
            guard let url = notification.userInfo?["url"] as? URL else { return }
            self.grepBuildDirectory(for: url) { (target, project) in
                guard target.count > 0, project.count > 0 else { return }
                var options = CommandLineOptions()
                var targetURL = URL(fileURLWithPath: target)
                targetURL.deleteLastPathComponent()
                targetURL.deleteLastPathComponent()
                targetURL.deleteLastPathComponent()
                targetURL.appendPathComponent("Index")
                targetURL.appendPathComponent("DataStore")
                options.indexStorePath = targetURL.path
                options.path = project
                options.mode = .graphviz
                self.analyze(with: options)
            }
        }
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
        runProcess(fileurl: Self.XCODEBUILD, arguments: ["-showBuildSettings", "-project", url.path]) {
            guard let observer = self.outputObserver else { return }
            NotificationCenter.default.removeObserver(observer)
            let builds = String.init(data: self.readData, encoding: .utf8)
            guard let settings = builds?.split(separator: "\n") else { return }
            var target_build_dir = ""
            var project_dir = ""
            for setting in settings {
                if setting.contains("TARGET_BUILD_DIR"){
                    target_build_dir = String(setting.split(separator: "=").last ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
                else if setting.contains("PROJECT_DIR") {
                    project_dir = String(setting.split(separator: "=").last ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
            }
            completeHandler(target_build_dir, project_dir)
        }
    }
    
    private func grepWorkspaceScheme(for url:URL, completeHandler: @escaping ([String]) -> Void ) {
        runProcess(fileurl: Self.XCODEBUILD, arguments: ["-list", "-workspace", url.path]) {
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
        runProcess(fileurl: Self.XCODEBUILD, arguments: ["-showBuildSettings", "-workspace", url.path, "-scheme", scheme]) {
            guard let observer = self.outputObserver else { return }
            NotificationCenter.default.removeObserver(observer)
            let builds = String.init(data: self.readData, encoding: .utf8)
            guard let settings = builds?.split(separator: "\n") else { return }
            var target_build_dir = ""
            var project_dir = ""
            for setting in settings {
                if setting.contains("TARGET_BUILD_DIR"){
                    target_build_dir = String(setting.split(separator: "=").last ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
                else if setting.contains("PROJECT_DIR") {
                    project_dir = String(setting.split(separator: "=").last ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
            }
            completeHandler(target_build_dir, project_dir)
        }
    }

    private func grepBuildDirectory(for project:URL, completeHandler: @escaping (String, String) -> Void ) {
        let isWorkspace = project.lastPathComponent.contains(".xcworkspace")
        let isProject = project.lastPathComponent.contains(".xcodeproj")
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
                    self.grepWorkspaceSchemeSetting(for: project, scheme: schemes.first!) { (target_dir, project_dir) in
                        completeHandler(target_dir, project_dir)
                    }
                }
            }
        }
    }
}

