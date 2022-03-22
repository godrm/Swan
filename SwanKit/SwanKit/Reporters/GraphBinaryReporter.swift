//
//  GraphBinaryReporter.swift
//  SwanKit
//
//  Created by JK on 2022/03/22.
//
import Foundation
import IndexStoreDB
import GraphViz

public struct GraphBinaryReporter: Reporter {
    private func filename(from path:String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.lastPathComponent
    }
    
    public func report(_ configuration: Configuration, sources: [SourceDetail:[SymbolOccurrence]]) -> [String] {
        var graph = Graph(directed: true)
        var fileMap = Dictionary<String, Subgraph>()
        var nodeMap = Dictionary<String, Node>()
        var clusterIndex = 1
        
        for key in sources.keys {
            let name = filename(from: key.location.path)
            var subgraph : Subgraph? = fileMap[name]
            if subgraph == nil {
                subgraph = Subgraph(id: "cluster_\(clusterIndex)", label: name)
                clusterIndex += 1
                subgraph?.textColor = Color.named(.blue)
                subgraph?.borderWidth = 1
                subgraph?.borderColor = Color.named(.blue)
                fileMap[name] = subgraph
                graph.append(subgraph!)
            }
            var keyName = "\(key.name)"
            if (key.sourceKind == .protocol) {
                keyName = "<<\(key.name)>>"
            }
            else if (key.sourceKind == .function) {
                continue
            }
            let node = Node(keyName)
            if key.sourceKind == .class || key.sourceKind == .enum || key.sourceKind == .struct || key.sourceKind == .typealias {
                node.shape = .box
                node.textColor = Color.named(.darkviolet)
            }
            else if key.sourceKind == .protocol {
                node.shape = .box
                node.textColor = Color.named(.darkseagreen4)
            }
            nodeMap[key.name] = node
            subgraph?.append(node)
        }
        
        let edges = Set<Edge>()
        for key in sources.keys {
            guard let node = nodeMap[key.name] else { continue }
            for reference in sources[key]! {
                guard let relation = reference.relations.first else { continue }
                let name = filename(from: reference.location.path)
                var subgraph : Subgraph? = fileMap[name]
                if subgraph == nil {
                    subgraph = Subgraph(id: "cluster_\(clusterIndex)", label: name)
                    clusterIndex += 1
                    subgraph?.textColor = Color.named(.blue)
                    subgraph?.borderWidth = 1
                    subgraph?.borderColor = Color.named(.blue)
                    fileMap[name] = subgraph
                    graph.append(subgraph!)
                }
                var symbolName = "\(relation.symbol.name)"
                if (relation.symbol.kind == .protocol) {
                    symbolName = "<<\(relation.symbol.name)>>"
                }
                guard key.name != symbolName else { continue }
                var other = nodeMap[symbolName]
                if other == nil {
                    if relation.symbol.kind == .instanceProperty ||
                        relation.symbol.kind == .classProperty ||
                        relation.symbol.kind == .staticProperty ||
                        relation.symbol.kind == .variable { continue }
                    if (relation.symbol.kind == .staticMethod || relation.symbol.kind == .classMethod) {
                        symbolName = "+\(relation.symbol.name)"
                    }
                    else if (relation.symbol.kind == .instanceMethod) {
                        symbolName = "-\(relation.symbol.name)"
                    }

                    other = Node(symbolName)
                    nodeMap[symbolName] = other
                    subgraph?.append(other!)
                }
                var edge = Edge(from: other!, to: node)
                guard !edges.contains(edge) else { continue }
                if key.sourceKind == .protocol {
                    edge.style = .dashed
                }
                subgraph?.append(edge)
            }
        }

        // Render image using dot layout algorithm
        let data = try! graph.render(using: .dot, to: .pdf)
        try? data.write(to: URL(fileURLWithPath: configuration.outputFile.pathString))
        return [configuration.outputFile.pathString]
    }
}
