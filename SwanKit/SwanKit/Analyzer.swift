//
//  Analyzer.swift
//  SwanKit
//
//  Created by JK on 2020/10/09.
//

import Foundation
import IndexStoreDB
import TSCBasic

public final class Analyzer {
    private let sourceCodeCollector: SourceCollector
    private let sourceKitserver: SourceKitServer
    private let workSpace: Workspace
    private let configuration: Configuration
    
    public init(configuration: Configuration) throws {
        sourceCodeCollector = SourceCollector(rootPath: configuration.projectPath,
                                              configuration: configuration)
        self.configuration = configuration
        let buildSystem = DatabaseBuildSystem(indexStorePath: configuration.indexStorePath,
                                              indexDatabasePath: configuration.indexDatabasePath)
        workSpace = try Workspace(buildSettings: buildSystem)
        workSpace.index?.pollForUnitChangesAndWait()
        sourceKitserver = SourceKitServer(workspace: workSpace)        
    }
    
    public func analyze() throws -> [SourceDetail: [SymbolOccurrence]] {
        let deadSources = ThreadSafe<[SourceDetail: [SymbolOccurrence]]>([:])
        sourceCodeCollector.collect()

        DispatchQueue.concurrentPerform(iterations: sourceCodeCollector.sources.count) { (index) in
                let occurs = analyze(source: sourceCodeCollector.sources[index])
                deadSources.atomically {
                    $0[sourceCodeCollector.sources[index]] = occurs
                }
        }

        return deadSources.value
    }
    
    public func hello() -> String {
        return "hello"
    }
}

extension Analyzer {
    
    /// Detect  whether source code if used
    /// - Parameter source: The source code to detect.
    private func analyze(source: SourceDetail) -> [SymbolOccurrence] {
        let symbols = sourceKitserver.findWorkspaceSymbols(matching: source.name)

        // If not find symbol of source, means source used.
        guard let symbol = symbols.unique(of: source) else {
            return []
        }

        // Skip declarations that override another. This works for both subclass overrides &
        // protocol extension overrides.
        let overridden = symbols.lazy.filter{ $0.symbol.usr != symbol.symbol.usr }.contains(where: { $0.isOverride(of: symbol) })
        if overridden {
            return []
        }

        if symbol.roles.contains(.overrideOf) {
            return []
        }
        
        let symbolOccurrenceResults = sourceKitserver.occurrences(
            ofUSR: symbol.symbol.usr,
            roles: [.reference],
            workspace: workSpace)
                   
        return symbolOccurrenceResults
    }
    
    /// In the rule class, struct, enum and protocol extensions  are not mean  used,
    /// But in symbol their extensions are defined as referred,
    /// So we need to filter their extensions.
    /// - Parameters:
    ///   - source: The source code, determine if need filter by source kind.
    ///   - symbols: All the source symbols
    private func filterExtension(source: SourceDetail, symbols: [SymbolOccurrence]) -> [SymbolOccurrence] {
        guard source.needFilterExtension else {
            return symbols
        }
        return symbols.lazy.filter { !$0.isSourceExtension(safeSources: sourceCodeCollector.sourceExtensions) }
    }
}
