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
import GraphViz
import DOT
import os

let swanLogger = os.Logger(subsystem: "kr.codesquad.swan", category: "swankit")

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
    
    public var includeSPM: Bool = false
    
    public init() {
    }
}

public func createConfiguration(options: CommandLineOptions, outputFile: String = "swan.output.pdf") throws -> Configuration {
    let indexStoreV5Path: AbsolutePath
    let sourcePackagePath: AbsolutePath
    let buildRootPath = try! AbsolutePath(validating: options.buildPath)
    sourcePackagePath = buildRootPath.appending(components: ["SourcePackages","checkouts"])

    indexStoreV5Path = buildRootPath.appending(components: ["Index", "DataStore", "v5"])
    let reachable = (try? indexStoreV5Path.asURL.checkResourceIsReachable()) ?? false
    var indexStorePath: AbsolutePath
    if reachable  {
        indexStorePath = buildRootPath.appending(components: ["Index", "DataStore"])
    }
    else {
        indexStorePath = buildRootPath.appending(components: ["Index.noindex", "DataStore"])
    }
    
    guard let cwd = localFileSystem.currentWorkingDirectory else {
        throw PEError.fiendCurrentWorkingDirectoryFailed
    }
    let rootPath = try! AbsolutePath(validating: options.path, relativeTo: cwd)
    let configuration = Configuration(projectPath: rootPath,
                                      projectFilePath: AbsolutePath(options.projectFilePath),
                                      workspaceFilePath: (options.workspaceFilePath.count>0) ? AbsolutePath(options.workspaceFilePath) : nil,
                                      indexStorePath: indexStorePath.asURL.path,
                                      sourcePackagePath: sourcePackagePath.asURL.path,
                                      reportType: options.mode,
                                      outputFile: outputFile,
                                      includeSPM: options.includeSPM)
    return configuration
}

public func isSupportGraphvizBinary() -> Bool {
    let graph = Graph()
    return graph.isAvailable(using: .dot)
}

public func log(_ message: String, level : os.OSLogType = .default) {
    switch level {
    case .default:
        swanLogger.info("\(message)")
    case .info:
        swanLogger.info("\(message)")
    case .error:
        swanLogger.error("\(message)")
    case .fault:
        swanLogger.critical("\(message)")
    default:
        swanLogger.warning("\(message)")
    }
}

enum PEError: Error {
    case findIndexFailed(message: String)
    case fiendCurrentWorkingDirectoryFailed
    case findProjectFileFailed(message: String)
    case indexStorePathPathWrong
    case dotBinaryNotFound
}
