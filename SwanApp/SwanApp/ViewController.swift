//
//  ViewController.swift
//  SwanApp
//
//  Created by JK on 2020/10/09.
//

import Cocoa
import SwanKit

class ViewController: NSViewController {
    private var outputObserver : NSObjectProtocol? = nil
    private var readData = Data()
    
    fileprivate func analyze(with options : CommandLineOptions) {
        do {
            let configuration = try createConfiguration(options: options)
            let analyzer = try Analyzer(configuration: configuration)
            let unusedSources = try analyzer.analyze()
            configuration.reporter.report(configuration, sources: unusedSources)
        } catch {
            log(error.localizedDescription, level: .error)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(forName: NSNotification.Name.init("DroppedURL"), object: nil, queue: nil) { (notification) in
            if let url = notification.userInfo?["url"] as? URL {
                self.grepBuildDirectory(for: url) { (target, project) in
                    var options = CommandLineOptions()
                    var targetURL = URL(fileURLWithPath: target)
                    targetURL.deleteLastPathComponent()
                    targetURL.deleteLastPathComponent()
                    targetURL.deleteLastPathComponent()
                    targetURL.appendPathComponent("Index")
                    targetURL.appendPathComponent("DataStore")
                    options.indexStorePath = targetURL.path
                    options.path = project
                    self.analyze(with: options)
                }
            }
        }
        
//        DispatchQueue.global().async {
//            self.analyze()
//        }
    }
    
    private func grepBuildDirectory(for project:URL, completeHandler: @escaping (String, String) -> Void ) {
        let aTask = Process()
        aTask.executableURL = URL(string: "file:///usr/bin/xcodebuild")!
        let isWorkspace = project.lastPathComponent.contains(".xcworkspace")
        let isProject = project.lastPathComponent.contains(".xcodeproj")
        guard isWorkspace || isProject else { return }
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
        if isProject {
            aTask.terminationHandler = { [weak self] (_) in
                guard let self = self, let observer = self.outputObserver else { return }
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
            aTask.arguments = ["-showBuildSettings", "-project", project.path]
            try? aTask.run()
        }
        else if isWorkspace {
            aTask.terminationHandler = { [weak self] (_) in
                guard let self = self, let observer = self.outputObserver else { return }
                NotificationCenter.default.removeObserver(observer)
                let builds = String.init(data: self.readData, encoding: .utf8)
                guard let settings = builds?.split(separator: "\n") else { return }
                var hasSchemes = false
                for setting in settings {
                    if hasSchemes {
                        print(setting)
                        continue
                    }
                    hasSchemes = setting.contains("Schemes:")
                }
            }
            aTask.arguments = ["-list", "-workspace", project.path]
            try? aTask.run()
        }
    }
}

