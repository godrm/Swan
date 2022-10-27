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
            var analyzer : Analyzer
            var options = CommandLineOptions()
            options.buildPath = target.path
            options.path = project
            options.projectFilePath = project_filepath
            options.workspaceFilePath = workspace_filepath ?? ""
            options.mode = .init(rawValue: self.format ?? "console") ?? .console
            options.includeSPM = true
            do {
                let configuration = try createConfiguration(options: options, outputFile: ((options.mode == .graphviz) ? "swan.report.pdf" : "swan.report.md"))
                analyzer = try Analyzer(configuration: configuration)
                self.report(with: configuration, analyzer: analyzer)
            } catch {
                log(error.localizedDescription, level: .error)
                lock.leave()
                return
            }
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
    
    private func report(with config: Configuration, analyzer: Analyzer) {
        do {
            let sources = try analyzer.analyzeSymbols()
            let _ = config.reporter.report(config, occurrences: sources, finder: analyzer)
        } catch {
            log(error.localizedDescription, level: .error)
        }
    }
}

Command.main()
