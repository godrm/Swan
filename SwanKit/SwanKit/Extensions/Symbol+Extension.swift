//
//  Symbol+Extension.swift
//  SwanKit
//
//  Created by JK on 2022/05/12.
//

import Foundation

import IndexStoreDB

extension Symbol {
    /// Whether self is object
    func isKindOfObject() -> Bool {
        return self.kind == .class || self.kind == .struct || self.kind == .protocol ||
               self.kind == .enum || self.kind == .extension || self.kind == .typealias
    }
}
