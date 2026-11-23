# MenuRows

One account row for a menu bar menu, shared by cl_quick and cl_audit: the account's address (through AddressPrivacy), a
compact usage line from ProfileCore's display value, and the tick for the account in use. It imports ProfileCore and
AddressPrivacy only (and Apple's Foundation and AppKit), holds no rule of its own, names no app and never logs; nothing of
ours imports it. Swift 5 language mode, macOS 13.

Built by `scripts/modules.sh` (`kit_build_menurows OUT`, after `kit_build` and `kit_build_privacy` into the same OUT; link
with `kit_menurows_link OUT` before the other two). `Checks/run.sh menurows` is its suite (lint first).

## The row

```
  ✓ abcdefghijkl@mnopqrst.com · standby          Switch…     the address line: the stand-in blurred at rest
    5h 34% · Week 12%                                        the usage line (or the app's note), smaller
```

- **The address.** Always whole. While addresses are hidden (the app's setting, `AddressPrivacy.shared.blur`) it is
  AddressPrivacy's one fixed stand-in, blurred, the same for every account, and sharp only while the menu lights the row
  **and** the pointer is on it: a keyboard highlight or type-ahead lights the row but never reveals the address. Its room is
  the stand-in's whatever the address, so nothing moves on a reveal and an address's length is never in the tag's position.
- **Words.** The item's title (type-ahead) and VoiceOver's label are the sentence form: `hidden address` in the address's
  place, then the tag and the second line. The account in use is the item's `.on` state, a tick in the margin (the address
  keeps the other rows' column), and "selected" to VoiceOver.
- **The usage line.** `MenuUsageLine.of(display, words:, now:)` from a `ProfileDisplay`: each limit that shows with its
  rounded percent in its colour level (`display.level`), the 5-hour part only where the week-only rule lets it
  (`display.hasFiveHour`), a full limit holding the profile back now (`display.full(now:)`) with the countdown to its reset
  instead of the parts, grey for old numbers (`display.grey`); nil when the display shows no numbers. The words are
  `MenuRowWords` (`standard`: "5h", "Week", "full"), or the app's own.
- **Compact.** One line, two with the usage line or a note; a native item's highlight; no stripe on any edge.
- **Acting.** A click closes the menu, then runs `pick` (outside the menu's tracking loop); Return and VoiceOver's press do
  the same. A dimmed row (`enabled: false`) is never lit and does nothing.

```swift
import MenuRows

let line = MenuUsageLine.of(display, now: now)                              // ProfileDisplay, from ProfileCore
let row = MenuAccountRow(address: "wu@example.com", inUse: true, usage: line)
menu.addItem(MenuAccountRowView.item(row) { /* the in-use row: nothing, or the app's action */ })

let standby = MenuAccountRow(address: "zedekiah@example.com", inUse: false, note: "Last used yesterday",
                             tag: " · standby", hint: "Switch…")
menu.addItem(MenuAccountRowView.item(standby) { openSwitch(...) })
```

The app keeps what is its own: which accounts are listed and in what order, the tag, the hint and the note words, what a
pick does, and its setting (`AddressPrivacy.shared.apply(blur:)`). For tests and pictures every row takes `blur:` (an
override of the setting) and `highlighted` (drawn lit with the pointer on it), and `pointer(_:)` stands in for the mouse.

Files: `MenuAccountRow.swift` (the model: `MenuAccountRow`, `MenuUsageLine`, `MenuRowWords`; Foundation and ProfileCore),
`MenuAccountRowView.swift` (the view and its menu item; AppKit, AddressPrivacy).
