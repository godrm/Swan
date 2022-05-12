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

public final class Analyzer {
    private let sourceCodeCollector: SourceCollector
    private let sourceKitserver: SourceKitServer
    private let workSpace: Workspace
    private let configuration: Configuration
    private let xcodeproj : XcodeProj
    
    public init(configuration: Configuration) throws {
        sourceCodeCollector = SourceCollector(rootPath: configuration.projectPath,
                                              configuration: configuration)
        self.configuration = configuration
        let buildSystem = DatabaseBuildSystem(indexStorePath: configuration.indexStorePath,
                                              indexDatabasePath: configuration.indexDatabasePath)
        workSpace = try Workspace(buildSettings: buildSystem)
        workSpace.index?.pollForUnitChangesAndWait()
        sourceKitserver = SourceKitServer(workspace: workSpace)
        xcodeproj = try XcodeProj.init(pathString: configuration.projectFilePath.pathString)
    }
        
    public func analyzeSymbols() throws -> [SymbolOccurrence] {
        let foundSource = ThreadSafe<Set<SymbolOccurrence>>([])
        var buildFiles = xcodeproj.pbxproj.buildFiles
        
        sourceCodeCollector.collectSymbols(with: workSpace.index!, for: buildFiles)
        
        DispatchQueue.concurrentPerform(iterations: sourceCodeCollector.symbols.count) { (index) in
                let symbol = sourceCodeCollector.symbols[index]
                let occurs = analyze(symbol: symbol)
                foundSource.atomically {
                    for occur in occurs {
                        if sourceCodeCollector.hasSource(filePath: occur.location.path) {
                            $0.insert(occur)
                        }
                    }
                }
        }
        return Array(foundSource.value)
    }
}

extension Analyzer {
    private func analyze(symbol: Symbol) -> [SymbolOccurrence] {
        let symbolOccurrenceResults = sourceKitserver.occurrences(
            ofUSR: symbol.usr,
            roles: [.reference, .calledBy, .canonical, .containedBy, .definition, .declaration, .extendedBy, .childOf, .ibTypeOf],
            workspace: workSpace)
                   
        return symbolOccurrenceResults
    }
}
