// ClaudeAuth · finding accounts on this Mac: each source a plain function, files in, accounts out, all in one shape
// (FoundAccount: one sighting of an account, its named fields only, never a token). Each app picks its sources and does its
// own listing with what comes back (which profile an account goes to, what is forgotten, the words).
//
// The sources:
// - a Claude Code folder's own record (.claude.json) and the backups Claude Code keeps of it (`folderRecordFiles`);
// - the Claude Code folders in a home folder (`claudeFolders`: ~/.claude and ~/.claude-*);
// - every record in a home folder and claude-transplant's switch folder (`homeRecordFiles`: ~/.claude*,
//   ~/.claude-switch/accounts/*/.claude.json), read for the profile on the default folder;
// - APP SESSIONS (an option, cl_audit's): the Claude desktop app's session folders in a data folder (`appSessions`): the
//   account and organisation folder names and their dates; for its agent sessions, the address their records name. It
//   opens session records of the desktop app: an app that never reads sessions (cl_quick, incognito) never calls it;
// - TRANSCRIPTS (an option, cl_audit's): the account ids a Claude Code folder's transcripts name (`transcriptAccounts`): it
//   READS CHATS (the first 64 KB of each transcript). An app that never reads chats (cl_quick) never calls it.
//
// Every path is the caller's (the home folder, the folders, the desktop app's data folder): nothing here names a place of
// its own but Claude Code's and the desktop app's own file names. Reads are bounded and never block on a FIFO or a device.

import Foundation
import ProfileCore

/// One sighting of an account: where it was seen and what that place says of it, its named fields only.
public struct FoundAccount: Equatable {
    /// Where it was seen.
    public enum Source: String, Equatable, Codable {
        /// A Claude Code folder's own record (.claude.json).
        case record
        /// A backup Claude Code keeps of a record (.claude.json.backup*).
        case backup
        /// The desktop app's Code sessions (claude-code-sessions/<account>/<organisation>/): names and dates only.
        case appSessions
        /// The desktop app's agent sessions (local-agent-mode-sessions/…): names, dates and the address a record names.
        case appAgentSessions
        /// A Claude Code transcript (the account id alone): read from chats.
        case transcript
    }

    /// The account id, in its normal form (AccountID.normal); always UUID-shaped.
    public var accountID: String
    /// The organisation's id in its normal form; nil when the place names none (a transcript).
    public var organizationID: String?
    public var email: String?
    /// The organisation's name and type as Claude wrote them (an app says them in its own words).
    public var organizationName: String?
    public var organizationType: String?
    /// The plan's name as recorded ("Ultra").
    public var plan: String?
    /// When the account was last used there (a session written under it); nil: not known.
    public var lastUsed: Date?
    public var source: Source
    /// The file or folder it was seen in.
    public var path: String

    public init(accountID: String, organizationID: String? = nil, email: String? = nil, organizationName: String? = nil,
                organizationType: String? = nil, plan: String? = nil, lastUsed: Date? = nil, source: Source, path: String) {
        self.accountID = AccountID.normal(accountID); self.organizationID = organizationID.map(AccountID.normal)
        self.email = email; self.organizationName = organizationName; self.organizationType = organizationType
        self.plan = plan; self.lastUsed = lastUsed; self.source = source; self.path = path
    }

    /// The seat it names, when the place names an organisation.
    public var seat: SeatID? { organizationID.map { SeatID(account: accountID, organization: $0) } }

    /// As ClaudeAuth names an account (guessed: a file).
    public var account: SignedInAccount {
        SignedInAccount(accountID: accountID, email: email, organizationID: organizationID, organizationName: organizationName,
                        plan: plan, origin: .record)
    }
}

/// The sightings put together, first seen first (the order the caller read its sources in): each account's address and plan,
/// each organisation's name and type, every seat in order, and when each seat was last used.
public struct FoundAccounts: Equatable {
    public var emails: [String: String] = [:]                 // account id → address
    public var plans: [String: String] = [:]                  // account id → plan
    public var organizationNames: [String: String] = [:]      // organisation id → name
    public var organizationTypes: [String: String] = [:]      // organisation id → type
    public var seats: [SeatID] = []                           // every account/organisation pair, in the order seen
    public var lastUsed: [SeatID: Date] = [:]
    /// Accounts seen by their id alone (no organisation named: a transcript's) and by no seat.
    public var idsAlone: [String] = []

    public init() {}

    public init(_ found: [FoundAccount]) { self.init(); add(found) }

    /// Adds sightings: a value already known is kept (first seen wins), a later date of use replaces an earlier one.
    public mutating func add(_ found: [FoundAccount]) {
        for f in found {
            let a = f.accountID
            if emails[a] == nil, let e = f.email, !e.isEmpty { emails[a] = e }
            if plans[a] == nil, let p = f.plan?.trimmingCharacters(in: .whitespaces), !p.isEmpty { plans[a] = p }
            if let s = f.seat {
                if organizationNames[s.organization] == nil, let n = f.organizationName, !n.isEmpty { organizationNames[s.organization] = n }
                if organizationTypes[s.organization] == nil, let t = f.organizationType, !t.isEmpty { organizationTypes[s.organization] = t }
                if !seats.contains(s) { seats.append(s) }
                if let d = f.lastUsed, d > (lastUsed[s] ?? .distantPast) { lastUsed[s] = d }
                idsAlone.removeAll { $0 == a }                    // now known by a seat
            } else if !idsAlone.contains(a), !seats.contains(where: { $0.account == a }) {
                idsAlone.append(a)
            }
        }
    }

