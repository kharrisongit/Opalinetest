import Foundation

// Each edit is an immutable revision. Concurrent branches remain separate drafts.
struct Revision: Codable, Equatable {
    var format = 1
    var id: UUID
    var noteID: UUID
    var parents: [UUID]
    var title: String
    var body: String
    var notebook: String
    var tags: String
    var favorite: Bool
    var deleted: Bool
    var modified: Date

    init(title: String = "", body: String = "", notebook: String = "Lyrics") {
        id = UUID(); noteID = UUID(); parents = []
        self.title = title; self.body = body; self.notebook = notebook
        tags = ""; favorite = false; deleted = false; modified = Date()
    }
    var displayTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled lyric" : title }
    var words: Int { body.split { $0.isWhitespace || $0.isNewline }.count }
    func edited() -> Revision {
        var next = self
        next.id = UUID(); next.parents = [id]; next.modified = Date()
        return next
    }
    var valid: Bool {
        format == 1 && title.utf8.count <= 4096 && body.utf8.count <= 2_000_000 &&
        notebook.utf8.count <= 1024 && tags.utf8.count <= 4096 && parents.count <= 100 && !parents.contains(id)
    }
}

enum RevisionGraph {
    static func heads(_ revisions: [Revision]) -> [Revision] {
        // Parent links only retire revisions belonging to the same note.
        let byID = Dictionary(revisions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let retired = Set(revisions.flatMap { child in child.parents.filter { byID[$0]?.noteID == child.noteID } })
        return byID.values.filter { !retired.contains($0.id) }.sorted {
            if $0.modified == $1.modified { return $0.id.uuidString < $1.id.uuidString }
            return $0.modified > $1.modified
        }
    }
}

struct RhymeHit { let word: String; let syllables: Int }
final class RhymeDictionary {
    struct Entry { let word: String; let syllables: Int; let tail: String; let vowels: String }
    private var entries: [Entry] = []
    private var lookup: [String: [Entry]] = [:]
    init(text: String) {
        for line in text.components(separatedBy: .newlines) {
            let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count > 1, !parts[0].hasPrefix(";;;"), !parts[0].hasPrefix("#") else { continue }
            let word = parts[0].lowercased().components(separatedBy: "(")[0]
            guard word.range(of: "^[a-z]+(?:'[a-z]+)?$", options: .regularExpression) != nil else { continue }
            let phones = Array(parts.dropFirst()).prefix { $0 != "#" }
            let vowelIndices = phones.indices.filter { phones[$0].last?.isNumber == true }
            guard let finalVowel = vowelIndices.last else { continue }
            let stressed = vowelIndices.last { phones[$0].hasSuffix("1") || phones[$0].hasSuffix("2") } ?? finalVowel
            let tailPhones = phones[stressed...].map { $0.filter { !$0.isNumber } }
            let entry = Entry(word: word, syllables: vowelIndices.count,
                              tail: tailPhones.joined(separator: " "),
                              vowels: phones[stressed...].filter { $0.last?.isNumber == true }.map { $0.filter { !$0.isNumber } }.joined(separator: " "))
            entries.append(entry); lookup[word, default: []].append(entry)
        }
    }
    func find(_ input: String, near: Bool, syllables: Int = 0) -> [RhymeHit] {
        let word = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let source = lookup[word] else { return [] }
        let tails = Set(source.map(\.tail)); let vowels = Set(source.map(\.vowels))
        var seen = Set<String>()
        return entries.filter { entry in
            guard entry.word != word, syllables == 0 || entry.syllables == syllables else { return false }
            let matches = near ? vowels.contains(entry.vowels) && !tails.contains(entry.tail) : tails.contains(entry.tail)
            return matches && seen.insert(entry.word).inserted
        }.sorted {
            if $0.syllables != $1.syllables { return $0.syllables < $1.syllables }
            if $0.word.count != $1.word.count { return $0.word.count < $1.word.count }
            return $0.word < $1.word
        }.prefix(240).map { RhymeHit(word: $0.word, syllables: $0.syllables) }
    }
    func contains(_ word: String) -> Bool { lookup[word.lowercased()] != nil }
}
