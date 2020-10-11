//
//  ReporterType.swift
//  SwanKit
//
//  Created by JK on 2020/10/09.
//
import Foundation

///Detect result output type
public enum ReporterType: String, Decodable {
    
    /// Warnings displayed in the IDE
    case xcode
    
    /// Export json file
    case json
}
