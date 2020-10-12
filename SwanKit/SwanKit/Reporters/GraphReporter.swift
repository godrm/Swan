//
//  GraphReporter.swift
//  SwanKit
//
//  Created by JK on 2020/10/11.
//
import Foundation
import IndexStoreDB
import GraphViz
import DOT

public struct GraphReporter: Reporter {
    private func filename(from path:String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.lastPathComponent
    }
    
    public func report(_ configuration: Configuration, sources: [SourceDetail:[SymbolOccurrence]]) {
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
            let node = Node((key.sourceKind == .protocol) ? "<\(key.name)>": key.name)
            if key.sourceKind == .class || key.sourceKind == .enum || key.sourceKind == .struct {
                node.textColor = Color.named(.darkviolet)
            }
            nodeMap[key.name] = node
            subgraph?.append(node)
        }
        
        for key in sources.keys {
            let node = nodeMap[key.name]
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
                var other = nodeMap[relation.symbol.name]
                if other == nil {
                    other = Node(relation.symbol.name)
                    nodeMap[relation.symbol.name] = other
                    subgraph?.append(other!)
                }
                let edge = Edge(from: other!, to: node!)
                subgraph?.append(edge)
            }
        }

        // Render image using dot layout algorithm
        let data = try! graph.render(using: .dot, to: .png)
        try? data.write(to: URL(fileURLWithPath: configuration.outputFile.pathString))
    }
}
