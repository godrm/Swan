//
//  ConsoleReporter.swift
//  SwanKit
//
//  Created by JK on 2020/10/11.
//
import Foundation
import IndexStoreDB

public struct ConsoleReporter: Reporter {
    
    public func report(_ configuration: Configuration, occurrences: [SymbolOccurrence]) -> [String] {
        var report = ""
        dump(occurrences, to: &report)
        let data = report.data(using: .utf8)
        try? data?.write(to: URL(fileURLWithPath: configuration.outputFile.pathString))
        print(report)
        return [report]
    }
}
