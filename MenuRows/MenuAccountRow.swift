// MenuRows · the model: what one account row of a menu says, apart from how it is drawn. Plain values, built by the app
// from what it already has (the account's address, whether it is the one in use, its ProfileCore display value); this
// module decides nothing about an account, it only turns the display value into a compact usage line.

import Foundation
import ProfileCore

/// One account in a menu: its address (always whole, hidden or shown by AddressPrivacy when drawn), whether it is the
/// account in use (the menu's tick), and a compact usage line or a line of the app's own words under it.
public struct MenuAccountRow: Equatable {
    /// The account's whole address. The row draws it through AddressPrivacy; it is never in a title or a spoken label
    /// while hidden.
    public var address: String
    /// The account in use: the tick in the margin, and "selected" to VoiceOver.
    public var inUse: Bool
    /// The compact usage line under the address, or nil (a standby account isn't read).
    public var usage: MenuUsageLine?
    /// A line of the app's own words under the address when there is no usage line ("Signed out", "Last used yesterday");
    /// nil: none. Never an address: the row doesn't hide what is in it.
    public var note: String?
    /// The app's words right after the address, in the same line (" · standby"), or "".
    public var tag: String
    /// The app's word at the right of the address line while the pointer is on the row ("Switch…"), or nil.
    public var hint: String?
    /// false: dimmed, never lit, does nothing.
    public var enabled: Bool

    public init(address: String, inUse: Bool, usage: MenuUsageLine? = nil, note: String? = nil, tag: String = "",
                hint: String? = nil, enabled: Bool = true) {
        self.address = address; self.inUse = inUse; self.usage = usage; self.note = note; self.tag = tag; self.hint = hint
        self.enabled = enabled
    }
}

/// The words a usage line is made of: the app's (or the kit's plain ones, `standard`).
public struct MenuRowWords: Equatable {
    /// The 5-hour limit's short name ("5h").
    public var fiveHour: String
    /// The week's short name ("Week").
    public var week: String
    /// What a full limit says after its name ("full"); the countdown to its reset follows (TimeWords.countdown).
    public var full: String

    public init(fiveHour: String, week: String, full: String) { self.fiveHour = fiveHour; self.week = week; self.full = full }

    /// Plain short words: "5h 34% · Week 12%", "Week full · 2d 19h".
    public static let standard = MenuRowWords(fiveHour: "5h", week: "Week", full: "full")
}

/// A compact usage line: each limit that shows with its percent and colour level, or the full limit and how long until
/// it's back, greyed for old numbers. Everything in it comes from ProfileCore's display value; it holds no rule of its own.
public struct MenuUsageLine: Equatable {
    /// One limit: its short name, its percent as a person reads it (rounded), its colour level (ProfileDisplay.level).
    public struct Part: Equatable {
        public var label: String
        public var percent: Int
        public var level: Level
        public init(label: String, percent: Int, level: Level) { self.label = label; self.percent = percent; self.level = level }
    }

    /// The limits that show, 5-hour first.
    public var parts: [Part]
    /// While a limit is full: its words instead of the parts ("Week full · 2d 19h"), drawn in the full colour.
    public var full: String?
    /// Old numbers: drawn grey (ProfileDisplay.grey).
    public var grey: Bool

    public init(parts: [Part], full: String? = nil, grey: Bool = false) { self.parts = parts; self.full = full; self.grey = grey }

    /// The line for a display value at `now`, or nil when it shows no numbers (`display.usage` is nil: the app says why in
    /// its own words, MenuAccountRow.note). The 5-hour part shows only where the week-only rule lets it
    /// (`display.hasFiveHour`); a limit with no number is left out; a full limit holding the profile back now
    /// (`display.full(now:)`) replaces the parts.
    public static func of(_ display: ProfileDisplay, words: MenuRowWords = .standard, now: Date = Date()) -> MenuUsageLine? {
        guard let u = display.usage else { return nil }
        if let f = display.full(now: now) {
            let name = f.kind == .fiveHour ? words.fiveHour : words.week
            let left = f.resets.map { " · " + TimeWords.countdown($0, now: now) } ?? ""
            return MenuUsageLine(parts: [], full: "\(name) \(words.full)\(left)", grey: display.grey)
        }
        var parts: [Part] = []
        if display.hasFiveHour, let p = u.fiveHour {
            parts.append(Part(label: words.fiveHour, percent: Int(p.rounded()), level: display.level(p)))
        }
        if let p = u.weekly { parts.append(Part(label: words.week, percent: Int(p.rounded()), level: display.level(p))) }
        return parts.isEmpty ? nil : MenuUsageLine(parts: parts, grey: display.grey)
    }

    /// The line as plain words ("5h 34% · Week 12%", "Week full · 2d 19h"): the row's spoken words and its title.
    public var words: String {
        full ?? parts.map { "\($0.label) \($0.percent)%" }.joined(separator: " · ")
    }
}
