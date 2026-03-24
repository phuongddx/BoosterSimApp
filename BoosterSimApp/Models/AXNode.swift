// AXNode.swift — Immutable accessibility tree node model
import Foundation
import CoreGraphics

struct AXNode: Identifiable, Sendable {
    let id: UUID
    let role: String       // kAXRoleAttribute
    let label: String      // kAXTitleAttribute ?? kAXDescriptionAttribute ?? ""
    let value: String      // kAXValueAttribute as string, or ""
    let frame: CGRect      // kAXFrameAttribute in AppKit screen coordinates
    let hasChildren: Bool  // checked without fetching children
    var children: [AXNode]? = nil  // nil = not yet loaded; [] = leaf
}
