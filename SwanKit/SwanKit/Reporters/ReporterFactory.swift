import Foundation

struct ReporterFactory {
    
    static func make(_ type: ReporterType?) -> Reporter {
            return ConsoleReporter()
    }
}
