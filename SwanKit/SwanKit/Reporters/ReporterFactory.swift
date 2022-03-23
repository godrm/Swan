import Foundation

struct ReporterFactory {
    
    static func make(_ type: ReporterType?) -> Reporter {
        switch type {
        case .console:
            return ConsoleReporter()
        case .graphviz:
            return GraphReporter()
        case .graphvizBinary:
            return GraphBinaryReporter()
        case .graphvizFile:
            return GraphFileReporter()
        default:
            return ConsoleReporter()
        }
    }
}
