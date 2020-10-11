//
//  Validation.swift
//  SwanKit
//
//  Created by JK on 2020/10/09.
//
import Foundation

class Validation {

    private enum RegexTypes: Regex {
        // TODO: This is not the most correct regex, optimized later
        case notOperator = ".*[a-zA-Z]+.*"
    }

    static func isOperator(_ str: String) -> Bool {
        return !RegexTypes.notOperator.rawValue.matches(str)
    }
}
