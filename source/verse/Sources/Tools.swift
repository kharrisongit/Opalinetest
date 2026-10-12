import UIKit
import UniformTypeIdentifiers

final class RhymeService {
    static let shared = RhymeService()
    private(set) var dictionary: RhymeDictionary?
    private var loading = false
    private(set) var error: String?
    func load() {
        guard dictionary == nil, !loading else { return }; loading = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard let url = Bundle.main.url(forResource: "cmudict", withExtension: "dict") else { throw CocoaError(.fileNoSuchFile) }
                let dictionary = RhymeDictionary(text: try String(contentsOf: url, encoding: .utf8))
                DispatchQueue.main.async { self.dictionary = dictionary; self.loading = false; NotificationCenter.default.post(name: Notification.Name("verseDictionary"), object: nil) }
            } catch {
                DispatchQueue.main.async { self.error = "The offline dictionary could not be loaded."; self.loading = false; NotificationCenter.default.post(name: Notification.Name("verseDictionary"), object: nil) }
            }
        }
    }
}

final class RhymeController: UITableViewController, UISearchBarDelegate {
    var initialWord = ""
    var onPick: ((String) -> Void)?
    private let search = UISearchBar()
    private let mode = UISegmentedControl(items: ["Perfect", "Near"])
    private let syllables = UISegmentedControl(items: ["Any", "1", "2", "3", "4"])
    private var hits: [RhymeHit] = []
    private var observer: NSObjectProtocol?
    private var pending: DispatchWorkItem?
    override func viewDidLoad() {
        super.viewDidLoad(); title = "Rhyme finder"
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        search.placeholder = "Find rhymes for a word"; search.autocapitalizationType = .none; search.autocorrectionType = .no; search.delegate = self; search.text = initialWord
        mode.selectedSegmentIndex = 0; syllables.selectedSegmentIndex = 0
        mode.addTarget(self, action: #selector(findRhymes), for: .valueChanged); syllables.addTarget(self, action: #selector(findRhymes), for: .valueChanged)
        mode.accessibilityLabel = "Rhyme type"; syllables.accessibilityLabel = "Syllable count"
        let label = UILabel(); label.text = "SYLLABLES"; label.font = .preferredFont(forTextStyle: .caption2); label.textColor = .secondaryLabel
        let stack = UIStackView(arrangedSubviews: [search, mode, label, syllables]); stack.axis = .vertical; stack.spacing = 10
        stack.isLayoutMarginsRelativeArrangement = true; stack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 6, leading: 20, bottom: 16, trailing: 20)
        stack.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 185); tableView.tableHeaderView = stack
        if onPick != nil { navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done)) }
        observer = NotificationCenter.default.addObserver(forName: Notification.Name("verseDictionary"), object: nil, queue: .main) { [weak self] _ in self?.findRhymes() }
        RhymeService.shared.load(); findRhymes()
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) }; pending?.cancel() }
    @objc private func done() { dismiss(animated: true) }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) { searchBar.resignFirstResponder(); findRhymes() }
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        pending?.cancel(); let work = DispatchWorkItem { [weak self] in self?.findRhymes() }; pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }
    @objc private func findRhymes() {
        let word = search.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        hits = RhymeService.shared.dictionary?.find(word, near: mode.selectedSegmentIndex == 1, syllables: syllables.selectedSegmentIndex) ?? []
        tableView.reloadData()
        let label = UILabel(); label.font = .preferredFont(forTextStyle: .body); label.textColor = .secondaryLabel; label.textAlignment = .center; label.numberOfLines = 0
        if let error = RhymeService.shared.error { label.text = error }
        else if RhymeService.shared.dictionary == nil { label.text = "Loading your offline dictionary…" }
        else if word.isEmpty { label.text = "A word can open a whole verse.\n\nTry light, rain, or home.\nAll lookups stay on your device." }
        else if RhymeService.shared.dictionary?.contains(word) == false { label.text = "That word isn’t in the English dictionary.\nCheck its spelling or try a single word." }
        else { label.text = "No matches with these filters.\nTry Near rhymes or Any syllables." }
        tableView.backgroundView = hits.isEmpty ? label : nil
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { hits.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { hits.isEmpty ? nil : "\(hits.count) suggestions\(hits.count == 240 ? " · first 240" : "")" }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { "\(onPick == nil ? "Tap a word to copy it." : "Tap a word to insert it into your lyric.") Near rhymes match vowel sounds and may be loose. English pronunciations: CMU Pronouncing Dictionary." }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil); let hit = hits[indexPath.row]
        cell.textLabel?.text = hit.word; cell.textLabel?.font = .preferredFont(forTextStyle: .body)
        cell.detailTextLabel?.text = "\(hit.syllables) \(hit.syllables == 1 ? "syllable" : "syllables")"
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let word = hits[indexPath.row].word
        if let onPick { dismiss(animated: true) { onPick(word) } }
        else { UIPasteboard.general.string = word; let cell = tableView.cellForRow(at: indexPath); cell?.detailTextLabel?.text = "Copied"; DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.tableView.reloadData() } }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

