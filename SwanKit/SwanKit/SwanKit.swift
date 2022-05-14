//
//  SwanKit.swift
//  SwanKit
//
//  Created by JK on 2020/10/10.
//
import Foundation
import IndexStoreDB
import TSCBasic
import TSCUtility

public struct CommandLineOptions {
    /// The project path
    public var path: String = ""

    /// The xcodeproj file path
    public var projectFilePath: String = ""

    /// The xcworkspace file path
    public var workspaceFilePath: String = ""

    /// The mode to report
    ///
    /// If not specified, default mode is console
    public var mode: ReporterType = .console

    /// The path to the index that should be loaded
    ///
    /// If not specified, the default is find from DerivedData with project name
    public var buildPath: String = ""
    
    public init() {
    }
}

public func createConfiguration(options: CommandLineOptions, outputFile: String = "swan.output.pdf") throws -> Configuration {
    let indexStorePath: AbsolutePath
    let sourcePackagePath: AbsolutePath
    let buildRootPath = AbsolutePath(options.buildPath)
    indexStorePath = buildRootPath.appending(components: ["Index", "DataStore"])
    sourcePackagePath = buildRootPath.appending(components: ["SourcePackages","checkouts"])
    
    guard let cwd = localFileSystem.currentWorkingDirectory else {
        throw PEError.fiendCurrentWorkingDirectoryFailed
    }
    let rootPath = AbsolutePath(options.path, relativeTo: cwd)
    let configuration = Configuration(projectPath: rootPath,
                                      projectFilePath: AbsolutePath(options.projectFilePath),
                                      workspaceFilePath: (options.workspaceFilePath.count>0) ? AbsolutePath(options.workspaceFilePath) : nil,
                                      indexStorePath: indexStorePath.asURL.path,
                                      sourcePackagePath: sourcePackagePath.asURL.path,
                                      reportType: options.mode,
                                      outputFile: outputFile)
    return configuration
}

enum PEError: Error {
    case findIndexFailed(message: String)
    case fiendCurrentWorkingDirectoryFailed
    case findProjectFileFailed(message: String)
    case indexStorePathPathWrong
}
