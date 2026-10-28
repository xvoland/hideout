//
//  HyperlinkTextField.swift
//  Hidden Bar
//
//  Created by phucld on 12/19/19.
//  Changed by Vitalii Tereshchuk / xVoLAnD, 2026
//  Copyright © 2019 Dwarves Foundation. All rights reserved.
//

import Foundation
import Cocoa

@IBDesignable
class HyperlinkTextField: NSTextField {
    
    @IBInspectable var href: String = ""
    
    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(self.bounds, cursor: NSCursor.pointingHand)
    }
    
    override func mouseDown(with theEvent: NSEvent) {
        if let localHref = URL(string: href) {
            NSWorkspace.shared.open(localHref)
        }
    }
}