    /// The organisation the account's own record named first (its first seat seen), nil when none was.
    public func organization(of account: String) -> String? {
        let a = AccountID.normal(account)
        return seats.first { $0.account == a }?.organization
    }

    /// Every account seen, in the order seen (by a seat or by its id alone).
    public var accounts: [String] {
        var out: [String] = []
        for a in seats.map(\.account) + idsAlone where !out.contains(a) { out.append(a) }
        return out
    }
}

public enum AccountSources {
    /// A name shaped like a UUID (any case), as Claude names accounts, organisations and sessions.
    public static func isUUID(_ s: String) -> Bool { UUID(uuidString: s) != nil }

    // MARK: Claude Code's records

    /// A folder's record and the backups Claude Code keeps of it, the record first: <folder>/backups/.claude.json.backup*,
    /// and for the default folder also <home>/.claude.json.backup*. Names only (nothing is read).
    public static func folderRecordFiles(_ folder: AuthFolder) -> [String] {
        var out = [folder.recordPath]
        func backups(_ d: String) {
            for n in list(d) where n.hasPrefix(".claude.json.backup") { out.append((d as NSString).appendingPathComponent(n)) }
        }
        backups((folder.path as NSString).appendingPathComponent("backups"))
        if folder.isDefault { backups(folder.home) }
        return out
    }

    /// The Claude Code folders in a home folder: ~/.claude first, then every ~/.claude-* folder by name (a real folder, not
    /// a link to one). As paths with ~ (the way a person names them).
    public static func claudeFolders(home: String) -> [String] {
        list(home).filter { n in
            guard n == ".claude" || n.hasPrefix(".claude-") else { return false }
            var st = stat()
            return lstat((home as NSString).appendingPathComponent(n), &st) == 0 && (st.st_mode & S_IFMT) == S_IFDIR
        }
        .sorted { a, b in a == ".claude" ? true : b == ".claude" ? false : a < b }
        .map { "~/" + $0 }
    }