final class SettingsController: UITableViewController, UIDocumentPickerDelegate {
    private var importing = false
    private var observer: NSObjectProtocol?
    override func viewDidLoad() {
        super.viewDidLoad(); title = "Settings"
        observer = NotificationCenter.default.addObserver(forName: .verseChanged, object: nil, queue: .main) { [weak self] _ in self?.tableView.reloadData() }
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    override func numberOfSections(in tableView: UITableView) -> Int { 4 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { [4, 1, 2, 1][section] }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { ["Cloud sync", "Writing", "Your data", "About"][section] }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0: return "Choose the same iCloud Drive folder on each device. Verse creates its own subfolder and syncs while the app is open. Files handles cloud upload and download; provider delays can occur. A folder under On My iPhone stays local. Parallel edits are kept as separate drafts."
        case 1: return "Spell check is always enabled. Use Check spelling in the editor to review suggestions. Autocorrect is off initially so it won’t change your lyrics without asking."
        case 2: return "Backups include every saved revision and deleted lyric. Keep one before removing the app. Restore merges revisions without replacing existing lyrics."
        default: return "Verse · by kharrison\nA little space for your next song."
        }
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil); cell.textLabel?.numberOfLines = 0; cell.detailTextLabel?.numberOfLines = 0
        switch (indexPath.section, indexPath.row) {
        case (0, 0): cell.textLabel?.text = VerseStore.shared.isLinked ? "Change sync folder" : "Connect iCloud Drive folder"; cell.imageView?.image = UIImage(systemName: "icloud"); cell.accessoryType = .disclosureIndicator
        case (0, 1): cell.textLabel?.text = "Sync now"; cell.detailTextLabel?.text = VerseStore.shared.syncStatus
        case (0, 2): cell.textLabel?.text = "Connected folder"; cell.detailTextLabel?.text = VerseStore.shared.cloudFolder?.lastPathComponent ?? "None · lyrics are saved on this device"; cell.selectionStyle = .none
        case (0, 3): cell.textLabel?.text = "Disconnect folder"; cell.textLabel?.textColor = .systemRed
        case (1, 0):
            cell.textLabel?.text = "Autocorrect while typing"; let toggle = UISwitch(); toggle.isOn = UserDefaults.standard.bool(forKey: "autocorrect"); toggle.addTarget(self, action: #selector(autocorrect(_:)), for: .valueChanged); cell.accessoryView = toggle; cell.selectionStyle = .none
        case (2, 0): cell.textLabel?.text = "Export complete backup"; cell.imageView?.image = UIImage(systemName: "square.and.arrow.up")
        case (2, 1): cell.textLabel?.text = "Restore backup"; cell.imageView?.image = UIImage(systemName: "square.and.arrow.down")
        default: cell.textLabel?.text = "Verse \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")"; cell.detailTextLabel?.text = "Offline rhyme dictionary & licenses"; cell.accessoryType = .disclosureIndicator
        }
        return cell
    }
    @objc private func autocorrect(_ sender: UISwitch) { UserDefaults.standard.set(sender.isOn, forKey: "autocorrect") }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch (indexPath.section, indexPath.row) {
        case (0, 0): importing = false; let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder]); picker.delegate = self; present(picker, animated: true)
        case (0, 1): if VerseStore.shared.isLinked { VerseStore.shared.sync() } else { message("Connect a folder first", "Choose Connect iCloud Drive folder, then select or create a folder under iCloud Drive.") }
        case (0, 3):
            let alert = UIAlertController(title: "Disconnect sync?", message: "Lyrics stay on this device and in the folder. New changes will be saved locally until you reconnect.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel)); alert.addAction(UIAlertAction(title: "Disconnect", style: .destructive) { _ in VerseStore.shared.disconnect() }); present(alert, animated: true)
        case (2, 0): do { share([try VerseStore.shared.exportBackup()]) } catch { message("Couldn’t export", error.localizedDescription) }
        case (2, 1): importing = true; let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true); picker.delegate = self; present(picker, animated: true)
        case (3, 0):
            let controller = UIViewController(); controller.title = "Dictionary license"; let text = UITextView(); text.isEditable = false; text.font = .preferredFont(forTextStyle: .body); text.textContainerInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
            if let url = Bundle.main.url(forResource: "CMUDICT-LICENSE", withExtension: "txt") { text.text = try? String(contentsOf: url, encoding: .utf8) }
            controller.view = text; navigationController?.pushViewController(controller, animated: true)
        default: break
        }
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        do {
            if importing { try VerseStore.shared.importBackup(url); message("Backup restored", "Your lyrics and saved revisions have been merged.") }
            else { try VerseStore.shared.connect(url) }
        } catch { message("Couldn’t open folder or backup", error.localizedDescription) }
        tableView.reloadData()
    }
}
