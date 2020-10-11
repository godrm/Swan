//
//  ProjectDragView.swift
//  SwanApp
//
//  Created by JK on 2020/10/10.
//

import AppKit

class ProjectDragView: NSImageView {
    override func awakeFromNib() {
        super.awakeFromNib()
        self.registerForDraggedTypes([.fileURL])
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let canReadPasteboardObjects = sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: nil)
        
        if canReadPasteboardObjects {
            highlight()
            return .copy
        }

        return NSDragOperation()
    }
    
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let pasteboardObjects = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil), pasteboardObjects.count > 0 else {
            return false
        }
        
        pasteboardObjects.forEach { (object) in
            if let url = object as? NSURL {
                self.handleFileURLObject(url as URL)
            }
        }
        
        sender.draggingDestinationWindow?.orderFrontRegardless()
        return true
    }
        
    override func draggingEnded(_ sender: NSDraggingInfo) {
        unhighlight()
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        unhighlight()
    }
    
    func handleFileURLObject(_ url: URL) {
        NotificationCenter.default.post(name: Notification.Name.init(rawValue: "DroppedURL"), object: self, userInfo: ["url":url])
    }
    
    func highlight() {
        self.layer?.borderColor = NSColor.controlAccentColor.cgColor
        self.layer?.borderWidth = 2.0
    }
    
    
    func unhighlight() {
        self.layer?.borderColor = NSColor.clear.cgColor
        self.layer?.borderWidth = 0.0
    }

}
