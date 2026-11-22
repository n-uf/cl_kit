// ClaudeAuth · the one folder reader: a folder's .claude.json, read for the account in it (oauthAccount's named fields
// only), bounded, and parsed again only when the file's stamp moved. Claude Code rewrites the file often (every session
// writes it) and it can be several MB, so each look is one stat and a parse only after a write. The reader is a value
// the app owns (one per app, shared by its parts); the kit keeps no global state.

import Foundation
import ProfileCore

/// Reads folders' records. Safe from any thread; a parse runs on the caller's thread (off the main thread for a large file).
public final class FolderRecordReader: @unchecked Sendable {
    /// One look at a record.
    public struct Look: Equatable {
        /// The account the record names now (guessed); nil when it names nobody, isn't there or can't be read.
        public var account: SignedInAccount?
        /// The record's stamp the account was read at.
        public var stamp: RecordStamp
        /// The record names another seat than at the last parse (signed in, signed out, or another account or seat);
        /// the first parse of a file is no change, and a rewrite for the same seat isn't one. Said once per change, by
        /// the look whose parse found it.
        public var changed: Bool
    }

    private let parse: (String) -> [String: Any]?
    private let stampOf: (String) -> RecordStamp
    private var cache: [String: (stamp: RecordStamp, account: SignedInAccount?)] = [:]
    private let lock = NSLock()

    /// `parse` reads a record file's oauthAccount block (bounded, never blocking on a FIFO: RecordFile's by default);
    /// `stamp` is the file's stamp now (RecordStamp.of). Both are parameters for the checks.
    public init(parse: @escaping (String) -> [String: Any]? = { RecordFile.oauthAccount($0) },
                stamp: @escaping (String) -> RecordStamp = { RecordStamp.of($0) }) {
        self.parse = parse; self.stampOf = stamp
    }

    /// The folder's record now.
    public func look(_ folder: AuthFolder) -> Look { look(path: folder.recordPath) }

    /// The record at `path` now: from the last parse while its stamp is the same, else parsed again. A parse that a
    /// write overtook (the stamp moved while it read) is returned but never kept, so the next look parses again.
    public func look(path: String) -> Look {
        let before = stampOf(path)
        lock.lock()
        if let hit = cache[path], hit.stamp == before { lock.unlock(); return Look(account: hit.account, stamp: before, changed: false) }
        lock.unlock()
        let account = before == .none ? nil : SignedInAccount.record(parse(path))
        guard stampOf(path) == before else { return Look(account: account, stamp: before, changed: false) }
        lock.lock(); defer { lock.unlock() }
        // another thread may have parsed the same file meanwhile: the change is said by whichever kept it first
        if let hit = cache[path], hit.stamp == before { return Look(account: hit.account, stamp: before, changed: false) }
        let last = cache[path]
        cache[path] = (before, account)
        let changed = last.map { Self.otherSeat($0.account, account) } ?? false
        return Look(account: account, stamp: before, changed: changed)
    }

    /// Forgets a record (a folder no longer followed); its next look is a first parse again.
    public func forget(path: String) { lock.lock(); cache[path] = nil; lock.unlock() }

    static func otherSeat(_ a: SignedInAccount?, _ b: SignedInAccount?) -> Bool {
        switch (a, b) {
        case (nil, nil): return false
        case (let a?, let b?): return a.match(b) != .seat
        default: return true
        }
    }
}
