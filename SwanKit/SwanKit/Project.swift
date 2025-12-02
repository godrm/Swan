//
//  Project.swift
//  SwanKit
//
//  Created by JK on 2022/05/11.
//

import Foundation
import CryptoKit

public final class ProjectManager {
    enum Constant {
        static let XCODEBUILD = "file:///usr/bin/xcodebuild"
        static let OPEN = "file:///usr/bin/open"
        static let TARGET_DIR = "TARGET_BUILD_DIR"
        static let PROJECT_DIR = "PROJECT_DIR"
        static let PROJECT_NAME = "PROJECT_NAME"
        static let PROJECT_FILE_PATH = "PROJECT_FILE_PATH"
        static let USER_LIBRARY_DIR = "USER_LIBRARY_DIR"
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
  
    private func hashcode(for project:URL) -> String {
      // 문자열을 UTF-8 데이터로 변환
      let path = project.path()
      guard let pathData = path.data(using: .utf8) else {
          return ""
      }
      
      // MD5 해시 계산
      let md5Digest = Insecure.MD5.hash(data: pathData)
      let md5Bytes = Array(md5Digest)
      
      // 결과를 저장할 배열
      var hashPath = [Character](repeating: " ", count: 28)
      
      // 첫 8바이트를 Big Endian UInt64로 변환
      let firstBytes = md5Bytes[0..<8]
      var firstValue: UInt64 = 0
      for byte in firstBytes {
          firstValue = (firstValue << 8) | UInt64(byte)
      }
      
      // 첫 번째 부분 처리 (인덱스 0-13)
      var counter = 13
      while counter >= 0 {
          let charCode = Int(firstValue % 26)
          hashPath[counter] = Character(UnicodeScalar(charCode + Int(Character("a").asciiValue!))!)
          firstValue = firstValue / 26
          counter -= 1
      }
      
      // 다음 8바이트를 Big Endian UInt64로 변환
      let secondBytes = md5Bytes[8..<16]
      var secondValue: UInt64 = 0
      for byte in secondBytes {
          secondValue = (secondValue << 8) | UInt64(byte)
      }
      
      // 두 번째 부분 처리 (인덱스 14-27)
      counter = 27
      while counter > 13 {
          let charCode = Int(secondValue % 26)
          hashPath[counter] = Character(UnicodeScalar(charCode + Int(Character("a").asciiValue!))!)
          secondValue = secondValue / 26
          counter -= 1
      }
      
      // 배열을 문자열로 변환
      return String(hashPath)
    }
  
    private func derivedTargetURL(from : URL, projectName : String, userLibrary : String) -> URL? {
      let hash = hashcode(for: from)
      let targetURL = URL(fileURLWithPath: "\(userLibrary)/Developer/Xcode/DerivedData/\(projectName)-\(hash)")
      return targetURL
    }
    
    public func grepProjectSetting(for url:URL, completeHandler: @escaping (URL?, String, String, String?) -> Void ) {
        runProcess(fileurl: Self.Constant.XCODEBUILD, arguments: [Self.Argument.SHOW_SETTING, Self.Argument.PROJECT, url.path]) {
            let builds = String.init(data: self.readData, encoding: .utf8)
            guard let settings = builds?.split(separator: "\n") else { return }
            var project_name = ""
            var project_dir = ""
            var project_file_path = ""
            var user_library = ""
            for setting in settings {
                if setting.contains(Self.Constant.PROJECT_DIR) {
                    project_dir = String(setting.split(separator: "=").last ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
                else if setting.contains(Self.Constant.PROJECT_NAME) {
                    project_name = String(setting.split(separator: "=").last ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
                else if setting.contains(Self.Constant.PROJECT_FILE_PATH) {
                    project_file_path = String(setting.split(separator: "=").last ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
                else if setting.contains(Self.Constant.USER_LIBRARY_DIR) {
                  user_library = String(setting.split(separator: "=").last ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
            }
            //unique default style
            let targetURL = self.derivedTargetURL(from: url, projectName: project_name, userLibrary: user_library)
            completeHandler(targetURL, project_dir, project_file_path, nil)
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
    
    public func grepWorkspaceSchemeSetting(for url:URL, scheme: String, completeHandler: @escaping (URL?, String, String, String?) -> Void ) {
        runProcess(fileurl: Self.Constant.XCODEBUILD, arguments: [Self.Argument.SHOW_SETTING, Self.Argument.WORKSPACE, url.path, Self.Argument.SCHEME, scheme]) {
            let builds = String.init(data: self.readData, encoding: .utf8)
            guard let settings = builds?.split(separator: "\n") else { return }
            var project_dir = ""
            var project_name = ""
            var project_file_path = ""
            var user_library = ""
            for setting in settings {
                if setting.contains(Self.Constant.PROJECT_DIR) {
                    project_dir = String(setting.split(separator: "=").last ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
                else if setting.contains(Self.Constant.PROJECT_NAME) {
                    project_name = String(setting.split(separator: "=").last ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
                else if setting.contains(Self.Constant.PROJECT_FILE_PATH) {
                    project_file_path = String(setting.split(separator: "=").last ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
                else if setting.contains(Self.Constant.USER_LIBRARY_DIR) {
                  user_library = String(setting.split(separator: "=").last ?? "").trimmingCharacters(in: CharacterSet.whitespaces)
                }
            }
            //unique default style
            let targetURL = self.derivedTargetURL(from: url, projectName: project_name, userLibrary: user_library)
            completeHandler(targetURL, project_dir, project_file_path, url.path)
        }
    }

    public func isWorkspace(for project:URL) -> Bool {
        return project.lastPathComponent.contains(Self.Constant.XC_WORKSPACE)
    }

    public func isProject(for project:URL) -> Bool {
        return project.lastPathComponent.contains(Self.Constant.XC_PROJECT)
    }
}
