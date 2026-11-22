# Changelog

All notable changes to cl_kit are listed here, newest first. Calendar versions, `YY.M.R`, tagged `vYY.M.R` (see README ▸
Versions and release).

## Unreleased

- **The status record moves into ProfileCore.** `StatusRecord`, `ResolvedAccount` and `StatusCodec` (with the drawable
  clamp) are cl_audit's status record as it writes it, so every app reads one shape. `StatusAges` gives its age formula,
  and `ProfileDisplay.of` turns a record into the one display value.
- **The account answer's line is a fact, not a sentence.** `ResolvedAccount` gains `codeUsageLine` and `splitLine`
  (optional, left out when empty: older records decode) and `usageOnPrefix`; the app builds the sentence when it shows it,
  so no record holds an address as text. `StatusCodec.drawable` turns an older record's stored "Usage: Claude Code on …"
  into the fact, so the address never reaches a display value's note, and `ProfileDisplay.of` takes the app's builder for
  the line (`lineText:`, the record's own `line` by default).
- **A profile's small picture, as data.** `StatusFace.of` gives the numbers, grey, the other-account warning, the full
  limit, the elapsed shares and the window mark from a display value and a `ProfileLook` (a plain value with its own
  defaults), so every picture of a profile follows the same rules. How it looks stays the app's.
- **Checks:** the core suite gains the codec, the ages, the look's defaults and the picture in each state.
- Additive: nothing that was in ProfileCore changes.

## 26.11.3

- **AddressPrivacy joins** (`Privacy/`, from cl_quick's `Shared/AddressPrivacy/` at 190fa1b): an account address on screen
  is one fixed stand-in or the words "hidden address", never the real address blurred or masked, in views, labels and plain
  text, revealed only on purpose; the setting is a value the app passes in. Its own static library, apart from the layers
  (Apple's UI frameworks, no module of ours): `kit_build_privacy` and `kit_privacy_link` in `scripts/modules.sh`, and the
  `addressprivacy` suite with its lint.

## 26.11.2

ClaudeSignIn as cl_quick last had it (cl_quick 0568102), with its checks.

- **A late script is ended.** A sign-in stopped while Terminal was still starting its window ends the script once it shows,
  its login with it, for at least 5 s after the end (also after a restart, at quit, and when the window never opened).
- **Each run has its own files:** `sign-in-<run>.pid`, `.status` and `.declined`, so a late script never writes into the
  next sign-in's; a start ends other runs' scripts by their files and waits for a pending one's login.
- **Checks:** the claudesignin suite gains the late-start, late-restart and late-quit cases (150 checks).

## 26.11.1

The first release: cl_audit's `Core/`, `Run/` and `Auth/` move here with their history, exactly as in cl_audit
26.11.79 (7444e6f), with the shared sign-in it took from cl_quick.

- **ProfileCore** (`Core/`), **Runs** (`Run/`) and **ClaudeAuth** (`Auth/`) as they were in cl_audit, including
  `Run/ProcessTable.swift`, `Auth/StoredSignIn.swift` and **ClaudeSignIn** (`Auth/ClaudeSignIn.swift`), the sign-in in a
  Terminal window shared by both apps.
- **The Keychain is optional.** ClaudeAuth reads a stored sign-in only through `StoredSignInReader`; `Auth/Keychain.swift`
  is the one file that reads the Keychain, and an app can build without it.
- **Build:** `scripts/build.sh` (`--no-keychain`) and `scripts/modules.sh`, the build recipe apps source from their vendored
  copy: static libraries in layers, Swift 5 language mode, macOS 13.
- **Checks:** the core, runs, auth and claudesignin suites from cl_audit, and a new `nokeychain` suite (ClaudeAuth builds
  without `Auth/Keychain.swift` and names no Security API), all through `Checks/run.sh`, on every pull request and push in CI.
