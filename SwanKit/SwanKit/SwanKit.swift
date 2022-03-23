//
//  SwanKit.swift
//  SwanKit
//
//  Created by JK on 2020/10/10.
//
import Foundation
import IndexStoreDB
import TSCBasic

public struct CommandLineOptions {
    /// The project path
    public var path: String = ""

    /// The mode to report
    ///
    /// If not specified, default mode is console
    public var mode: ReporterType = .console

    /// The path to the index that should be loaded
    ///
    /// If not specified, the default is find from DerivedData with project name
    public var indexStorePath: String?
    
    public init() {
    }
}

public func createConfiguration(options: CommandLineOptions, outputFile: String = "swan.output.pdf") throws -> Configuration {
    let indexStorePath: AbsolutePath
    if let indexStorePathString = options.indexStorePath {
        indexStorePath = AbsolutePath(indexStorePathString)
    } else {
        let processInfo = ProcessInfo()
        // ~/Library/Developer/Xcode/DerivedData/<target>/Index/DataStore
        let buildRoot = try processInfo.environmentVariable(name: EnvironmentKeys.buildRoot)
        let buildRootPath = AbsolutePath(buildRoot)
        indexStorePath = buildRootPath.parentDirectory.parentDirectory.appending(component: "Index/DataStore")
    }
    
    guard let cwd = localFileSystem.currentWorkingDirectory else {
        throw PEError.fiendCurrentWorkingDirectoryFailed
    }
    let rootPath = AbsolutePath(options.path, relativeTo: cwd)
    let configuration = Configuration(projectPath: rootPath, indexStorePath: indexStorePath.asURL.path, reportType: options.mode, outputFile: outputFile)
    
    return configuration
}

private extension ProcessInfo {
    func environmentVariable(name: String) throws -> String {
    guard let value = self.environment[name] else {
        throw ProcessError.missingValue(argument: name)
    }
    return value
  }
}

// Default values for non-optional Commander Options
struct EnvironmentKeys {
    static let bundleIdentifier = "PRODUCT_BUNDLE_IDENTIFIER"
    static let productModuleName = "PRODUCT_MODULE_NAME"
    static let scriptInputFileCount = "SCRIPT_INPUT_FILE_COUNT"
    static let scriptOutputFileCount = "SCRIPT_OUTPUT_FILE_COUNT"
    static let target = "TARGET_NAME"
    static let tempDir = "TEMP_DIR"
    static let xcodeproj = "PROJECT_FILE_PATH"
    static let buildRoot = "BUILD_ROOT"
}

enum ProcessError: Error {
    case missingValue(argument: String?)
}

enum PEError: Error {
    case findIndexFailed(message: String)
    case fiendCurrentWorkingDirectoryFailed
    case findProjectFileFailed(message: String)
    case indexStorePathPathWrong
}
