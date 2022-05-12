//
//  Project.swift
//  SwanKit
//
//  Created by JK on 2022/05/11.
//

import Foundation

public final class ProjectManager {
    enum Constant {
        static let XCODEBUILD = "file:///usr/bin/xcodebuild"
        static let OPEN = "file:///usr/bin/open"
        static let TARGET_DIR = "TARGET_BUILD_DIR"
        static let PROJECT_DIR = "PROJECT_DIR"
        static let PROJECT_FILE_PATH = "PROJECT_FILE_PATH"
        static let XC_PROJECT = ".xcodeproj"
        static let XC_WORKSPACE = ".xcworkspace"
    }
    enum Argument {
        static let SHOW_SETTING = "-showBuildSettings"
        static let PROJECT = "-project"
        static let LIST = "-list"
        static let WORKSPACE = "-workspace"
        static let SCHEME = "-scheme"
    }
    private var readData = Data()
    private var outputPipe : Pipe!
    private var fileHandle : FileHandle!

    public init() {
        self.outputPipe = Pipe()
        self.fileHandle = self.outputPipe.fileHandleForReading
        self.fileHandle.readabilityHandler = { (fileHandle) -> Void in
            self.readData.append(fileHandle.availableData)
        }
    }

    private func runProcess(fileurl: String, arguments:[String], terminationHandler:  @escaping ()->()) {
        let aTask = Process()
        aTask.qualityOfService = .userInitiated
        aTask.executableURL = URL(string: fileurl)
        aTask.standardOutput = outputPipe
        readData.removeAll()
        
        aTask.terminationHandler = { (_) in
            terminationHandler()
        }
        aTask.arguments = arguments
        try? aTask.run()
    }
    
    public func grepProjectSetting(for url:URL, completeHandler: @escaping (URL?, String, String) -> Void ) {
        runProcess(fileurl: Self.Constant.XCODEBUILD, arguments: [Self.Argument.SHOW_SETTING, Self.Argument.PROJECT, url.path]) {
            let builds = String.init(data: self.readData, encoding: .utf8)
            guard let settings = builds?.split(separator: "\n") else { return }
            var target_build_dir = ""
            var project_dir = ""
            var project_file_path = ""
            for setting in settings {
                if setting.contains(Self.Constant.TARGET_DIR){
                    target_build_dir = String(setting.split(separator: "=").last ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
                else if setting.contains(Self.Constant.PROJECT_DIR) {
                    project_dir = String(setting.split(separator: "=").last ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
                else if setting.contains(Self.Constant.PROJECT_FILE_PATH) {
                    project_file_path = String(setting.split(separator: "=").last ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
            }
            var targetURL : URL?
            if !target_build_dir.isEmpty {
                targetURL = URL(fileURLWithPath: target_build_dir)
                targetURL?.deleteLastPathComponent()
                targetURL?.deleteLastPathComponent()
                targetURL?.deleteLastPathComponent()
            }
            completeHandler(targetURL, project_dir, project_file_path)
        }
    }
    
    public func grepWorkspaceScheme(for url:URL, completeHandler: @escaping ([String]) -> Void ) {
        runProcess(fileurl: Self.Constant.XCODEBUILD, arguments: [Self.Argument.LIST, Self.Argument.WORKSPACE, url.path]) {
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
    
    public func grepWorkspaceSchemeSetting(for url:URL, scheme: String, completeHandler: @escaping (URL?, String, String) -> Void ) {
        runProcess(fileurl: Self.Constant.XCODEBUILD, arguments: [Self.Argument.SHOW_SETTING, Self.Argument.WORKSPACE, url.path, Self.Argument.SCHEME, scheme]) {
            let builds = String.init(data: self.readData, encoding: .utf8)
            guard let settings = builds?.split(separator: "\n") else { return }
            var target_build_dir = ""
            var project_dir = ""
            var project_file_path = ""
            for setting in settings {
                if setting.contains(Self.Constant.TARGET_DIR){
                    target_build_dir = String(setting.split(separator: "=").last ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
                else if setting.contains(Self.Constant.PROJECT_DIR) {
                    project_dir = String(setting.split(separator: "=").last ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
                else if setting.contains(Self.Constant.PROJECT_FILE_PATH) {
                    project_file_path = String(setting.split(separator: "=").last ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
            }
            var targetURL : URL?
            if !target_build_dir.isEmpty {
                targetURL = URL(fileURLWithPath: target_build_dir)
                targetURL?.deleteLastPathComponent()
                targetURL?.deleteLastPathComponent()
                targetURL?.deleteLastPathComponent()
            }
            completeHandler(targetURL, project_dir, project_file_path)
        }
    }

    public func isWorkspace(for project:URL) -> Bool {
        return project.lastPathComponent.contains(Self.Constant.XC_WORKSPACE)
    }

    public func isProject(for project:URL) -> Bool {
        return project.lastPathComponent.contains(Self.Constant.XC_PROJECT)
    }
}
