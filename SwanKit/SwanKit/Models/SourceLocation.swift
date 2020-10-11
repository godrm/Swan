//
//  SourceLocation.swift
//  SwanKit
//
//  Created by JK on 2020/10/09.
//
import Foundation
import SwiftSyntax

public typealias SSSourceLocation = SwiftSyntax.SourceLocation

public struct SourceLocation {
    public let path: String
    public let line: Int
    public let column: Int
    public let offset: Int
}

extension SourceLocation: CustomStringConvertible {
    public var description: String {
        "\(path):\(line):\(column)"
    }
}

extension SourceLocation: Equatable, Hashable {
    public static func == (lhs: SourceLocation, rhs: SourceLocation) -> Bool {
        lhs.path == rhs.path && lhs.line == rhs.line && lhs.column == rhs.column
    }
}

extension SourceLocation {
    /// Converts a `SourceLocation` to a `SwiftSyntax.SourceLocation`.
    public var toSSLocation: SSSourceLocation {
        return SSSourceLocation(
            line: line,
            column: column,
            offset: offset,
            file: path)
    }
}
