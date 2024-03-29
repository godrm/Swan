//
//  main.swift
//  Swan
//
//  Created by JK on 2022/05/11.
//

import Foundation
import SwanKit
import ArgumentParser
import IndexStoreDB

class Command: ParsableCommand {
    @Option var project: String?
    @Option var workspace: String?
    @Option var scheme: String?
    @Option var format: String?
    @Option var output: String?
    
    required init() {
    }
    
    func run() throws {
        let lock = DispatchGroup.init()
        
        print("""
            project = \(project ?? "") \
            scheme = \(scheme ?? "") for workspace = \(workspace ?? "")
            format = \(format ?? "")
            output = \(output ?? "")
            """)
        let projectManager = ProjectManager()

        let handler : (URL?, String, String, String?) -> Void = { [weak self] (targetURL, project, project_filepath, workspace_filepath) in
            guard let self = self, let target = targetURL, project.count > 0 else {
                lock.leave()
                return
            }
            var options = CommandLineOptions()
            options.buildPath = target.path
            options.path = project
            options.projectFilePath = project_filepath
            options.workspaceFilePath = workspace_filepath ?? ""
            options.mode = .init(rawValue: self.format ?? "console") ?? .console
            let sources = self.analyze(with: options)
            self.report(for: sources, with: options)
            lock.leave()
        }
        
        let projectURL = URL(fileURLWithPath: project ?? "")
        let workspaceURL = URL(fileURLWithPath: workspace ?? "")

        lock.enter()
        
        if projectManager.isProject(for: projectURL) {
            projectManager.grepProjectSetting(for: projectURL, completeHandler: handler)
        }
        else if projectManager.isWorkspace(for: workspaceURL) {
            projectManager.grepWorkspaceSchemeSetting(for: workspaceURL, scheme: scheme ?? "", completeHandler: handler)
        }
        
        lock.wait()
    }
    
    private func analyze(with options : CommandLineOptions) -> [SymbolOccurrence] {
        do {
            let configuration = try createConfiguration(options: options)
            let analyzer = try Analyzer(configuration: configuration)
            let symbols = try analyzer.analyzeSymbols()
            return symbols
        } catch {
            log(error.localizedDescription, level: .error)
        }
        return []
    }

    private func report(for sources: [SymbolOccurrence], with options: CommandLineOptions) {
        do {
            let configuration = try createConfiguration(options: options,
                                                        outputFile: output ?? ((options.mode == .graphviz) ? "swan.report.pdf" : "swan.report.md"))
            let _ = configuration.reporter.report(configuration, occurrences: sources)
        } catch {
            log(error.localizedDescription, level: .error)
        }
    }
}

Command.main()
