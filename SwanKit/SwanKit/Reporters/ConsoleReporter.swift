//
//  ConsoleReporter.swift
//  SwanKit
//
//  Created by JK on 2020/10/11.
//
import Foundation
import IndexStoreDB

public struct ConsoleReporter: Reporter {
    
    public func report(_ configuration: Configuration, sources: [SourceDetail:[SymbolOccurrence]]) {
        var entries = sources.map { "key: \($0.key), values: \($0.value)" }
                print(entries)
    }
}
