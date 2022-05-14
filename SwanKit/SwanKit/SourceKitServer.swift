//
//  SourceKitServer.swift
//  SwanKit
//
//  Created by JK on 2020/10/09.
//

import Foundation
import IndexStoreDB

extension SymbolLocation : Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.moduleName)
        hasher.combine(self.path)
        hasher.combine(self.line)
        hasher.combine(self.utf8Column)
    }
}

extension SymbolOccurrence : Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.symbol)
        hasher.combine(self.roles)
        hasher.combine(self.location)
        for relation in self.relations {
            hasher.combine(relation.symbol)
            hasher.combine(relation.roles)
        }
    }
}

class SourceKitServer {
    
    let workspace: Workspace?
    
    init(workspace: Workspace? = nil) {
        self.workspace = workspace
    }
    
    func findWorkspaceSymbols(matching: String) -> [SymbolOccurrence] {
        var symbolOccurrenceResults: [SymbolOccurrence] = []
        workspace?.index?.forEachCanonicalSymbolOccurrence(
          containing: matching,
          anchorStart: true,
          anchorEnd: true,
          subsequence: true,
          ignoreCase: true
        ) { symbol in
            if !symbol.location.isSystem &&
                !symbol.roles.contains(.accessorOf) {
            symbolOccurrenceResults.append(symbol)
          }
          return true
        }
        return symbolOccurrenceResults
    }
    
    func occurrences(ofUSR usr: String, roles: SymbolRole, workspace: Workspace) -> [SymbolOccurrence] {
        guard let index = workspace.index else {
            return []
        }
        var result: Set<SymbolOccurrence> = []
        index.forEachSymbolOccurrence(byUSR: usr, roles: roles) { occur in
            result.insert(occur)
            return true
        }
        return Array(result)
    }
}
