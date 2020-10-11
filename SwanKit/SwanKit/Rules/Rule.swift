import Foundation
import SwiftSyntax
import IndexStoreDB

public protocol Rule {}

public protocol SourceCollectRule: Rule {
    
    func skip(_ node: SyntaxProtocol, location: SourceLocation) -> Bool
}

public protocol AnalyzeRule: Rule {
    
    func analyze(_ source: SourceDetail) -> Bool
}


