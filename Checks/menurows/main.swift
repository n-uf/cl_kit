// The MenuRows module's own checks (Checks/run.sh menurows): the module and the two it imports (ProfileCore, AddressPrivacy),
// no app code, no window shown, no mouse, nothing written outside Checks/.work. Sample addresses only (example.com).
//
// What they prove: the usage line says what ProfileCore's display value says and nothing else (the week-only rule, the
// levels, a full limit's countdown, grey for old numbers, none without numbers); with addresses hidden, nothing of an
// address is in a row's title, its spoken words or its drawn text, two addresses draw the very same pixels and take the
// same room, a keyboard highlight never reveals the address and the pointer on the lit row does; the tick and "selected"
// for the account in use; the item's title, action, state and a dimmed row's silence; one line or two.

@testable import MenuRows
import AddressPrivacy
import AppKit
import ProfileCore

var failed = 0, passed = 0
func check(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
    if ok { passed += 1 } else { failed += 1; print("FAIL \(name) \(detail())") }
}

let short = "wu@example.com", long = "zedekiah.with.a.long.name@sample-domain.example.net", other = "ines@example.org"
/// The pieces of an address a match could use: its local part, its domain, each word of three letters or more.
func parts(_ a: String) -> [String] {
    let at = a.firstIndex(of: "@")!
    var out = [String(a[..<at]), String(a[a.index(after: at)...])]
    out += a.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    return out.filter { $0.count >= 3 && $0 != "com" }
}
func leaks(_ s: String, of a: String) -> Bool { parts(a).contains { s.contains($0) } || s.contains(String(a.prefix(1)) + "@") }

let now = Date(timeIntervalSince1970: 1_800_000_000)
func display(five: Double? = nil, week: Double? = nil, weekResets: Date? = nil, tier: ProfileDisplay.Tier = .fresh,
             full: FullLimit? = nil, hasFiveHour: Bool = true, none: Bool = false) -> ProfileDisplay {
    let u = none ? nil : Usage(fiveHour: five, weekly: week, weeklyResets: weekResets, fetchedAt: now, source: "sample")
    return ProfileDisplay(usage: u, none: none ? .notRead : nil, readAt: now, tier: tier, full: full, lamp: true, key: nil,
                          line: nil, clash: nil, split: nil, sign: .ok, otherAccount: false, hasFiveHour: hasFiveHour)
}

// ── the usage line: what the display value says, and nothing of its own ────────────────────────────────────
let both = MenuUsageLine.of(display(five: 34.4, week: 12), now: now)
check("usage: both limits, rounded, 5-hour first, the standard words", both?.words == "5h 34% · Week 12%", "\(both?.words ?? "nil")")
check("usage: each part's level is the display's (ProfileCore.Level)",
      both?.parts.map(\.level) == [display(five: 34.4).level(34.4), display().level(12)])
let weekOnly = MenuUsageLine.of(display(five: 40, week: 20, hasFiveHour: false), now: now)
check("usage: the week-only rule (display.hasFiveHour false): no 5-hour part even with a number", weekOnly?.words == "Week 20%",
      "\(weekOnly?.words ?? "nil")")
check("usage: a limit with no number is left out", MenuUsageLine.of(display(five: 7), now: now)?.words == "5h 7%")
check("usage: no numbers (display.usage nil): no line, the app says why in its note",
      MenuUsageLine.of(display(none: true), now: now) == nil && MenuUsageLine.of(display(), now: now) == nil)
let resets = now.addingTimeInterval(2 * 86400 + 19 * 3600)
let full = MenuUsageLine.of(display(five: 10, week: 100, weekResets: resets, full: FullLimit(kind: .week, resets: resets)), now: now)
check("usage: a full limit replaces the parts: its name, the words' full, the countdown (TimeWords)",
      full?.full == "Week full · \(TimeWords.countdown(resets, now: now))" && full?.parts.isEmpty == true && full?.words == full?.full,
      "\(full?.full ?? "nil")")
let passedFull = MenuUsageLine.of(display(five: 10, week: 100, weekResets: now.addingTimeInterval(-60),
                                          full: FullLimit(kind: .week, resets: now.addingTimeInterval(-60))), now: now)
check("usage: a full limit whose reset has passed holds nothing back (display.full(now:)): the parts again",
      passedFull?.full == nil && passedFull?.words == "5h 10% · Week 100%", "\(passedFull?.words ?? "nil")")
let old = MenuUsageLine.of(display(five: 60, week: 30, tier: .stale), now: now)
check("usage: old numbers are grey, their levels none (the display's rule)", old?.grey == true && old?.parts.allSatisfy { $0.level == .none } == true)
let own = MenuRowWords(fiveHour: "5-hour", week: "wk", full: "is full")
check("usage: the app's own words", MenuUsageLine.of(display(five: 1, week: 2), words: own, now: now)?.words == "5-hour 1% · wk 2%")

// ── the row, addresses hidden ──────────────────────────────────────────────────────────────────────────────
func view(_ a: String, inUse: Bool = false, usage: MenuUsageLine? = nil, note: String? = nil, tag: String = "", hint: String? = nil,
          enabled: Bool = true, blur: Bool = true) -> MenuAccountRowView {
    let v = MenuAccountRowView(row: MenuAccountRow(address: a, inUse: inUse, usage: usage, note: note, tag: tag, hint: hint,
                                                   enabled: enabled), pick: {})
    v.blur = blur
    v.frame.size = NSSize(width: max(v.naturalWidth, 320), height: v.height)
    return v
}
let hShort = view(short, inUse: true, usage: both, tag: " · in use"), hLong = view(long, usage: both, tag: " · in use")
check("hidden: the title is the sentence form, the same for every account",
      hShort.title == "hidden address · in use" && hLong.title == hShort.title && !leaks(hShort.title, of: short) && !leaks(hLong.title, of: long))
