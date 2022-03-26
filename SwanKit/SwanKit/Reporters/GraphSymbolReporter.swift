//
//  GraphBinaryReporter.swift
//  SwanKit
//
//  Created by JK on 2022/03/22.
//
import Foundation
import IndexStoreDB
import GraphViz

public struct GraphSymbolReporter: Reporter {
    private func filename(from path:String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.lastPathComponent
    }
    
    public func report(_ configuration: Configuration, sources: [SourceDetail:[SymbolOccurrence]]) -> [String] {
        var graph = Graph(directed: true)
        var fileMap = Dictionary<String, Subgraph>()
        var nodeMap = Dictionary<String, Node>()
        var clusterIndex = 1
        
        let allSymbols = sources[SourceDetail.init()]!
        let edges = Set<Edge>()
        for selected in allSymbols {
            let name = filename(from: selected.location.path)
            var subgraph : Subgraph? = fileMap[selected.location.path]
            if subgraph == nil {
                subgraph = Subgraph(id: "cluster_\(clusterIndex)", label: name)
                clusterIndex += 1
                subgraph?.textColor = Color.named(.blue)
                subgraph?.borderWidth = 1
                subgraph?.borderColor = Color.named(.blue)
                fileMap[selected.location.path] = subgraph
                graph.append(subgraph!)
            }
            
            var label = "\(selected.symbol.name)"
            if (selected.symbol.kind == .protocol) {
                label = "<<\(selected.symbol.name)>>"
            }
            else if (selected.symbol.kind == .staticMethod || selected.symbol.kind == .classMethod) {
                label = "+\(selected.symbol.name)"
            }
            else if (selected.symbol.kind == .instanceMethod) {
                label = "-\(selected.symbol.name)"
            }
            var node = Node(selected.symbol.usr)
            node.label = label
            if selected.symbol.kind == .class || selected.symbol.kind == .enum || selected.symbol.kind == .struct || selected.symbol.kind == .typealias {
                node.shape = .box
                node.textColor = Color.named(.darkviolet)
            }
            else if selected.symbol.kind == .protocol {
                node.shape = .box
                node.textColor = Color.named(.darkseagreen4)
            }
            nodeMap[selected.symbol.usr] = node
            subgraph?.append(node)

            for relation in selected.relations {
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
                }
                var edge = Edge(from: other!, to: node)
                guard !edges.contains(edge) else { continue }
                if selected.symbol.kind == .protocol {
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
