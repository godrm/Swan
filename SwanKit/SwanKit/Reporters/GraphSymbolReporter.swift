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
        var moduleMap = Dictionary<String, Subgraph>()
        var fileMap = Dictionary<String, Subgraph>()
        var nodeMap = Dictionary<String, Node>()
        var usrToFileMap = Dictionary<String, String>()
        let edges = Set<Edge>()
        var clusterIndex = 1
        var moduleIndex = 1

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
            var file : Subgraph? = fileMap[selected.location.path]
            if file == nil {
                file = Subgraph(id: "cluster_f\(clusterIndex)", label: name)
                clusterIndex += 1
                file?.textColor = Color.named(.blue)
                file?.borderWidth = 1
                file?.borderColor = Color.named(.blue)
                fileMap[selected.location.path] = file
                module?.append(file!)
            }
            
            if selected.roles.contains(.definition) || selected.relations.count == 0  {
                if selected.relations.count == 1 && (
                     selected.relations.first?.symbol.kind == .staticProperty ||
                     selected.relations.first?.symbol.kind == .parameter ||
                     selected.relations.first?.symbol.kind == .classProperty ||
                     selected.relations.first?.symbol.kind == .instanceProperty) {
                    continue
                }
                if selected.symbol.kind == .parameter ||
                    selected.symbol.kind == .extension ||
                    selected.symbol.kind == .enumConstant ||
                    selected.roles.contains(.dynamic) {
                    continue
                }
                
//                if selected.symbol.kind == .enum ||
//                    selected.symbol.kind == .struct ||
//                    selected.symbol.kind == .class {
//                    var type : Subgraph? = typeMap[selected.location.path]
//                    if type == nil {
//                        type = Subgraph(id: "cluster_f\(clusterIndex)", label: selected.symbol.name)
//                        clusterIndex += 1
//                        type?.textColor = Color.named(.blue)
//                        type?.borderWidth = 1
//                        type?.borderColor = Color.named(.blue)
//                        typeMap[selected.location.path] = type
//                        file?.append(type!)
//                    }
//                    continue
//                }
                
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

                var node = nodeMap[selected.symbol.usr]
                if node == nil {
                    node = Node(selected.symbol.usr)
                    node?.label = label //+ ((selected.symbol.properties.contains(.ibAnnotated) || selected.symbol.properties.contains(.ibOutletCollection)) ? "@IB" : "")
                    if selected.symbol.kind == .class || selected.symbol.kind == .enum || selected.symbol.kind == .struct || selected.symbol.kind == .typealias {
                        node?.shape = .box
                        node?.textColor = Color.named(.darkviolet)
                    }
                    else if selected.symbol.kind == .protocol {
                        node?.shape = .box
                        node?.textColor = Color.named(.darkseagreen4)
                    }
                    nodeMap[selected.symbol.usr] = node!
                    file?.append(node!)
                    usrToFileMap[selected.symbol.usr] = selected.location.path
                }
            }
        }
            
        for selected in allSymbols {
            let file : Subgraph? = fileMap[selected.location.path]
            
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

            if selected.symbol.kind == .parameter ||
                selected.symbol.kind == .enumConstant ||
                selected.relations.count == 1 && selected.relations.first?.symbol.kind == .parameter ||
                selected.relations.count == 1 && selected.relations.first?.symbol.kind == .staticProperty {
                continue
            }

            var node = nodeMap[selected.symbol.usr]
            if node == nil {
                node = Node(selected.symbol.usr)
                node?.label = label + ((selected.symbol.properties.contains(.ibAnnotated) || selected.symbol.properties.contains(.ibOutletCollection)) ? "@IB" : "")
                if selected.symbol.kind == .class || selected.symbol.kind == .enum || selected.symbol.kind == .struct || selected.symbol.kind == .typealias {
                    node?.shape = .box
                    node?.textColor = Color.named(.darkviolet)
                }
                else if selected.symbol.kind == .protocol {
                    node?.shape = .box
                    node?.textColor = Color.named(.darkseagreen4)
                }
                nodeMap[selected.symbol.usr] = node!
            }

            for relation in selected.relations {
                if relation.roles.contains(.childOf) &&
                    ( relation.symbol.kind == .struct ||
                      relation.symbol.kind == .class ||
                      relation.symbol.kind == .enum) {
                    file?.append(node!)
                    usrToFileMap[selected.symbol.usr] = selected.location.path
                    continue
                }
                else if relation.symbol.kind == .parameter ||
                            relation.symbol.kind == .extension ||
                            relation.roles.contains(.overrideOf) ||
                            relation.symbol.kind == .variable && relation.roles.contains(.containedBy) {
                    continue
                }
                else if relation.roles.contains(.childOf) &&
                        (relation.symbol.kind == .classProperty ||
                         relation.symbol.kind == .staticProperty ||
                        relation.symbol.kind == .instanceProperty) &&
                        (selected.symbol.kind == .parameter ||
                         selected.symbol.kind == .instanceMethod ||
                         selected.symbol.kind == .function ||
                         selected.symbol.kind == .staticMethod) {
                    continue
                }
                                
                if relation.roles.contains(.receivedBy) {
                    guard let recvFilePath = usrToFileMap[relation.symbol.usr],
                          let recvFile = fileMap[recvFilePath] else { continue }
                    recvFile.append(node!)
                    continue
                }
                
                if usrToFileMap[selected.symbol.usr] == nil {
                    file?.append(node!)
                    usrToFileMap[selected.symbol.usr] = selected.location.path
                }

                var symbolName = "\(relation.symbol.name)"
                if (relation.symbol.kind == .protocol) {
                    symbolName = "<<\(relation.symbol.name)>>"
                }
                var other = nodeMap[relation.symbol.usr]
                if other == nil {
                    if (relation.symbol.kind == .staticMethod || relation.symbol.kind == .classMethod) {
                        symbolName = "+\(relation.symbol.name)"
                    }
                    else if (relation.symbol.kind == .instanceMethod) {
                        symbolName = "-\(relation.symbol.name)"
                    }
                    other = Node(relation.symbol.usr)
                    other?.label = symbolName + (selected.symbol.properties.contains(.ibAnnotated) ? "@IB" : "")
                    nodeMap[relation.symbol.usr] = other
                }
                                
                var edge = Edge(from: other!, to: node!)
                guard !edges.contains(edge) else { continue }
                if selected.symbol.kind == .protocol {
                    edge.style = .dashed
                }
                graph.append(edge)
            }
        }
        
        // Render image using dot layout algorithm
        _ = try! graph.render(using: .dot, to: .pdf, output: configuration.outputFile.pathString)
        return [configuration.outputFile.pathString]
    }
}