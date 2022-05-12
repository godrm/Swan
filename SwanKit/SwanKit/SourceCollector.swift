//
//  SourceCollector.swift
//  SwanKit
//
//  Created by JK on 2020/10/09.
//

import Foundation
import TSCBasic
import IndexStoreDB
import XcodeProj

public typealias FileSystem = TSCBasic.FileSystem

extension Symbol : Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.usr)
        hasher.combine(self.name)
    }
}

/// Collects source code in the path.
class SourceCollector {
    private(set) var sources: [AbsolutePath] = []
    private(set) var symbols: [Symbol] = []
    private let configuration: Configuration
    private let targetPath: AbsolutePath
    private let swiftPackagePath: AbsolutePath
    private let excluded: Set<AbsolutePath>
    private let included: Set<AbsolutePath>
    private let blocklistFiles: Set<String>
    /// The file system to operate on.
    private let fs: FileSystem
    private let xcodeproj: XcodeProj
    
    init(rootPath: AbsolutePath, configuration: Configuration, xcodeproj: XcodeProj) {
        self.targetPath = rootPath
        self.configuration = configuration
        self.swiftPackagePath = AbsolutePath(configuration.sourcePackagePath)
        self.excluded = Set(configuration.excluded)
        self.included = Set(configuration.included)
        self.blocklistFiles = Set(configuration.blacklistFiles)
        self.fs = localFileSystem
        self.xcodeproj = xcodeproj
    }
    
    func collectSymbolsAtTarget(with indexDB: IndexStoreDB) {
        let files = computeContents()
        let safeSources = ThreadSafe<[Symbol]>([])
        DispatchQueue.concurrentPerform(iterations: files.count) { index in
            let symbols = indexDB.symbols(inFilePath: files[index].pathString)
            safeSources.atomically { $0.append(contentsOf: symbols) }
        }
        symbols = safeSources.value
    }

    func collectSymbolsProject(with indexDB: IndexStoreDB) {
        sources = computeContents(with: xcodeproj.pbxproj.buildFiles, projectPath: targetPath.pathString)
        sources.append(contentsOf: computeFrameworkContents(in: xcodeproj.pbxproj.fileReferences))
        let safeSources = ThreadSafe<Set<Symbol>>([])
        DispatchQueue.concurrentPerform(iterations: sources.count) { index in
            let symbols = indexDB.symbols(inFilePath: sources[index].pathString)
            safeSources.atomically { symbolMap in symbols.forEach{ symbolMap.insert($0) } }
        }
        symbols = Array(safeSources.value)
    }
    
    func hasSource(filePath: String) -> Bool {
        for source in sources {
            if source.pathString == filePath {
                return true
            }
        }
        return false
    }

    /// Compute the contents of the files in a target.
    ///
    /// This avoids recursing into certain directories like exclude.
    private func computeContents() -> [AbsolutePath] {
        var contents: [AbsolutePath] = []
        var queue: [AbsolutePath] = [targetPath]

        while let curr = queue.popLast() {
            
            // Ignore if this is an excluded path.
            if self.excluded.contains(curr) { continue }
            
            // Append and continue if the path doesn't have an extension or is not a directory and is not in lacklistFiles.
            if curr.extension == "swift" && !blocklistFiles.contains(curr.basenameWithoutExt) {
                contents.append(curr)
                continue
            }
            // If not directory continue
            guard fs.isDirectory(curr) else {
                continue
            }

            do {
                // Add directory content to the queue.
                let dirContents = try fs.getDirectoryContents(curr).map{ curr.appending(component: $0) }
                queue += dirContents
            } catch {
                log(error.localizedDescription, level: .warning)
            }
        }

        return contents
    }
    
    /// Compute project build phase files
    private func computeContents(with buildFiles: [PBXBuildFile], projectPath: String) -> [AbsolutePath] {
        var contents: [AbsolutePath] = []

        for buildFile in buildFiles {
            guard let sourcefile = buildFile.file else {
                continue
            }
            let parentPath = sourcefile.parentPath() ?? ""
            let fullPath = AbsolutePath("\(projectPath)\(parentPath)/\(sourcefile.path ?? sourcefile.name!)")
            if self.excluded.contains(fullPath) { continue }
            if fullPath.extension == "swift" && !blocklistFiles.contains(fullPath.basenameWithoutExt) {
                contents.append(fullPath)
                continue
            }
        }
        
        return contents
    }

    private func computeContentsWithSPM(with buildFiles: [PBXBuildFile]) -> [AbsolutePath] {
        var contents: [AbsolutePath] = []

        for buildFile in buildFiles {
            guard let sourcefile = buildFile.file else {
                guard let package = buildFile.product?.package else { continue }
                let packagePath = "\(swiftPackagePath.pathString)/\(package.name!)"
                guard FileManager.default.fileExists(atPath: packagePath) else { continue }
                let directories = FileManager.default.enumerator(atPath: packagePath)
                while let file = directories?.nextObject() as? String {
                    if file.hasSuffix(".swift") {
                        contents.append(AbsolutePath("\(packagePath)/\(file)"))
                    }
                }
                continue
            }
            let parentPath = sourcefile.parentPath() ?? ""
            let fullPath = AbsolutePath("\(targetPath.pathString)\(parentPath)/\(sourcefile.path ?? sourcefile.name!)")
            if self.excluded.contains(fullPath) { continue }
            if fullPath.extension == "swift" && !blocklistFiles.contains(fullPath.basenameWithoutExt) {
                contents.append(fullPath)
                continue
            }
        }
        
        return contents
    }

    /// Compute project file references
    private func computeFrameworkContents(in referenceFiles: [PBXFileReference]) -> [AbsolutePath] {
        var contents: [AbsolutePath] = []

        for reference in referenceFiles where reference.lastKnownFileType == "wrapper.pb-project" {
            let projectPath = "\(targetPath.pathString)/\(reference.path!)"
            guard let framework = try? XcodeProj(pathString: projectPath) else { continue }
            let projectURL = URL(fileURLWithPath: projectPath)            
            contents.append(contentsOf: computeContents(with: framework.pbxproj.buildFiles, projectPath: projectURL.deletingLastPathComponent().path))
        }
        
        return contents
    }
}

extension PBXFileElement {
    fileprivate func parentPath() -> String? {
        guard let parent = self.parent, let parentPath = parent.path else {
            return nil
        }
        if let grandParentPath = parent.parentPath() {
            return "/\(grandParentPath)/\(parentPath)"
        }
        return "/\(parentPath)"
    }
}
