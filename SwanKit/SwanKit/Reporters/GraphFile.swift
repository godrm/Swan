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
        var moduleMap = Dictionary<String, Subgraph>()
        var fileMap = Dictionary<String, Node>()
        var usrToFileMap = Dictionary<String, String>()
        var moduleIndex = 1
        var edges = Set<Edge>()

        let allSymbols = sources[SourceDetail.init()]!
        for selected in allSymbols {
            var module : Subgraph? = moduleMap[selected.location.moduleName]
            if module == nil {
                module = Subgraph(id: "cluster_m\(moduleIndex)", label: selected.location.moduleName)
                moduleIndex += 1
                module?.textColor = Color.named(.indianred4)
                module?.borderWidth = 1
                module?.borderColor = Color.named(.indianred4)
                moduleMap[selected.location.moduleName] = module
                graph.append(module!)
            }
            
            let name = filename(from: selected.location.path)
            var node = fileMap[selected.location.path]
            if node == nil {
                node = Node(selected.location.path)
                node?.label = name
                node?.shape = .box
                node?.textColor = Color.named(.darkviolet)
                fileMap[selected.location.path] = node
                module?.append(node!)
            }

            if selected.roles.contains(.definition) || selected.relations.count == 0  {
                usrToFileMap[selected.symbol.usr] = selected.location.path
            }
        }
            
        for selected in allSymbols {
            guard let filePath = usrToFileMap[selected.symbol.usr] else { continue }
            guard let node = fileMap[filePath] else { continue }
            if selected.symbol.kind == .parameter { continue }
            for relation in selected.relations {
                if relation.roles.contains(.childOf) &&
                    ( relation.symbol.kind == .struct ||
                      relation.symbol.kind == .class ||
                      relation.symbol.kind == .enum) {
                    usrToFileMap[selected.symbol.usr] = selected.location.path
                    continue
                }
                else if relation.roles.contains(.overrideOf) ||
                            relation.symbol.kind == .variable && relation.roles.contains(.containedBy) {
                    continue
                }
                else if relation.roles.contains(.childOf) &&
                        (relation.symbol.kind == .classProperty ||
                        relation.symbol.kind == .instanceProperty) &&
                        (selected.symbol.kind == .parameter ||
                         selected.symbol.kind == .instanceMethod) {
                    continue
                }
                                
                if relation.roles.contains(.receivedBy) {
                    usrToFileMap[relation.symbol.usr] = filePath
                    continue
                }
                
                guard let filePath = usrToFileMap[relation.symbol.usr] else { continue }
                if let fromNode = fileMap[filePath] {
                    if fromNode == node { continue }
                    let edge = Edge(from: fromNode, to: node)
                    guard !edges.contains(edge) else { continue }
                    edges.insert(edge)
                    graph.append(edge)
                }
                else {
                    let fromNode = Node(relation.symbol.usr)
                    if fromNode == node { continue }
                    fromNode.label = relation.symbol.name
                    fromNode.textColor = Color.named(.gray)
                    let edge = Edge(from: fromNode, to: node)
                    guard !edges.contains(edge) else { continue }
                    edges.insert(edge)
                    graph.append(edge)
                }
            }
        }

        // Render image using dot layout algorithm
        _ = try! graph.render(using: .dot, to: .pdf, output: configuration.outputFile.pathString)
        return [configuration.outputFile.pathString]
    }
}
