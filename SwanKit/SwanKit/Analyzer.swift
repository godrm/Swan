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
    
    public func analyze() throws -> [SourceDetail: [SymbolOccurrence]] {
        let foundSource = ThreadSafe<[SourceDetail: [SymbolOccurrence]]>([:])
        sourceCodeCollector.collect()

        DispatchQueue.concurrentPerform(iterations: sourceCodeCollector.sources.count) { (index) in
                let symbol = sourceCodeCollector.sources[index]
                let occurs = analyze(source: symbol)
                foundSource.atomically {
                    $0[sourceCodeCollector.sources[index]] = occurs
                }
        }
        return foundSource.value
    }
    
    public func analyzeSymbols() throws -> [SymbolOccurrence] {
        let foundSource = ThreadSafe<[SymbolOccurrence]>([])
        sourceCodeCollector.collectSymbols(with: workSpace.index!, for: xcodeproj.pbxproj.buildFiles)

        DispatchQueue.concurrentPerform(iterations: sourceCodeCollector.symbols.count) { (index) in
                let symbol = sourceCodeCollector.symbols[index]
                let occurs = analyze(symbol: symbol)
                foundSource.atomically {
                    $0.append(contentsOf: occurs)
                }
        }
        return foundSource.value
    }

}

extension Analyzer {
    
    /// Detect  whether source code if used
    /// - Parameter source: The source code to detect.
    private func analyze(source: SourceDetail) -> [SymbolOccurrence] {
        let symbols = sourceKitserver.findWorkspaceSymbols(matching: source.name)
        print("\(source.name) => \(symbols)")
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
            roles: [.reference, .calledBy, .receivedBy, .canonical, .containedBy, .definition, .declaration, .extendedBy],
            workspace: workSpace)
                   
        return symbolOccurrenceResults
    }
    
    private func analyze(symbol: Symbol) -> [SymbolOccurrence] {

        let symbolOccurrenceResults = sourceKitserver.occurrences(
            ofUSR: symbol.usr,
            roles: [.reference, .calledBy, .canonical, .containedBy, .definition, .declaration, .extendedBy, .childOf, .ibTypeOf],
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
