// MenuRows · the row: one account in a menu bar menu, drawn by hand so a hidden address can be the blurred stand-in
// (AddressPrivacy) and still be told apart from its neighbours by its place, never by its text. Merged from cl_audit's
// AddressMenuRow (the tick in the margin, the tag after the address, VoiceOver's "selected") and cl_quick's
// QCStandbyMenuRow (the reveal only with the pointer on the row, the quiet hint at the right while lit, the press that
// closes the menu first). It adds the compact usage line under the address (MenuUsageLine, from ProfileCore's display).
//
//   ✓ abcdefghijkl@mnopqrst.com · standby          Switch…     address line: the stand-in blurred at rest
//     5h 34% · Week 12%                                        usage line (or the app's note), smaller
//
// - Hidden (the setting on): the address is AddressPrivacy's one fixed stand-in, blurred, the same for every account, and
//   sharp only while the menu lights the row AND the pointer is on it. A keyboard highlight or type-ahead lights the row
//   but never reveals the address. Its room is the stand-in's width whatever the address, so nothing moves on a reveal
//   and an address's length is never in the position of the tag after it.
// - Its title (the menu's type-ahead) and its VoiceOver label hold the sentence form: "hidden address" in the address's
//   place, the same for every account.
// - Compact: one line (two with the usage line), a native item's highlight, no stripe on any edge.

import AddressPrivacy
import AppKit
import ProfileCore

public final class MenuAccountRowView: NSView {
    /// What the row says.
    public let row: MenuAccountRow
    /// Runs on a click (after the menu has closed), on Return, and on VoiceOver's press. Never while dimmed.
    public let pick: () -> Void
    /// For pictures: drawn as if the menu lit the row with the pointer on it (the address sharp).
    public var highlighted = false { didSet { needsDisplay = true } }
    /// A test override of the setting (nil: the app's, AddressPrivacy.shared); it reaches what is drawn, written and spoken.
    public var blur: Bool? { didSet { needsDisplay = true } }
    /// The pointer is on the row (a keyboard highlight lights the row too, but only the pointer reveals the address).
    public private(set) var pointerOn = false

    // MARK: metrics

    public static let font = NSFont.menuFont(ofSize: 0)
    /// The usage line's (and the note's) font, a step smaller.
    public static let smallFont = NSFont.menuFont(ofSize: 11)
    /// The tick's font: a little smaller than the row's, so it sits in the margin with room before the address.
    public static let tickFont = NSFont.menuFont(ofSize: 11)
    public static let padX: CGFloat = 14
    /// Room between the tick and the address.
    public static let tickGap: CGFloat = 3
    /// Least room between the tag and the hint.
    public static let hintGap: CGFloat = 18
    /// The highlight: a native item's, inset from the menu's edges, rounded.
    public static let highlightInset: CGFloat = 5, highlightH: CGFloat = 22, highlightRadius: CGFloat = 4
    /// The address line: as tall as the blurred stand-in's picture (the text and the blur's reach above and below), so the
    /// blur is never cut.
    public static let addressLineH: CGFloat = textH(font) + 2 * AddressInk.blurPad
    /// Where the second line (usage or note) starts: right under the address's text (the blur's reach below it is only
    /// a faint edge, so the line may start there).
    public static let secondLineTop: CGFloat = addressLineH - AddressInk.blurPad
    /// The second line's height, with a little room below it.
    public static let secondLineH: CGFloat = textH(smallFont) + 3

    static func textH(_ f: NSFont) -> CGFloat { ceil(("Ag" as NSString).size(withAttributes: [.font: f]).height) }
    static func w(_ s: String, _ f: NSFont) -> CGFloat { ceil((s as NSString).size(withAttributes: [.font: f]).width) }

    private let ink = AddressInk(font: MenuAccountRowView.font)

    // MARK: making one

    public init(row: MenuAccountRow, pick: @escaping () -> Void) {
        self.row = row; self.pick = pick
        super.init(frame: .zero)
        frame = NSRect(x: 0, y: 0, width: naturalWidth, height: height)
        autoresizingMask = [.width]
        setAccessibilityElement(true)
        setAccessibilityRole(.menuItem)
        setAccessibilityEnabled(row.enabled)
        setAccessibilitySelected(row.inUse)
    }
    required init?(coder: NSCoder) { fatalError("not from a nib") }

