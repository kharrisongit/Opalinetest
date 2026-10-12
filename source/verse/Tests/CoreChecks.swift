import Foundation

@main struct CoreChecks {
    static func main() throws {
        let initial = Revision(title: "Song", body: "First line")
        var a = initial.edited(); a.body = "Device A"
        var b = initial.edited(); b.body = "Device B"
        let heads = RevisionGraph.heads([initial, a, b])
        precondition(heads.count == 2, "Concurrent offline edits must both survive")
        var next = a.edited(); next.body = "Device A newer"
        precondition(Set(RevisionGraph.heads([initial, a, b, next]).map(\.id)) == Set([b.id, next.id]))
        var deleted = next.edited(); deleted.deleted = true
        precondition(RevisionGraph.heads([initial, a, b, next, deleted]).filter { !$0.deleted }.map(\.id) == [b.id])
        var foreign = Revision(); foreign.parents = [b.id]
        precondition(RevisionGraph.heads([initial, a, b, foreign]).count == 3, "Other notes cannot retire revisions")
        precondition(RevisionGraph.heads([initial, initial]).count == 1)
        let restored = try JSONDecoder().decode(Revision.self, from: JSONEncoder().encode(next))
        precondition(restored == next && restored.valid)
        let dictionary = RhymeDictionary(text: "light L AY1 T\nnight N AY1 T\nwhite W AY1 T\nmind M AY1 N D\ndelight D IH0 L AY1 T\nrecord R EH1 K ER0 D\nrecord(2) R IH0 K AO1 R D")
        precondition(Set(dictionary.find("light", near: false).map(\.word)) == Set(["night", "white", "delight"]))
        precondition(dictionary.find("light", near: true).map(\.word) == ["mind"])
        precondition(dictionary.find("light", near: false, syllables: 2).map(\.word) == ["delight"])
        precondition(dictionary.find("nonsenseword", near: false).isEmpty)
        print("PASS: concurrent edits, deletes, identity boundaries, backup roundtrip, perfect/near rhymes, syllables")
    }
}
