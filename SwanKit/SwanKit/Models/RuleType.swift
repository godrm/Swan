//
//  RuleType.swift
//  SwanKit
//
//  Created by JK on 2020/10/09.
//
import Foundation

public enum RuleType: String, Decodable, CaseIterable {
    
    case skipPublic = "skip_public"
    case xctest
    case attributes
    case comment
    case superClass = "super_class"
    case skipOptionaFunction = "skip_optional_function"
}
