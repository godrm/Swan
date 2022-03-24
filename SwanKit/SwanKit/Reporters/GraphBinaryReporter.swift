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
        var typeMap = Dictionary<String, Subgraph>()
        var nodeMap = Dictionary<String, Node>()
        var clusterIndex = 1
        
        for key in sources.keys {
            let name = filename(from: key.location.path)
            var subgraph : Subgraph? = fileMap[key.location.path]
            if subgraph == nil {
                subgraph = Subgraph(id: "cluster_\(clusterIndex)", label: name)
                clusterIndex += 1
                subgraph?.textColor = Color.named(.blue)
                subgraph?.borderWidth = 1
                subgraph?.borderColor = Color.named(.blue)
                fileMap[key.location.path] = subgraph
                graph.append(subgraph!)
            }
            var keyName = "\(key.name)"
            if (key.sourceKind == .protocol) {
                keyName = "<<\(key.name)>>"
            }

            guard let reference = sources[key]?.first else { continue }
            if (reference.symbol.kind == .staticMethod || reference.symbol.kind == .classMethod) {
                keyName = "+\(reference.symbol.name)"
            }
            else if (reference.symbol.kind == .instanceMethod) {
                keyName = "-\(reference.symbol.name)"
            }

            let node = Node(reference.symbol.usr)
            node.label = keyName
            if key.sourceKind == .class || key.sourceKind == .enum || key.sourceKind == .struct || key.sourceKind == .typealias {
                node.shape = .box
                node.textColor = Color.named(.darkviolet)
            }
            else if key.sourceKind == .protocol {
                node.shape = .box
                node.textColor = Color.named(.darkseagreen4)
            }
            nodeMap[reference.symbol.usr] = node
            subgraph?.append(node)
        }
        
        let edges = Set<Edge>()
        for key in sources.keys {
            for reference in sources[key]! {
                guard let node = nodeMap[reference.symbol.usr] else { continue }
                guard let relation = reference.relations.first else { continue }
                let name = filename(from: reference.location.path)
                let keyFilename = filename(from: key.location.path)
                
                var subgraphTo : Subgraph? = fileMap[key.location.path]
                if subgraphTo == nil {
                    subgraphTo = Subgraph(id: "cluster_\(clusterIndex)", label: keyFilename)
                    clusterIndex += 1
                    subgraphTo?.textColor = Color.named(.blue)
                    subgraphTo?.borderWidth = 1
                    subgraphTo?.borderColor = Color.named(.blue)
                    fileMap[key.location.path] = subgraphTo
                    graph.append(subgraphTo!)
                }
                
                var subgraphFrom : Subgraph? = fileMap[reference.location.path]
                if subgraphFrom == nil {
                    subgraphFrom = Subgraph(id: "cluster_\(clusterIndex)", label: name)
                    clusterIndex += 1
                    subgraphFrom?.textColor = Color.named(.blue)
                    subgraphFrom?.borderWidth = 1
                    subgraphFrom?.borderColor = Color.named(.blue)
                    fileMap[reference.location.path] = subgraphFrom
                    graph.append(subgraphFrom!)
                }

                var symbolName = "\(relation.symbol.name)"
                if (relation.symbol.kind == .protocol) {
                    symbolName = "<<\(relation.symbol.name)>>"
                }
                var other = nodeMap[relation.symbol.usr]
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
                    other = Node(relation.symbol.usr)
                    other?.label = symbolName
                    nodeMap[relation.symbol.usr] = other
                    subgraphFrom?.append(other!)
                }
                var edge = Edge(from: other!, to: node)
                guard !edges.contains(edge) else { continue }
                if key.sourceKind == .protocol {
                    edge.style = .dashed
                }
                graph.append(edge)
            }
        }

        // Render image using dot layout algorithm
        let data = try! graph.render(using: .dot, to: .pdf)
        try? data.write(to: URL(fileURLWithPath: configuration.outputFile.pathString))
        return [configuration.outputFile.pathString]
    }
}
