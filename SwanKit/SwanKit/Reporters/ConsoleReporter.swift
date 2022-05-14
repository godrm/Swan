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
        var result = [String]()
        for occurrence in occurrences {
            result.append(occurrence.description)
        }
        let report = result.joined(separator: "\n")
        let data = report.data(using: .utf8)
        try? data?.write(to: URL(fileURLWithPath: "/var/tmp/swan-report.txt"))
        print(report)
        return result
    }
}
