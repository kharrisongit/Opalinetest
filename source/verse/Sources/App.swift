import UIKit

let verseTint = UIColor(red: 0.10, green: 0.48, blue: 0.40, alpha: 1)

@main final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.tintColor = verseTint
        let tabs = UITabBarController()
        let library = UINavigationController(rootViewController: LibraryController())
        library.tabBarItem = UITabBarItem(title: "Notebooks", image: UIImage(systemName: "books.vertical"), tag: 0)
        let rhymes = UINavigationController(rootViewController: RhymeController())
        rhymes.tabBarItem = UITabBarItem(title: "Rhyme finder", image: UIImage(systemName: "waveform"), tag: 1)
        let settings = UINavigationController(rootViewController: SettingsController(style: .insetGrouped))
        settings.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gearshape"), tag: 2)
        tabs.viewControllers = [library, rhymes, settings]
        [library, rhymes, settings].forEach { $0.navigationBar.prefersLargeTitles = true }
        window.rootViewController = tabs; self.window = window; window.makeKeyAndVisible()
        _ = VerseStore.shared
        RhymeService.shared.load()
        return true
    }
    func applicationDidBecomeActive(_ application: UIApplication) { VerseStore.shared.sync() }
    func applicationWillResignActive(_ application: UIApplication) { NotificationCenter.default.post(name: Notification.Name("verseFlush"), object: nil) }
}

