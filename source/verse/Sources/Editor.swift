import UIKit

final class EditorController: UIViewController, UITextViewDelegate, UITextFieldDelegate {
    private var note: Revision
    private let titleField = UITextField()
    private let text = UITextView()
    private let meta = UILabel()
    private var dirty = false
    private var pending: DispatchWorkItem?
    private var observers: [NSObjectProtocol] = []
    init(note: Revision) { self.note = note; super.init(nibName: nil, bundle: nil); hidesBottomBarWhenPushed = true }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItems = [UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: moreMenu()), UIBarButtonItem(title: "Rhyme", style: .plain, target: self, action: #selector(rhyme))]
        titleField.text = note.title; titleField.placeholder = "Untitled lyric"
        titleField.font = .systemFont(ofSize: 30, weight: .bold); titleField.adjustsFontForContentSizeCategory = true
        titleField.accessibilityLabel = "Lyric title"; titleField.returnKeyType = .next; titleField.delegate = self
        titleField.addTarget(self, action: #selector(edited), for: .editingChanged)
        text.text = note.body; text.delegate = self
        text.font = .preferredFont(forTextStyle: .body); text.adjustsFontForContentSizeCategory = true
        text.textContainerInset = UIEdgeInsets(top: 12, left: 0, bottom: 30, right: 0)
        text.accessibilityLabel = "Lyrics"; text.alwaysBounceVertical = true
        text.spellCheckingType = .yes; text.autocorrectionType = UserDefaults.standard.bool(forKey: "autocorrect") ? .yes : .no
        text.smartQuotesType = .yes; text.smartDashesType = .yes; text.backgroundColor = .clear
        let bar = UIToolbar(); bar.sizeToFit()
        bar.items = [UIBarButtonItem(title: "+ Section", style: .plain, target: self, action: #selector(section)), UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), UIBarButtonItem(title: "Spelling", style: .plain, target: self, action: #selector(spelling)), UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), UIBarButtonItem(image: UIImage(systemName: "keyboard.chevron.compact.down"), style: .plain, target: self, action: #selector(closeKeyboard))]
        bar.items?[2].accessibilityLabel = "Check spelling"; bar.items?.last?.accessibilityLabel = "Dismiss keyboard"
        text.inputAccessoryView = bar
        meta.font = .preferredFont(forTextStyle: .caption1); meta.textColor = .secondaryLabel; meta.numberOfLines = 2
        [titleField, text, meta].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; view.addSubview($0) }
        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 22), titleField.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -22), titleField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18), titleField.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            meta.leadingAnchor.constraint(equalTo: titleField.leadingAnchor), meta.trailingAnchor.constraint(equalTo: titleField.trailingAnchor), meta.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 8),
            text.topAnchor.constraint(equalTo: meta.bottomAnchor, constant: 12), text.leadingAnchor.constraint(equalTo: titleField.leadingAnchor), text.trailingAnchor.constraint(equalTo: titleField.trailingAnchor), text.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        ])
        updateMeta()
        observers.append(NotificationCenter.default.addObserver(forName: Notification.Name("verseFlush"), object: nil, queue: .main) { [weak self] _ in self?.flush() })
        observers.append(NotificationCenter.default.addObserver(forName: .verseChanged, object: nil, queue: .main) { [weak self] _ in self?.receiveSyncedChanges() })
    }
    deinit { pending?.cancel(); observers.forEach(NotificationCenter.default.removeObserver) }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); flush() }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool { text.becomeFirstResponder(); return true }
    func textViewDidChange(_ textView: UITextView) { edited() }
    @objc private func edited() {
        dirty = true; pending?.cancel(); updateMeta()
        let work = DispatchWorkItem { [weak self] in self?.flush() }; pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
    }
    @discardableResult private func flush() -> Bool {
        pending?.cancel(); guard dirty else { return true }
        var next = note.edited(); next.title = String((titleField.text ?? "").prefix(1000)); next.body = text.text ?? ""
        do { try VerseStore.shared.save(next); note = next; dirty = false; updateMeta(); return true }
        catch { meta.text = "Couldn’t save. Your text is still here: \(error.localizedDescription)"; return false }
    }
    private func receiveSyncedChanges() {
        let heads = VerseStore.shared.heads.filter { $0.noteID == note.noteID }
        // Refresh an unedited open lyric, while leaving simultaneous branches intact.
        if !dirty, heads.count == 1, let current = heads.first, !current.deleted, current.id != note.id {
            let selection = text.selectedRange
            note = current; titleField.text = current.title; text.text = current.body
            let length = (current.body as NSString).length
            let start = min(selection.location, length)
            text.selectedRange = NSRange(location: start, length: min(selection.length, length - start))
        }
        updateMeta()
    }
    private func updateMeta() {
        title = note.notebook
        let count = (text.text ?? note.body).split { $0.isWhitespace || $0.isNewline }.count
        let lines = (text.text ?? note.body).components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        meta.text = "\(count) words · \(lines) lines\(note.tags.isEmpty ? "" : " · \(note.tags)")\n\(dirty ? "Saving…" : VerseStore.shared.syncStatus)"
    }
    private func moreMenu() -> UIMenu {
        UIMenu(children: [
            UIAction(title: "Move to notebook", image: UIImage(systemName: "folder")) { [weak self] _ in self?.moveNotebook() },
            UIAction(title: "Edit tags", image: UIImage(systemName: "tag")) { [weak self] _ in self?.editTags() },
            UIAction(title: "Toggle favorite", image: UIImage(systemName: "star")) { [weak self] _ in guard let self, self.flush() else { return }; self.note.favorite.toggle(); self.dirty = true; self.flush() },
            UIAction(title: "Check spelling", image: UIImage(systemName: "checkmark.abc")) { [weak self] _ in self?.spelling() },
            UIAction(title: "Share / export text", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in guard let self else { return }; self.flush(); self.share(["\(self.titleField.text ?? "Untitled lyric")\n\n\(self.text.text ?? "")"]) },
            UIAction(title: "Duplicate lyric", image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
                guard let self, self.flush() else { return }
                var copy = Revision(title: self.note.displayTitle + " (copy)", body: self.note.body, notebook: self.note.notebook); copy.tags = self.note.tags
                do { try VerseStore.shared.save(copy); self.navigationController?.pushViewController(EditorController(note: copy), animated: true) } catch { self.message("Couldn’t duplicate", error.localizedDescription) }
            }
        ])
    }
    private func moveNotebook() {
        let alert = UIAlertController(title: "Move to notebook", message: "Choose an existing notebook or type a new name.", preferredStyle: .alert)
        alert.addTextField { $0.text = self.note.notebook; $0.placeholder = "Notebook name" }
        for book in VerseStore.shared.notebooks.prefix(6) { alert.addAction(UIAlertAction(title: book, style: .default) { _ in self.setNotebook(book) }) }
        alert.addAction(UIAlertAction(title: "Use typed name", style: .default) { _ in self.setNotebook(alert.textFields?.first?.text ?? "Lyrics") })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel)); present(alert, animated: true)
    }
    private func setNotebook(_ name: String) {
        guard flush() else { return }
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines); guard !clean.isEmpty else { return }
        note.notebook = String(clean.prefix(100)); dirty = true; flush()
    }
    private func editTags() {
        let alert = UIAlertController(title: "Tags", message: "Separate tags with commas, for example: chorus, acoustic, unfinished", preferredStyle: .alert)
        alert.addTextField { $0.text = self.note.tags; $0.placeholder = "Tags" }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            guard self.flush() else { return }; self.note.tags = String((alert.textFields?.first?.text ?? "").prefix(500)); self.dirty = true; self.flush()
        }); present(alert, animated: true)
    }
    @objc private func closeKeyboard() { view.endEditing(true); flush() }
    @objc private func section() {
        let alert = UIAlertController(title: "Add a song section", message: nil, preferredStyle: .actionSheet)
        for name in ["Verse", "Pre-Chorus", "Chorus", "Bridge", "Outro"] {
            alert.addAction(UIAlertAction(title: name, style: .default) { _ in self.text.insertText("\n\n[\(name)]\n"); self.edited() })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel)); alert.popoverPresentationController?.sourceView = text; alert.popoverPresentationController?.sourceRect = CGRect(x: 30, y: 30, width: 1, height: 1)
        present(alert, animated: true)
    }
    private func selectedWord() -> String {
        let ns = (text.text ?? "") as NSString
        let selection = text.selectedRange
        if selection.length > 0, NSMaxRange(selection) <= ns.length { return ns.substring(with: selection).trimmingCharacters(in: .whitespacesAndNewlines) }
        let prefix = ns.substring(to: min(selection.location, ns.length))
        return prefix.components(separatedBy: CharacterSet.letters.inverted).last(where: { !$0.isEmpty }) ?? ""
    }
    @objc private func rhyme() {
        let controller = RhymeController(); controller.initialWord = selectedWord()
        controller.onPick = { [weak self] word in
            guard let self else { return }
            // No selection is overwritten accidentally: insert at the retained caret.
            self.text.insertText(word); self.edited()
        }
        let nav = UINavigationController(rootViewController: controller)
        nav.navigationBar.prefersLargeTitles = true; present(nav, animated: true)
    }
    @objc private func spelling() {
        let body = text.text ?? ""
        let checker = UITextChecker(); let language = UITextChecker.availableLanguages.contains("en_US") ? "en_US" : (UITextChecker.availableLanguages.first ?? "en_US")
        let range = checker.rangeOfMisspelledWord(in: body, range: NSRange(location: 0, length: (body as NSString).length), startingAt: 0, wrap: false, language: language)
        guard range.location != NSNotFound else { message("Spelling checked", "No spelling errors found. Names, slang, and invented words may be intentional."); return }
        text.selectedRange = range; text.scrollRangeToVisible(range)
        let word = (body as NSString).substring(with: range)
        let guesses = checker.guesses(forWordRange: range, in: body, language: language) ?? []
        let alert = UIAlertController(title: "“\(word)”", message: guesses.isEmpty ? "No suggestions. You can edit this word yourself or add it to your dictionary." : "Choose a spelling, or keep your original word.", preferredStyle: .actionSheet)
        for guess in guesses.prefix(7) {
            alert.addAction(UIAlertAction(title: guess, style: .default) { _ in
                guard self.text.text == body else { return }
                self.text.selectedRange = range; self.text.insertText(guess); self.edited()
            })
        }
        alert.addAction(UIAlertAction(title: "Learn this word", style: .default) { _ in UITextChecker.learnWord(word) })
        alert.addAction(UIAlertAction(title: "Keep original", style: .cancel))
        alert.popoverPresentationController?.sourceView = text; alert.popoverPresentationController?.sourceRect = CGRect(x: 30, y: 30, width: 1, height: 1)
        present(alert, animated: true)
    }
}
