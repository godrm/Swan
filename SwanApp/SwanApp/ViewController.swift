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
    @IBOutlet weak var statusLabel: NSTextField!
    private var projectManager : ProjectManager!
    private var analyzer : Analyzer!
    static let PREVIEW = "Preview.app"
    static let OPEN = "file:///usr/bin/open"

    override func viewDidLoad() {
        super.viewDidLoad()
                
        let handler : (URL?, String, String, String?) -> Void = { (targetURL, project, project_filepath, workspace_filepath) in
            guard let target = targetURL, project.count > 0 else {
                log("project not found in target = \(targetURL?.absoluteString)", level: .error)
                return
            }
            self.updateStatus(ment: "Prepare options for analysis")
            var options = CommandLineOptions()
            options.buildPath = target.path
            options.path = project
            options.projectFilePath = project_filepath
            options.workspaceFilePath = workspace_filepath ?? ""
            options.mode = .graphviz
            self.updateStatus(ment: "Do analyzing in project files")
            let sources = self.analyze(with: options)
            self.updateStatus(ment: "Make a report for analysis result")
            self.report(for: sources, with: options)
            self.updateStatus(ment: "The Swan report is done.")
        }
        
        NotificationCenter.default.addObserver(forName: ProjectDragView.NotificationName.didDropURL, object: nil, queue: nil) { (notification) in
            guard let url = notification.userInfo?["url"] as? URL else {
                log("drop url not exist.", level: .error)
                return
            }
            self.projectManager = ProjectManager()

            if self.projectManager.isProject(for: url) {
                self.updateStatus(ment: "Looking up setting for project")
                self.projectManager.grepProjectSetting(for: url, completeHandler: handler)
            }
            else if self.projectManager.isWorkspace(for: url) {
                self.projectManager.grepWorkspaceScheme(for: url) { (schemes) in
                    self.updateStatus(ment: "Selecting scheme for workspace")
                    DispatchQueue.main.async {
                        if schemes.count == 0 {                            
                            self.updateStatus(ment: "workspace's scheme not founded.")
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
                              let scheme = selectButton.selectedItem?.title else {
                            log("workspace's scheme not selected", level: .error)
                            return
                        }
                        ProjectManager().grepWorkspaceSchemeSetting(for: url, scheme: scheme, completeHandler: handler)
                    }
                }
            }
        }
        verifyEnvironment()
    }
    
    private func updateStatus(ment: String) {
        DispatchQueue.main.async {
            self.statusLabel.stringValue = ment
        }
        log("update status - \(ment)", level: .debug)
    }
    
    private func verifyEnvironment() {
        if Workspace.isAvailable() {
            updateStatus(ment: "Xcode bundle was founded.")
        }
        else {
            updateStatus(ment: "Xcode or IndexStore Library Not founded.")
            return
        }
        if isSupportGraphvizBinary() {
            updateStatus(ment: "dot command installed and confirmed.")
        }
        else {
            updateStatus(ment: "graphviz must be installed by brew for dot command.")
        }
    }
    
    fileprivate func analyze(with options : CommandLineOptions) -> [SymbolOccurrence] {
        do {
            let configuration = try createConfiguration(options: options, outputFile: "swan.func.pdf")
            self.analyzer = try Analyzer(configuration: configuration)
            let symbols = try analyzer.analyzeSymbols()
            return symbols
        } catch {
            updateStatus(ment: error.localizedDescription)
        }
        return []
    }
    
    private func report(for sources: [SymbolOccurrence], with options: CommandLineOptions) {
        do {
            let configuration = try createConfiguration(options: options)
            let outputs = configuration.reporter.report(configuration, occurrences: sources, finder: analyzer)
            if options.mode != .console {
                preview(outputs)
            }
        } catch {
            updateStatus(ment: error.localizedDescription)
        }
    }

    private func preview(_ outputs: [String]) {
        guard outputs.count > 0,
              let output = outputs.first 
        else {
            updateStatus(ment: "Preview not working because of empty output")
            return
        }
        let aTask = Process()
        aTask.executableURL = URL(string: Self.OPEN)
        aTask.arguments = ["-a", Self.PREVIEW, output]
        aTask.launch()
    }
    
    @objc private func selectScheme(_ sender: NSPopUpButton) {
        sender.title = sender.selectedItem?.title ?? ""
    }
}

