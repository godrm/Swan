//
//  Analyzer.swift
//  SwanKit
//
//  Created by JK on 2020/10/09.
//

import Foundation
import IndexStoreDB
import TSCBasic
import XcodeProj

public protocol SymbolFindable {
    func isInSPM(for locationPath: String) -> Bool
}

public final class Analyzer : SymbolFindable {
    private let sourceCodeCollector: SourceCollector
    private let sourceKitserver: SourceKitServer
    private let workSpace: Workspace
    private let configuration: Configuration
    private let xcodeproj : XcodeProj
    private var xcworkspace : XCWorkspace? = nil
    
    public init(configuration: Configuration) throws {
        self.configuration = configuration
        xcodeproj = try XcodeProj.init(pathString: configuration.projectFilePath.pathString)
        if let workspacePath = configuration.workspaceFilePath?.pathString {
            xcworkspace = try? XCWorkspace.init(pathString: workspacePath)
            let workspaceURL = URL(fileURLWithPath: workspacePath)
            let pathURL = workspaceURL.deletingLastPathComponent()
            sourceCodeCollector = SourceCollector(rootPath: AbsolutePath(pathURL.path),
                                              configuration: configuration,
                                              xcodeproj: xcodeproj,
                                              xcworkspace: xcworkspace)
        }
        else {
            sourceCodeCollector = SourceCollector(rootPath: configuration.projectPath,
                                              configuration: configuration,
                                              xcodeproj: xcodeproj,
                                              xcworkspace: nil)
        }
        let buildSystem = DatabaseBuildSystem(indexStorePath: configuration.indexStorePath,
                                              indexDatabasePath: configuration.indexDatabasePath)
        workSpace = try Workspace(buildSettings: buildSystem)
        workSpace.index?.pollForUnitChangesAndWait()
        sourceKitserver = SourceKitServer(workspace: workSpace)
    }
        
    public func analyzeSymbols() throws -> [SymbolOccurrence] {
        let foundSource = ThreadSafe<Set<SymbolOccurrence>>([])
        if xcworkspace != nil {
            sourceCodeCollector.collectSymbolsWorkspace(with: workSpace.index!, includeSPM: configuration.includeSPM)
        }
        else {
            sourceCodeCollector.collectSymbolsProject(with: workSpace.index!, includeSPM: configuration.includeSPM)
        }
        DispatchQueue.concurrentPerform(iterations: sourceCodeCollector.symbols.count) { (index) in
                let symbol = sourceCodeCollector.symbols[index]
                let occurs = analyze(symbol: symbol)
                foundSource.atomically {
                    let filtered = occurs.filter { sourceCodeCollector.hasSource(filePath: $0.location.path) }
                    for occur in filtered {
                        $0.insert(occur)
                    }
                }
        }
        return Array(foundSource.value)
    }

    private func analyze(symbol: Symbol) -> [SymbolOccurrence] {
        let symbolOccurrenceResults = sourceKitserver.occurrences(
            ofUSR: symbol.usr,
            roles: [.reference, .calledBy, .canonical, .containedBy, .definition, .declaration, .extendedBy, .childOf, .ibTypeOf],
            workspace: workSpace)
                   
        return symbolOccurrenceResults
    }
    
    public func isInSPM(for locationPath: String) -> Bool {
        return sourceCodeCollector.hasSourceInSPM(filePath: locationPath)
    }
}