extension UIViewController {
    func message(_ title: String, _ message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    func share(_ items: [Any], anchor: UIBarButtonItem? = nil) {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.popoverPresentationController?.barButtonItem = anchor ?? navigationItem.rightBarButtonItems?.first
        if controller.popoverPresentationController?.barButtonItem == nil {
            controller.popoverPresentationController?.sourceView = view
            controller.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(controller, animated: true)
    }
}

final class LibraryController: UITableViewController, UISearchResultsUpdating {
    private let store = VerseStore.shared
    private var notes: [Revision] = []
    private var notebook: String?
    private var favorites = false
    private var trash = false
    private let search = UISearchController(searchResultsController: nil)
    private var observer: NSObjectProtocol?
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Verse"
        tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.rowHeight = UITableView.automaticDimension; tableView.estimatedRowHeight = 110
        search.searchResultsUpdater = self; search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "Search lyrics, titles, tags"
        navigationItem.searchController = search; navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "square.and.pencil"), style: .plain, target: self, action: #selector(newNote))
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "sidebar.left"), style: .plain, target: self, action: #selector(filterNotes))
        navigationItem.rightBarButtonItem?.accessibilityLabel = "New lyric"
        navigationItem.leftBarButtonItem?.accessibilityLabel = "Choose notebook"
        refreshControl = UIRefreshControl(); refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
        observer = NotificationCenter.default.addObserver(forName: .verseChanged, object: nil, queue: .main) { [weak self] _ in self?.reload() }
        reload()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !UserDefaults.standard.bool(forKey: "welcomed") && !ProcessInfo.processInfo.arguments.contains("--smoke-test") {
            UserDefaults.standard.set(true, forKey: "welcomed")
            message("A home for your next song", "Create a lyric with the compose button. Use Notebooks to organize songs and ideas. Select a word in the editor, then tap Rhyme. Connect an iCloud Drive folder in Settings to sync across devices.")
        } else if let error = store.loadError { message("Storage needs attention", error) }
    }
    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    @objc private func refresh() { store.sync(); reload(); refreshControl?.endRefreshing() }
    func updateSearchResults(for searchController: UISearchController) { reload() }
    private func reload() {
        let q = search.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        notes = store.heads.filter { note in
            note.deleted == trash && (notebook == nil || note.notebook == notebook) && (!favorites || note.favorite) &&
            (q.isEmpty || [note.title, note.body, note.tags, note.notebook].contains { $0.localizedCaseInsensitiveContains(q) })
        }
        title = trash ? "Recently deleted" : (favorites ? "Favorites" : notebook ?? "Verse")
        tableView.reloadData()
        if notes.isEmpty {
            let label = UILabel(); label.numberOfLines = 0; label.textAlignment = .center
            label.font = .preferredFont(forTextStyle: .body); label.textColor = .secondaryLabel
            label.text = q.isEmpty ? "Every song starts with a line.\n\nTap the compose button to begin." : "No lyrics found.\nTry another word."
            tableView.backgroundView = label
        } else { tableView.backgroundView = nil }
    }
    @objc private func filterNotes() {
        let alert = UIAlertController(title: "Your notebooks", message: nil, preferredStyle: .actionSheet)
        func add(_ title: String, _ action: @escaping () -> Void) { alert.addAction(UIAlertAction(title: title, style: .default) { _ in action(); self.reload() }) }
        add("All lyrics") { self.notebook = nil; self.favorites = false; self.trash = false }
        add("Favorites") { self.notebook = nil; self.favorites = true; self.trash = false }
        for book in store.notebooks { add(book) { self.notebook = book; self.favorites = false; self.trash = false } }
        add("New notebook…") { self.createNotebook() }
        add("Recently deleted") { self.notebook = nil; self.favorites = false; self.trash = true }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.popoverPresentationController?.barButtonItem = navigationItem.leftBarButtonItem
        present(alert, animated: true)
    }
    private func createNotebook() {
        let alert = UIAlertController(title: "New notebook", message: "Give this collection of lyrics a name.", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Album, project, or idea"; $0.autocapitalizationType = .words }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Create", style: .default) { _ in
            let name = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else { return }
            self.notebook = String(name.prefix(100)); self.newNote()
        })
        present(alert, animated: true)
    }
    @objc private func newNote() {
        let note = Revision(notebook: notebook ?? "Lyrics")
        do { try store.save(note); open(note) } catch { message("Couldn’t save", error.localizedDescription) }
    }
    private func open(_ note: Revision) { navigationController?.pushViewController(EditorController(note: note), animated: true) }
    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { notes.count }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { "\(notes.count) \(notes.count == 1 ? "lyric" : "lyrics")" }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? { store.syncStatus }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        let note = notes[indexPath.row]
        let conflicts = store.heads.filter { $0.noteID == note.noteID && !$0.deleted }.count > 1
        var content = cell.defaultContentConfiguration()
        content.text = (note.favorite ? "★  " : "") + note.displayTitle
        content.textProperties.font = .preferredFont(forTextStyle: .headline)
        let preview = note.body.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: "  ")
        content.secondaryText = "\(note.notebook) · \(note.modified.formatted(date: .abbreviated, time: .omitted))\(conflicts ? " · Parallel draft" : "")\n\(preview.isEmpty ? "A blank page, a little possibility." : String(preview.prefix(130)))"
        content.secondaryTextProperties.numberOfLines = 3; content.secondaryTextProperties.color = .secondaryLabel
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        cell.contentConfiguration = content; cell.accessoryType = .disclosureIndicator
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let note = notes[indexPath.row]
        if trash {
            let alert = UIAlertController(title: "Restore lyric?", message: note.displayTitle, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Restore", style: .default) { _ in
                var next = note.edited(); next.deleted = false
                do { try self.store.save(next) } catch { self.message("Couldn’t restore", error.localizedDescription) }
            }); present(alert, animated: true)
        } else { open(note) }
    }
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard !trash else { return nil }
        let note = notes[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Trash") { _, _, done in
            var next = note.edited(); next.deleted = true
            do { try self.store.save(next); done(true) } catch { self.message("Couldn’t delete", error.localizedDescription); done(false) }
        }
        let favorite = UIContextualAction(style: .normal, title: note.favorite ? "Unfavorite" : "Favorite") { _, _, done in
            var next = note.edited(); next.favorite.toggle()
            do { try self.store.save(next); done(true) } catch { self.message("Couldn’t save", error.localizedDescription); done(false) }
        }
        favorite.backgroundColor = verseTint
        return UISwipeActionsConfiguration(actions: [delete, favorite])
    }
}