    /// The menu item for a row: the row as its view, the account in use ticked (the item's state says it too), a title and
    /// an action of its own for the menu's type-ahead and Return. A dimmed row is disabled and has no action.
    /// The caller may put its own `representedObject` or `tag` on it; the row keeps its handler in `target`.
    public static func item(_ row: MenuAccountRow, blur: Bool? = nil, pick: @escaping () -> Void) -> NSMenuItem {
        let view = MenuAccountRowView(row: row, pick: pick)
        view.blur = blur
        view.frame.size = NSSize(width: view.naturalWidth, height: view.height)
        let item = NSMenuItem(title: view.title, action: row.enabled ? #selector(MenuAccountRowView.fire) : nil, keyEquivalent: "")
        item.target = view                       // (the item keeps its view, so its target lives as long as it does)
        item.isEnabled = row.enabled
        item.state = row.inUse ? .on : .off
        item.view = view
        return item
    }

    // MARK: what it says

    /// Whether the address is hidden now: the override, or the app's setting.
    public var blurred: Bool { blur ?? AddressPrivacy.shared.blur }
    /// The item's title: the address in its sentence form ("hidden address" while hidden) and the tag.
    public var title: String { AddressText.sentence(address: row.address, blur: blurred) + row.tag }
    /// The second line's words: the usage line's, else the app's note, else nil.
    public var secondLine: String? { row.usage?.words ?? row.note }
    /// What VoiceOver reads, worked out on each call (so a change of the setting reaches it): the title, then the second
    /// line. Nothing of a hidden address, whatever the pointer does.
    public override func accessibilityLabel() -> String? { [title, secondLine].compactMap { $0 }.joined(separator: ", ") }
    /// The account in use says so, as a native ticked item does.
    public override func accessibilityValue() -> Any? { row.inUse ? "selected" : nil }

    // MARK: size

    /// The room of the address: the stand-in's while hidden, whatever the address (its own width while shown).
    public var room: CGFloat { ink.room(for: row.address, blur: blurred) }
    /// One line, or two with a usage line or a note.
    public var height: CGFloat { secondLine == nil ? Self.addressLineH : Self.secondLineTop + Self.secondLineH }
    /// The least width that shows it all: the address line (the address's room, the tag, the hint) or the second line.
    public var naturalWidth: CGFloat {
        let line1 = Self.padX + room + Self.w(row.tag, Self.font) + (row.hint.map { Self.hintGap + Self.w($0, Self.font) } ?? 0) + Self.padX
        let line2 = secondLine.map { Self.padX + Self.w($0, Self.smallFont) + Self.padX } ?? 0
        return max(line1, line2)
    }
    public override var intrinsicContentSize: NSSize { NSSize(width: naturalWidth, height: height) }
    public override var isFlipped: Bool { true }

    // MARK: lit and sharp

    /// Lit by the menu (the pointer or the arrow keys are on it, or drawn so for a picture); a dimmed row never is.
    public var lit: Bool { row.enabled && (highlighted || (menuLit ?? (enclosingMenuItem?.isHighlighted == true))) }
    /// A check's stand-in for the menu's highlight (nil: the item's own): lit as by the arrow keys, the pointer elsewhere.
    var menuLit: Bool? { didSet { needsDisplay = true } }
    /// The address is drawn readable: lit with the pointer on it (or lit for a picture), or addresses aren't hidden.
    public var sharp: Bool { (lit && (pointerOn || highlighted)) || !blurred }
    /// The address text drawn now: its own while sharp, else the stand-in (never any part of the address).
    public var drawnAddress: String { AddressText.drawn(address: row.address, revealed: sharp, blur: true) }

    /// The pointer came onto the row or left it (the tracking area's calls; a check calls it to stand in for the mouse).
    public func pointer(_ on: Bool) { pointerOn = on; needsDisplay = true }

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))
    }
    public override func mouseEntered(with e: NSEvent) { pointer(true) }
    public override func mouseExited(with e: NSEvent) { pointer(false) }
    public override func mouseUp(with e: NSEvent) {
        if bounds.contains(convert(e.locationInWindow, from: nil)) { press() }
    }

    // MARK: acting

    /// A click on the row: closes the menu, then runs `pick` once it has closed (not inside the menu's tracking loop, where a
    /// window or a question would not take the keyboard). Nothing while dimmed.
    public func press() {
        guard row.enabled else { return }
        enclosingMenuItem?.menu?.cancelTracking()
        let run = pick
        DispatchQueue.main.async { run() }
    }
    /// Return on the lit row (the item's action).
    @objc public func fire() { if row.enabled { pick() } }
    /// VoiceOver's press does what a click does.
    public override func accessibilityPerformPress() -> Bool {
        guard row.enabled else { return false }
        press()
        return true
    }

    // MARK: drawing

    /// The colour of a usage level (ProfileCore.Level, the one colour rule): the menu's own greens and reds.
    public static func color(_ level: Level) -> NSColor {
        switch level {
        case .none: return .secondaryLabelColor
        case .green: return .systemGreen
        case .amber: return .systemOrange
        case .red: return .systemRed
        case .crimson: return NSColor(srgbRed: 0.86, green: 0.15, blue: 0.24, alpha: 1)
        }
    }

    public override func draw(_ dirty: NSRect) {
        let on = lit
        if on {
            NSColor.selectedContentBackgroundColor.setFill()
            let h = secondLine == nil ? Self.highlightH : bounds.height - 2
            NSBezierPath(roundedRect: NSRect(x: Self.highlightInset, y: bounds.midY - h / 2, width: bounds.width - 2 * Self.highlightInset,
                                             height: h), xRadius: Self.highlightRadius, yRadius: Self.highlightRadius).fill()
        }
        let text: NSColor = on ? .selectedMenuItemTextColor : row.enabled ? .labelColor : .disabledControlTextColor
        let quiet: NSColor = on ? NSColor.selectedMenuItemTextColor.withAlphaComponent(0.8) : row.enabled ? .secondaryLabelColor : .disabledControlTextColor
        let mid = Self.addressLineH / 2, h = ink.lineHeight
        func put(_ s: String, _ f: NSFont, _ c: NSColor, x: CGFloat, y: CGFloat) {
            (s as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: [.font: f, .foregroundColor: c])
        }
        // the tick, in the margin: the address keeps the other rows' column
        if row.inUse {
            let tw = Self.w("✓", Self.tickFont)
            put("✓", Self.tickFont, text, x: max(1, Self.padX - tw - Self.tickGap), y: mid - h / 2)
        }
        // the address (sharp, or the stand-in blurred), the tag right after its room, the hint at the right while lit
        ink.draw(address: row.address, readable: sharp, color: text, x: Self.padX, midY: mid, blur: blurred)
        if !row.tag.isEmpty { put(row.tag, Self.font, quiet, x: Self.padX + room, y: mid - h / 2) }
        if on, let hint = row.hint {
            put(hint, Self.font, quiet, x: bounds.maxX - Self.padX - Self.w(hint, Self.font), y: mid - h / 2)
        }
        // the second line: the usage line's parts in their levels' colours (grey when old), its full limit, or the note
        guard secondLine != nil else { return }
        let y = Self.secondLineTop, f = Self.smallFont
        if let u = row.usage {
            if let full = u.full {
                put(full, f, on ? text : u.grey ? .tertiaryLabelColor : Self.color(.crimson), x: Self.padX, y: y)
                return
            }
            var x = Self.padX
            for (i, p) in u.parts.enumerated() {
                if i > 0 { put(" · ", f, quiet, x: x, y: y); x += Self.w(" · ", f) }
                let label = p.label + " "
                put(label, f, quiet, x: x, y: y); x += Self.w(label, f)
                let pct = "\(p.percent)%"
                put(pct, f, on ? text : u.grey ? .tertiaryLabelColor : Self.color(p.level), x: x, y: y); x += Self.w(pct, f)
            }
        } else if let note = row.note {
            put(note, f, quiet, x: Self.padX, y: y)
        }
    }

    // (the blurred stand-in is made once per colour by `ink`, and made again if the appearance changes)
    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        ink.reset()
        needsDisplay = true
    }
}
