import Foundation
import IndexStoreDB

public protocol Reporter {
    
    func report(_ configuration: Configuration, sources: [SourceDetail:[SymbolOccurrence]]) -> [String]
}
