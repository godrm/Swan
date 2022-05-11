//
//  GraphBinaryReporter.swift
//  SwanKit
//
//  Created by JK on 2022/03/22.
//
import Foundation
import IndexStoreDB
import GraphViz
import DOT

public struct GraphSymbolReporter: Reporter {
    private func filename(from path:String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.lastPathComponent
    }
    
    public func report(_ configuration: Configuration, occurrences: [SymbolOccurrence]) -> [String] {
        var graph = Graph(directed: true)
        var moduleMap = Dictionary<String, Subgraph>()
        var fileMap = Dictionary<String, Subgraph>()
        var objectMap = Dictionary<String, Subgraph>()
        var nodeToObjectMap = Dictionary<Node, Subgraph>()
        var nodeMap = Dictionary<String, Node>()
        var usrToFileMap = Dictionary<String, String>()
        var implicitMap = Dictionary<String, Symbol>()
        var edges = Set<Edge>()
        var clusterIndex = 1
        var moduleIndex = 0

        let systemModule = Subgraph(id: "cluster_m\(moduleIndex)", label: "System")
        moduleIndex += 1
        systemModule.textColor = Color.named(.indianred4)
        systemModule.borderWidth = 1
        systemModule.borderColor = Color.named(.indianred4)
        moduleMap["System"] = systemModule
        graph.append(systemModule)

        for selected in occurrences {
            var module : Subgraph? = moduleMap[selected.location.moduleName]
            if module == nil {
                module = Subgraph(id: "cluster_m\(moduleIndex)", label: selected.location.moduleName + " Module")
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
                if (selected.roles.contains(.implicit) && selected.roles.contains(.definition) &&
                         selected.relations.count == 1 &&
                         (selected.symbol.name.hasPrefix("getter:") ||
                          selected.symbol.name.hasPrefix("setter:"))) {
                    implicitMap[selected.symbol.usr] = selected.relations.first!.symbol
                    continue
                }
                if selected.relations.count == 1 && (
                     selected.relations.first?.symbol.kind == .staticProperty ||
                     selected.relations.first?.symbol.kind == .parameter ||
                     selected.relations.first?.symbol.kind == .classProperty ||
                     selected.relations.first?.symbol.kind == .instanceProperty) {
                    continue
                }
                if selected.symbol.kind == .parameter ||
                    selected.symbol.kind == .extension ||
                    selected.symbol.kind == .enumConstant {
                    continue
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

                var node = nodeMap[selected.symbol.usr]
                if node == nil {
                    node = Node(selected.symbol.usr)
                    node?.label = label
                    if selected.symbol.kind == .class || selected.symbol.kind == .enum || selected.symbol.kind == .struct {
                        var object : Subgraph? = objectMap[selected.symbol.usr]
                        if object == nil {
                            object = Subgraph(id: "cluster_o\(clusterIndex)",
                                              label: "\(selected.symbol.kind) \(selected.symbol.name)")
                            clusterIndex += 1
                            object?.textColor = Color.named(.darkseagreen4)
                            object?.borderWidth = 1
                            object?.borderColor = Color.named(.darkseagreen4)
                            objectMap[selected.symbol.usr] = object
                            file?.append(object!)
                        }
                        node = nil
                        continue
                    }
                    else if selected.symbol.kind == .typealias {
                        node?.shape = .box
                        node?.textColor = Color.named(.darkviolet)
                    }
                    else if selected.symbol.kind == .protocol {
                        node?.shape = .box
                        node?.textColor = Color.named(.darkseagreen4)
                    }
                    else if selected.symbol.kind == .classProperty
                                || selected.symbol.kind == .staticProperty
                                ||  selected.symbol.kind == .instanceProperty {
                        node?.shape = .box
                        node?.label = "." + label
                    }
    
                    var objectMapped = false
                    for relation in selected.relations {
                        if relation.roles.contains(.childOf) &&
                            (relation.symbol.kind == .class || relation.symbol.kind == .enum || relation.symbol.kind == .struct) {
                            var object : Subgraph? = objectMap[relation.symbol.usr]
                            if object == nil {
                                object = Subgraph(id: "cluster_o\(clusterIndex)",
                                                  label: "\(relation.symbol.kind) \(relation.symbol.name)")
                                clusterIndex += 1
                                object?.textColor = Color.named(.darkseagreen4)
                                object?.borderWidth = 1
                                object?.borderColor = Color.named(.darkseagreen4)
                                objectMap[relation.symbol.usr] = object
                                file?.append(object!)
                            }
                            if nodeToObjectMap[node!] == nil {
                                object?.append(node!)
                                nodeToObjectMap[node!] = object
                            }
                            nodeMap[selected.symbol.usr] = node!
                            objectMapped = true
                            break
                        }
                    }
                    if !objectMapped {
                        nodeMap[selected.symbol.usr] = node!
                        file?.append(node!)
                        usrToFileMap[selected.symbol.usr] = selected.location.path
                    }
                }
            }
        }
            
        for selected in occurrences {
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
                selected.relations.count == 1 && selected.relations.first?.symbol.kind == .staticProperty
            {
                continue
            }

            var selectedUSR = selected.symbol.usr
            var node = nodeMap[selectedUSR]
            if node == nil {
                if let original = implicitMap[selected.symbol.usr] {
                    selectedUSR = original.usr
                }
                node = Node(selectedUSR)
                node?.label = label + ((selected.symbol.properties.contains(.ibAnnotated) || selected.symbol.properties.contains(.ibOutletCollection)) ? "@IB" : "")
                if selected.symbol.kind == .class || selected.symbol.kind == .enum || selected.symbol.kind == .struct || selected.symbol.kind == .typealias {
                    node?.shape = .box
                    node?.textColor = Color.named(.darkviolet)
                }
                else if selected.symbol.kind == .protocol {
                    node?.shape = .box
                    node?.textColor = Color.named(.darkseagreen4)
                }
            }

            for relation in selected.relations {
                let founded = nodeMap[selectedUSR] != nil
                if relation.roles.contains(.childOf) &&
                    ( relation.symbol.kind == .struct ||
                      relation.symbol.kind == .class ||
                      relation.symbol.kind == .enum) {
                    if founded {
                        var object : Subgraph? = objectMap[relation.symbol.usr]
                        if object == nil {
                            object = Subgraph(id: "cluster_o\(clusterIndex)", label: relation.symbol.name)
                            clusterIndex += 1
                            object?.textColor = Color.named(.darkseagreen4)
                            object?.borderWidth = 1
                            object?.borderColor = Color.named(.darkseagreen4)
                            objectMap[relation.symbol.usr] = object
                            file?.append(object!)
                        }
                        if nodeToObjectMap[node!] == nil {
                            object?.append(node!)
                            nodeToObjectMap[node!] = object
                        }
                    }
                    else {
                        file?.append(node!)
                        nodeMap[selectedUSR] = node!
                        usrToFileMap[selectedUSR] = selected.location.path
                    }
                    continue
                }
                else if relation.symbol.kind == .parameter ||
                            relation.symbol.kind == .extension ||
                            relation.roles.contains(.overrideOf) ||
                            relation.symbol.kind == .variable && relation.roles.contains(.containedBy) {
                    continue
                }
                else if relation.roles.contains(.childOf) &&
                        (selected.symbol.kind == .parameter ||
                         selected.symbol.kind == .instanceMethod ||
                         selected.symbol.kind == .function ||
                         selected.symbol.kind == .staticMethod) {
                    continue
                }
                                                
                if let object = objectMap[selectedUSR], nodeToObjectMap[node!] == nil &&  selected.roles.contains(.reference) {
                    object.append(node!)
                    nodeToObjectMap[node!] = object
                    nodeMap[selectedUSR] = node!
                }
                else if let object = objectMap[relation.symbol.usr], relation.roles.contains(.receivedBy) {
                    if nodeToObjectMap[node!] == nil {
                        object.append(node!)
                        nodeToObjectMap[node!] = object
                        nodeMap[relation.symbol.usr] = node!
                    }
                    else {
                        continue
                    }
                }
                else if relation.roles.contains(.receivedBy) && nodeMap[selectedUSR] == nil {
                    guard let recvFilePath = usrToFileMap[relation.symbol.usr],
                          let recvFile = fileMap[recvFilePath] else { continue }
                    nodeMap[selectedUSR] = node!
                    usrToFileMap[selectedUSR] = recvFilePath
                    recvFile.append(node!)
                    continue
                }
                else if nodeMap[selectedUSR] == nil {
                    file?.append(node!)
                    nodeMap[selectedUSR] = node!
                    usrToFileMap[selectedUSR] = selected.location.path
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
                    else if let object = objectMap[relation.symbol.usr], nodeToObjectMap[node!] == nil {
                        object.append(node!)
                        nodeToObjectMap[node!] = object
                        continue
                    }
                    other = Node(relation.symbol.usr)
                    other?.label = symbolName + (selected.symbol.properties.contains(.ibAnnotated) ? "@IB" : "")
                    if relation.symbol.kind == .class || relation.symbol.kind == .enum ||
                                relation.symbol.kind == .struct || relation.symbol.kind == .typealias {
                        other?.shape = .box
                        other?.textColor = Color.named(.darkviolet)
                    }
                    nodeMap[relation.symbol.usr] = other
                    if let object = objectMap[relation.symbol.usr], nodeToObjectMap[other!] == nil  {
                        object.append(other!)
                        nodeToObjectMap[other!] = object
                    }
                }
                                
                var edge = Edge(from: other!, to: node!)
                guard !edges.contains(edge) else { continue }
                edges.insert(edge)
                if selected.symbol.kind == .protocol {
                    edge.style = .dashed
                }
                graph.append(edge)
            }
        }
        
        // Render image using dot layout algorithm
        _ = try? graph.render(using: .dot, to: Format.pdf, output: configuration.outputFile.pathString)
        return [configuration.outputFile.pathString]
    }
}
