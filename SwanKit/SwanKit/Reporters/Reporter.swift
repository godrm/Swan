import Foundation
import IndexStoreDB

public protocol Reporter {
    
    func report(_ configuration: Configuration, occurrences: [SymbolOccurrence]) -> [String]
}
