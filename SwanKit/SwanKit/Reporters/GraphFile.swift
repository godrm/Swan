//
//  GraphBinaryReporter.swift
//  SwanKit
//
//  Created by JK on 2022/03/23.
//
import Foundation
import IndexStoreDB
import GraphViz

public struct GraphFileReporter: Reporter {
    private func filename(from path:String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.lastPathComponent
    }
    
    public func report(_ configuration: Configuration, sources: [SourceDetail:[SymbolOccurrence]]) -> [String] {
        var graph = Graph(directed: true)
        var nodeMap = Dictionary<String, Node>()
        
        for key in sources.keys {
            let name = filename(from: key.location.path)
            var node = nodeMap[name]
            if node == nil {
                node = Node(name, path:key.location.path)
                node?.shape = .box
                node?.textColor = Color.named(.darkviolet)
                nodeMap[name] = node
                graph.append(node!)
            }
        }
        
        var edges = Set<Edge>()
        for key in sources.keys {
            let keyFilename = filename(from: key.location.path)
            guard let node = nodeMap[keyFilename] else { continue }
            for reference in sources[key]! {
                guard let relation = reference.relations.first else { continue }
                let name = filename(from: reference.location.path)
                guard keyFilename != name else { continue }
                var other = nodeMap[name]
                if other == nil {
                    other = Node(name, path: reference.location.path)
                    other?.shape = .box
                    other?.textColor = Color.named(.darkviolet)
                    nodeMap[name] = other
                    graph.append(other!)
                }
                let edge = Edge(from: other!, to: node)
                guard !edges.contains(edge) else { continue }
                edges.insert(edge)
                graph.append(edge)
            }
        }

        // Render image using dot layout algorithm
        let data = try! graph.render(using: .dot, to: .pdf)
        try? data.write(to: URL(fileURLWithPath: configuration.outputFile.pathString))
        return [configuration.outputFile.pathString]
    }
}
