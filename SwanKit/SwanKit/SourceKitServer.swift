//
//  SourceKitServer.swift
//  SwanKit
//
//  Created by JK on 2020/10/09.
//

import Foundation
import IndexStoreDB

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
                !symbol.roles.contains(.accessorOf) &&
                symbol.roles.contains(.definition) {
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
        return index.occurrences(ofUSR: usr, roles: roles)
    }
}
