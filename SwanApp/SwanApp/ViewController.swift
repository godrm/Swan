//
//  ViewController.swift
//  SwanApp
//
//  Created by JK on 2020/10/09.
//
import Cocoa
import SwanKit
import IndexStoreDB

class ViewController: NSViewController {
    private var projectManager : ProjectManager!
    static let PREVIEW = "Preview.app"
    static let OPEN = "file:///usr/bin/open"

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let handler : (URL?, String, String) -> Void = { (targetURL, project, project_filepath) in
            guard let target = targetURL, project.count > 0 else { return }
            var options = CommandLineOptions()
            options.indexStorePath = target.path
            options.path = project
            options.project_filepath = project_filepath
            options.mode = .graphviz
            let sources = self.analyze(with: options)
            self.report(for: sources, with: options)
        }
        
        NotificationCenter.default.addObserver(forName: ProjectDragView.NotificationName.didDropURL, object: nil, queue: nil) { (notification) in
            guard let url = notification.userInfo?["url"] as? URL else { return }
            self.projectManager = ProjectManager()

            if self.projectManager.isProject(for: url) {
                self.projectManager.grepProjectSetting(for: url, completeHandler: handler)
            }
            else if self.projectManager.isWorkspace(for: url) {
                self.projectManager.grepWorkspaceScheme(for: url) { (schemes) in
                    DispatchQueue.main.async {
                        if schemes.count == 0 {                            
                            return
                        }
                        let selectButton = NSPopUpButton(title: "shemes", target: self, action: #selector(ViewController.selectScheme))
                        selectButton.title = schemes.first!
                        selectButton.frame = CGRect(x: 0, y: 0, width: 200, height: 50)
                        selectButton.addItems(withTitles: schemes)
                        
                        let alert = NSAlert()
                        alert.accessoryView = selectButton
                        alert.messageText = "Select scheme to analyze"
                        alert.addButton(withTitle: "Analyze")
                        alert.addButton(withTitle: "Cancel")
                        let selected = alert.runModal()
                        
                        guard selected == .alertFirstButtonReturn,
                              let scheme = selectButton.selectedItem?.title else { return }
                        ProjectManager().grepWorkspaceSchemeSetting(for: url, scheme: scheme, completeHandler: handler)
                    }
                }
            }
        }
    }
    
    fileprivate func analyze(with options : CommandLineOptions) -> [SymbolOccurrence] {
        do {
            let configuration = try createConfiguration(options: options, outputFile: "swan.func.pdf")
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
            let configuration = try createConfiguration(options: options)
            let outputs = configuration.reporter.report(configuration, occurrences: sources)
            if options.mode != .console {
                preview(outputs)
            }
            
//            var options = options
//            options.mode = .graphvizFile
//            let fileConfiguration = try createConfiguration(options: options, outputFile: "swan.func.pdf")
//            let fileOutputs = fileConfiguration.reporter.report(fileConfiguration, occurrences: sources)
//            if options.mode != .console {
//                preview(fileOutputs)
//            }
        } catch {
            log(error.localizedDescription, level: .error)
        }
    }

    private func preview(_ outputs: [String]) {
        guard outputs.count > 0,
              let output = outputs.first else { return }
        let aTask = Process()
        aTask.executableURL = URL(string: Self.OPEN)
        aTask.arguments = ["-a", Self.PREVIEW, output]
        aTask.launch()
    }
    
    @objc private func selectScheme(_ sender: NSPopUpButton) {
        sender.title = sender.selectedItem?.title ?? ""
    }
}

