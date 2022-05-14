import Foundation
import IndexStoreDB

extension SymbolOccurrence {
    /// Whether  is override of giving symbol
    /// - Parameter symbol: giving symbol
    func isOverride(of symbol: SymbolOccurrence) -> Bool {
        relations.contains(where: { $0.roles.contains(.overrideOf) && $0.symbol.usr == symbol.symbol.usr})
    }
    
    func isImplicitProperty() -> Bool {
        return ((self.roles.contains(.implicit) && self.roles.contains(.definition)) ||
                (self.roles.contains(.accessorOf) && self.roles.contains(.definition)) ) &&
                self.relations.count == 1 &&
                (self.symbol.name.hasPrefix("getter:") ||
                 self.symbol.name.hasPrefix("setter:"))
    }
}

extension SymbolOccurrence {
    var identifier: String {
        return "\(location.path):\(location.line):\(location.utf8Column)"
    }
}
