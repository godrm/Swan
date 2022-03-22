//
//  ReporterType.swift
//  SwanKit
//
//  Created by JK on 2020/10/09.
//
import Foundation

///Detect result output type
public enum ReporterType: String, Decodable {
    
    /// Export to console
    case console
    
    /// Export dot for graphviz
    case graphviz

    /// Export dot(binary) for graphviz
    case graphvizBinary
}