    /// Every record in a home folder: each ~/.claude* (a folder's .claude.json, or the file itself) and each
    /// ~/.claude-switch/accounts/<name>/.claude.json (claude-transplant's). Names only. Read for the profile on the default
    /// folder (it collects every folder's account: an app adds none of them to another profile by itself).
    public static func homeRecordFiles(home: String) -> [String] {
        let fm = FileManager.default
        var out: [String] = []
        for n in list(home) where n.hasPrefix(".claude") {
            let p = (home as NSString).appendingPathComponent(n)
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: p, isDirectory: &isDir) else { continue }
            out.append(isDir.boolValue ? (p as NSString).appendingPathComponent(".claude.json") : p)
        }
        let sw = (home as NSString).appendingPathComponent(".claude-switch/accounts")
        for n in list(sw) { out.append((sw as NSString).appendingPathComponent("\(n)/.claude.json")) }
        return out
    }

    /// The accounts the records at `paths` name (their oauthAccount blocks, named fields only, bounded reads): one sighting
    /// per record with a UUID-shaped account id, in order; a `.claude.json.backup*` is a backup. `read`: the record reader
    /// (RecordFile's, bounded, by default; an app passes its own cached one).
    public static func records(_ paths: [String], read: (String) -> [String: Any]? = { RecordFile.oauthAccount($0) }) -> [FoundAccount] {
        paths.compactMap { p in
            guard let o = read(p), let a = o["accountUuid"] as? String, isUUID(a) else { return nil }
            func text(_ k: String) -> String? { (o[k] as? String).flatMap { $0.isEmpty ? nil : $0 } }
            let org = text("organizationUuid").flatMap { isUUID($0) ? $0 : nil }
            let backup = (p as NSString).lastPathComponent.hasPrefix(".claude.json.backup")
            return FoundAccount(accountID: a, organizationID: org, email: text("emailAddress"), organizationName: text("organizationName"),
                                organizationType: text("organizationType"), plan: text("planDisplayName"),
                                source: backup ? .backup : .record, path: p)
        }
    }

    // MARK: the desktop app's sessions (an option: cl_audit's)

    /// APP SESSIONS (an option; it opens the desktop app's agent session records): the account/organisation pairs under a
    /// desktop app's data folder, with when a session was last written under each. claude-code-sessions/<account>/<org>/:
    /// its local_<UUID>.json entries' names and dates only, none opened. local-agent-mode-sessions/<account>/<org>/: its
    /// records' dates, and the address the first of them that names one says (at most `records` opened, each bounded).
    /// Both names UUID-shaped, real folders and files only (a link is never followed). `limit`: at most that many names
    /// looked at in each folder.
    public static func appSessions(dataDir: String, records: Int = 50, limit: Int? = nil) -> [FoundAccount] {
        let fm = FileManager.default
        var out: [FoundAccount] = []
        for (kind, agent) in [("claude-code-sessions", false), ("local-agent-mode-sessions", true)] {
            let root = (dataDir as NSString).appendingPathComponent(kind)
            for a in names(root, limit: limit) where isUUID(a) {
                let adir = (root as NSString).appendingPathComponent(a)
                guard isRealFolder(adir) else { continue }
                for o in names(adir, limit: limit) where isUUID(o) {
                    let odir = (adir as NSString).appendingPathComponent(o)
                    guard isRealFolder(odir) else { continue }
                    let files = names(odir, limit: limit).filter { agent ? $0.hasSuffix(".json") : isEntryName($0) }
                        .filter { isRealFile((odir as NSString).appendingPathComponent($0)) }
                    let dates = files.compactMap { (try? fm.attributesOfItem(atPath: (odir as NSString).appendingPathComponent($0)))?[.modificationDate] as? Date }
                    var email: String?
                    if agent {
                        for f in files.prefix(records) {
                            guard let d = RecordFile.read((odir as NSString).appendingPathComponent(f), max: RecordFile.max),
                                  let j = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
                                  let e = j["emailAddress"] as? String, !e.isEmpty else { continue }
                            email = e
                            break
                        }
                    }
                    out.append(FoundAccount(accountID: a, organizationID: o, email: email, lastUsed: dates.max(),
                                            source: agent ? .appAgentSessions : .appSessions, path: odir))
                }
            }
        }
        return out
    }

    /// A desktop app's Code session entry's name: local_<UUID>.json (any case).
    public static func isEntryName(_ n: String) -> Bool {
        n.hasPrefix("local_") && n.hasSuffix(".json") && isUUID(String(n.dropFirst("local_".count).dropLast(".json".count)))
    }

    // MARK: transcripts (an option: cl_audit's; it reads chats)

    /// TRANSCRIPTS (an option; IT READS CHATS): the account ids a Claude Code folder's transcripts name
    /// ("accountUuid":"<uuid>"), from the first `head` bytes of each <folder>/projects/*/*.jsonl, at most `cap` of them,
    /// newest first. Ids alone (no organisation), one sighting per id, in the order found. An app that stays incognito
    /// never calls it.
    public static func transcriptAccounts(folder: AuthFolder, cap: Int = 400, head: Int = 64 << 10) -> [FoundAccount] {
        let fm = FileManager.default
        let projects = (folder.path as NSString).appendingPathComponent("projects")
        var files: [(String, Date)] = []
        for p in list(projects) {
            let dir = (projects as NSString).appendingPathComponent(p)
            for n in list(dir) where n.hasSuffix(".jsonl") {
                let f = (dir as NSString).appendingPathComponent(n)
                files.append((f, ((try? fm.attributesOfItem(atPath: f))?[.modificationDate] as? Date) ?? .distantPast))
            }
        }
        let re = try! NSRegularExpression(pattern: #""accountUuid"\s*:\s*"([0-9a-fA-F-]{36})""#)
        var out: [FoundAccount] = []
        for (f, _) in files.sorted(by: { $0.1 > $1.1 }).prefix(cap) {
            guard let d = RecordFile.head(f, bytes: head) else { continue }        // a FIFO or a device: skipped at once
            let s = String(decoding: d, as: UTF8.self)
            for m in re.matches(in: s, range: NSRange(s.startIndex..., in: s)) {
                guard let r = Range(m.range(at: 1), in: s), isUUID(String(s[r])) else { continue }
                let a = AccountID.normal(String(s[r]))
                if !out.contains(where: { $0.accountID == a }) { out.append(FoundAccount(accountID: a, source: .transcript, path: f)) }
            }
        }
        return out
    }

    // MARK: folders

    static func list(_ dir: String) -> [String] { ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []).sorted() }

    /// A folder's names, sorted (at most `limit` looked at, in the order the disk gives them).
    static func names(_ dir: String, limit: Int?) -> [String] {
        guard let limit else { return list(dir) }
        guard let d = opendir(dir) else { return [] }
        defer { closedir(d) }
        var out: [String] = []
        var seen = 0
        while seen < limit, let e = readdir(d) {
            seen += 1
            let n = withUnsafePointer(to: e.pointee.d_name) { $0.withMemoryRebound(to: CChar.self, capacity: 256) { String(cString: $0) } }
            if n != "." && n != ".." { out.append(n) }
        }
        return out.sorted()
    }

    static func isRealFolder(_ p: String) -> Bool { var st = stat(); return lstat(p, &st) == 0 && (st.st_mode & S_IFMT) == S_IFDIR }
    static func isRealFile(_ p: String) -> Bool { var st = stat(); return lstat(p, &st) == 0 && (st.st_mode & S_IFMT) == S_IFREG }
}
