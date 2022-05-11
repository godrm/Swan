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
    @Option var project: String
    @Option var workspace: String?
    @Option var scheme: String?
    
    required init() {
    }
    
    func run() throws {
        print("""
            project = \(project) \
            scheme = \(scheme) for workspace = \(workspace)
            """)
        let projectManager = ProjectManager()

        let handler : (URL?, String, String) -> Void = { [weak self] (targetURL, project, project_filepath) in
            guard let self = self, let target = targetURL, project.count > 0 else { return }
            var options = CommandLineOptions()
            options.indexStorePath = target.path
            options.path = project
            options.project_filepath = project_filepath
            options.mode = .graphviz
            let sources = self.analyze(with: options)
            self.report(for: sources, with: options)
        }
        
        let projectURL = URL(fileURLWithPath: project)
        let workspaceURL = URL(fileURLWithPath: workspace ?? "")

        if projectManager.isProject(for: projectURL) {
            projectManager.grepProjectSetting(for: projectURL, completeHandler: handler)
        }

        else if projectManager.isWorkspace(for: workspaceURL) {
            projectManager.grepWorkspaceSchemeSetting(for: workspaceURL, scheme: scheme ?? "", completeHandler: handler)
        }
    }
    
    private func analyze(with options : CommandLineOptions) -> [SymbolOccurrence] {
        do {
            let configuration = try createConfiguration(options: options, outputFile: "swan.report.md")
            let analyzer = try Analyzer(configuration: configuration)
            let symbols = try analyzer.analyzeSymbols()
            return symbols
        } catch {
            log(error.localizedDescription, level: .error)
        }
        return []
    }

    private func report(for sources: [SymbolOccurrence], with options: CommandLineOptions) {
    }
}

Command.main()