check("hidden: VoiceOver's label holds nothing of the address, the usage line after it",
      hShort.accessibilityLabel() == "hidden address · in use, 5h 34% · Week 12%"
      && !leaks(hShort.accessibilityLabel() ?? short, of: short) && !leaks(hLong.accessibilityLabel() ?? long, of: long))
check("hidden: what is drawn is the stand-in, never the address", hShort.drawnAddress == AddressText.standIn && hLong.drawnAddress == AddressText.standIn)
check("hidden: a short and a long address take the same room and the same width (no length in it)",
      hShort.room == hLong.room && view(short).naturalWidth == view(long).naturalWidth)

// the reveal: only the pointer on the lit row
let r = view(short, hint: "Switch…")
check("reveal: at rest, not lit, not sharp", !r.lit && !r.sharp)
r.menuLit = true
check("reveal: lit by the keyboard (the arrow keys), the pointer elsewhere: still the stand-in", r.lit && !r.sharp && r.drawnAddress == AddressText.standIn)
r.pointer(true)
check("reveal: lit with the pointer on it: the address, sharp", r.sharp && r.drawnAddress == short)
r.menuLit = false
check("reveal: the pointer on it but not lit (the menu moved on): the stand-in again", !r.sharp && r.drawnAddress == AddressText.standIn)
r.pointer(false)
check("reveal: the title and spoken words stay hidden whatever the pointer does", r.title == "hidden address" && r.accessibilityLabel() == "hidden address")
let dim = view(short, enabled: false); dim.menuLit = true; dim.pointer(true)
check("reveal: a dimmed row is never lit and never reveals", !dim.lit && !dim.sharp)
let picture = view(short); picture.highlighted = true
check("reveal: drawn lit for a picture, sharp", picture.lit && picture.sharp)

// the pixels: two addresses, hidden, draw the very same row, and it isn't blank
func pixels(_ v: NSView) -> Data? {
    guard let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { return nil }
    v.cacheDisplay(in: v.bounds, to: rep)
    return rep.representation(using: .png, properties: [:])
}
func inked(_ v: NSView) -> Bool {
    guard let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { return false }
    v.cacheDisplay(in: v.bounds, to: rep)
    for x in stride(from: 0, to: rep.pixelsWide, by: 2) { for y in stride(from: 0, to: rep.pixelsHigh, by: 2) {
        if let c = rep.colorAt(x: x, y: y), c.alphaComponent > 0.05 { return true } } }
    return false
}
let p1 = view(short, inUse: true, usage: both), p2 = view(long, inUse: true, usage: both)
p2.frame.size = p1.frame.size
check("pixels: hidden, a short and a long address draw the very same row", pixels(p1) != nil && pixels(p1) == pixels(p2))
check("pixels: the row isn't blank", inked(p1))
let s1 = view(short, blur: false), s2 = view(other, blur: false)
s2.frame.size = s1.frame.size
check("pixels: shown, two addresses draw differently (the address is there)", pixels(s1) != pixels(s2))

// ── shown ──────────────────────────────────────────────────────────────────────────────────────────────────
let shown = view(short, tag: " · standby", blur: false)
check("shown: the title and the drawn text are the address", shown.title == "\(short) · standby" && shown.drawnAddress == short && shown.sharp)
check("shown: the room is the address's own (nothing to hide, nothing cut)", view(long, blur: false).room > view(short, blur: false).room)

// ── the tick, the item, acting ─────────────────────────────────────────────────────────────────────────────
var picks = 0
let inUseItem = MenuAccountRowView.item(MenuAccountRow(address: short, inUse: true, usage: both), blur: true) { picks += 1 }
let standbyItem = MenuAccountRowView.item(MenuAccountRow(address: long, inUse: false, note: "Last used yesterday", hint: "Switch…"), blur: true) { picks += 1 }
let dimItem = MenuAccountRowView.item(MenuAccountRow(address: other, inUse: false, enabled: false), blur: true) { picks += 1 }
check("tick: the account in use is the item's .on state and 'selected' to VoiceOver; a standby account neither",
      inUseItem.state == .on && inUseItem.view?.accessibilityValue() as? String == "selected"
      && standbyItem.state == .off && standbyItem.view?.accessibilityValue() == nil)
check("item: its title is the row's sentence form, its view the row, its target the row with Return's action",
      inUseItem.title == "hidden address" && inUseItem.view is MenuAccountRowView && inUseItem.target === inUseItem.view
      && inUseItem.action == #selector(MenuAccountRowView.fire))
(standbyItem.target as? MenuAccountRowView)?.fire()
check("item: Return (the item's action) runs pick", picks == 1)
check("item: a dimmed row is disabled, has no action and does nothing",
      !dimItem.isEnabled && dimItem.action == nil && (dimItem.view as? MenuAccountRowView)?.accessibilityPerformPress() == false)
(dimItem.view as? MenuAccountRowView)?.fire()
check("item: a dimmed row's Return does nothing", picks == 1)

// one line or two
let oneLine = view(short), withUsage = view(short, usage: both), withNote = view(short, note: "Signed out")
check("size: one line without a second line; two with the usage line or a note, the same height either way",
      withUsage.height > oneLine.height && withNote.height == withUsage.height && oneLine.height == MenuAccountRowView.addressLineH)
check("size: the second line's words, the note when there are no numbers", withNote.secondLine == "Signed out" && oneLine.secondLine == nil)
check("size: compact (a native item's height for one line, under 40 pt for two)",
      oneLine.height <= 30 && withUsage.height < 40, "\(oneLine.height) \(withUsage.height)")

print("menurows: \(passed) passed, \(failed) failed")
exit(failed == 0 ? 0 : 1)
