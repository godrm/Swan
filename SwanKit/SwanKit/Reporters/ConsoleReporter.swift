import Foundation
import IndexStoreDB

public struct ConsoleReporter: Reporter {
    
    public func report(_ configuration: Configuration, sources: [SourceDetail:[SymbolOccurrence]]) {
        var entries = sources.map { "key: \($0.key), values: \($0.value)" }
                print(entries)
    }
}

private func writeEntries(entries: [String], to path: URL) throws {
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(entries)
        try data.write(to: path, options: .atomic)
    }
}
