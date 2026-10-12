import UIKit
import UniformTypeIdentifiers

extension Notification.Name { static let verseChanged = Notification.Name("verseChanged") }

final class VerseStore {
    static let shared = VerseStore()
    private(set) var revisions: [UUID: Revision] = [:]
    private(set) var syncStatus = "Saved on this device"
    private(set) var cloudFolder: URL?
    private(set) var lastSync: Date?
    private var syncing = false
    private var syncAgain = false
    private let io = DispatchQueue(label: "com.kharrison.verse.sync", qos: .utility)
    private var timer: Timer?
    private var local: URL!
    private(set) var loadError: String?
    private var scopeStarted = false
    var heads: [Revision] { RevisionGraph.heads(Array(revisions.values)) }
    var notebooks: [String] { Array(Set(heads.filter { !$0.deleted }.map(\.notebook) + ["Lyrics", "Ideas"])).sorted() }
    var isLinked: Bool { cloudFolder != nil }

    private init() {
        do {
            local = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("VerseRevisions", isDirectory: true)
            try FileManager.default.createDirectory(at: local, withIntermediateDirectories: true)
            for file in try FileManager.default.contentsOfDirectory(at: local, includingPropertiesForKeys: nil) where file.lastPathComponent.hasSuffix(".verse.json") {
                do { let revision = try Self.read(file); revisions[revision.id] = revision }
                catch { loadError = "Some saved revisions could not be read. Original files have been kept." }
            }
            if let data = UserDefaults.standard.data(forKey: "cloudFolderBookmark") {
                var stale = false
                let url = try URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
                scopeStarted = url.startAccessingSecurityScopedResource()
                cloudFolder = url
                if stale { try remember(url) }
                syncStatus = "Ready to sync"
            }
        } catch { loadError = error.localizedDescription; syncStatus = "Storage needs attention" }
        timer = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in self?.sync() }
    }
    private func remember(_ url: URL) throws {
        let data = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(data, forKey: "cloudFolderBookmark")
    }
    func connect(_ url: URL) throws {
        guard !syncing else { throw NSError(domain: "Verse", code: 1, userInfo: [NSLocalizedDescriptionKey: "Wait for the current sync to finish, then choose the folder again."]) }
        let access = url.startAccessingSecurityScopedResource()
        do {
            try remember(url)
            if scopeStarted { cloudFolder?.stopAccessingSecurityScopedResource() }
            cloudFolder = url; scopeStarted = access
            syncStatus = "Connecting…"; changed(); sync()
        } catch { if access { url.stopAccessingSecurityScopedResource() }; throw error }
    }
    func disconnect() {
        guard !syncing else { return }
        if scopeStarted { cloudFolder?.stopAccessingSecurityScopedResource() }
        cloudFolder = nil; scopeStarted = false
        UserDefaults.standard.removeObject(forKey: "cloudFolderBookmark")
        syncStatus = "Saved on this device"; changed()
    }
    @discardableResult func save(_ revision: Revision) throws -> Revision {
        guard revision.valid, let local else { throw NSError(domain: "Verse", code: 2, userInfo: [NSLocalizedDescriptionKey: "This lyric is too large, or local storage is unavailable."]) }
        let data = try JSONEncoder().encode(revision)
        try data.write(to: local.appendingPathComponent(revision.id.uuidString + ".verse.json"), options: .atomic)
        revisions[revision.id] = revision
        syncStatus = isLinked ? "Changes waiting to sync" : "Saved on this device"
        changed(); sync()
        return revision
    }
    private func changed() { NotificationCenter.default.post(name: .verseChanged, object: nil) }
    private static func read(_ file: URL) throws -> Revision {
        let values = try file.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey])
        guard values.isSymbolicLink != true, (values.fileSize ?? 0) <= 2_100_000 else { throw CocoaError(.fileReadCorruptFile) }
        let revision = try JSONDecoder().decode(Revision.self, from: Data(contentsOf: file))
        guard revision.valid, file.lastPathComponent == revision.id.uuidString + ".verse.json" else { throw CocoaError(.fileReadCorruptFile) }
        return revision
    }
    func sync() {
        guard let root = cloudFolder, let local else { return }
        guard !syncing else { syncAgain = true; return }
        syncing = true; syncStatus = "Syncing with Files…"; changed()
        let known = revisions
        io.async {
            var imported: [Revision] = []
            var problem: Error?
            var coordinationError: NSError?
            // Coordinate provider access; immutable files avoid last-writer-wins loss.
            NSFileCoordinator().coordinate(writingItemAt: root, options: .forMerging, error: &coordinationError) { coordinatedRoot in
                let coordinated = coordinatedRoot.appendingPathComponent("Verse", isDirectory: true)
                do {
                    try FileManager.default.createDirectory(at: coordinated, withIntermediateDirectories: true)
                    let files = try FileManager.default.contentsOfDirectory(at: coordinated, includingPropertiesForKeys: [.fileSizeKey])
                    let remoteNames = Set(files.map(\.lastPathComponent))
                    for file in files where file.lastPathComponent.hasSuffix(".verse.json") {
                        guard let id = UUID(uuidString: String(file.lastPathComponent.dropLast(".verse.json".count))), known[id] == nil else { continue }
                        let revision = try Self.read(file)
                        let destination = local.appendingPathComponent(file.lastPathComponent)
                        try JSONEncoder().encode(revision).write(to: destination, options: .atomic)
                        imported.append(revision)
                    }
                    for revision in known.values {
                        let name = revision.id.uuidString + ".verse.json"
                        if !remoteNames.contains(name) {
                            try JSONEncoder().encode(revision).write(to: coordinated.appendingPathComponent(name), options: .atomic)
                        }
                    }
                } catch { problem = error }
            }
            let finalError = problem ?? coordinationError
            DispatchQueue.main.async {
                imported.forEach { self.revisions[$0.id] = $0 }
                self.syncing = false
                if let finalError { self.syncStatus = "Sync paused: " + finalError.localizedDescription }
                else { self.lastSync = Date(); self.syncStatus = "Saved to sync folder" }
                self.changed()
                if self.syncAgain { self.syncAgain = false; self.sync() }
            }
        }
    }
    func exportBackup() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Verse-backup-\(Int(Date().timeIntervalSince1970)).json")
        try JSONEncoder().encode(Array(revisions.values)).write(to: url, options: .atomic)
        return url
    }
    func importBackup(_ url: URL) throws {
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size < 100_000_000 else { throw CocoaError(.fileReadTooLarge) }
        let incoming = try JSONDecoder().decode([Revision].self, from: Data(contentsOf: url))
        guard incoming.allSatisfy(\.valid), let local else { throw CocoaError(.fileReadCorruptFile) }
        for revision in incoming where revisions[revision.id] == nil {
            try JSONEncoder().encode(revision).write(to: local.appendingPathComponent(revision.id.uuidString + ".verse.json"), options: .atomic)
            revisions[revision.id] = revision
        }
        changed(); sync()
    }
}
