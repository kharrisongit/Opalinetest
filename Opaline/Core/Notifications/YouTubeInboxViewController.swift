import UIKit

final class YouTubeInboxViewController: UITableViewController {
    let filter = UISegmentedControl(items: [
        "youtubeInbox.all".localized, "youtubeInbox.replies".localized
    ])
    let statusLabel = UILabel()
    let moreButton = UIButton(type: .system)
    var inboxItems: [YouTubeNotification] = []
    var items: [YouTubeNotification] {
        kind == .replies ? inboxItems.filter(\.isComment) : inboxItems
    }
    var continuation: YouTubeInboxContinuation?
    var usedContinuations = Set<YouTubeInboxContinuation>()
    var emptyPages = 0
    var loading = false
    var requestGeneration = 0
    let profileAvatar = ThumbnailImageView(frame: .zero)
    let profileName = UILabel()
    var kind: YouTubeInboxKind { filter.selectedSegmentIndex == 1 ? .replies : .all }

    static func present(from presenter: UIViewController) {
        let navigation = RotatingNavigationController(
            rootViewController: YouTubeInboxViewController()
        )
        navigation.modalPresentationStyle = .pageSheet
        presenter.present(navigation, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "youtubeInbox.title".localized
        filter.selectedSegmentIndex = 0
        filter.addTarget(self, action: #selector(changeFilter), for: .valueChanged)
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "youtubeInbox.account".localized,
            style: .plain,
            target: self,
            action: #selector(openAccount)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "common.done".localized,
            style: .done,
            target: self,
            action: #selector(close)
        )
        setupTable()
        setupProfileHeader()
        observeChanges()
        applyTheme()
        reloadInbox()
    }

    private func setupTable() {
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 140
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .interactive
        tableView.register(
            YouTubeNotificationCell.self, forCellReuseIdentifier: YouTubeNotificationCell.reuseID
        )
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(reloadInbox), for: .valueChanged)
        refreshControl = refresh
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.font = .preferredFont(forTextStyle: .body)
        moreButton.frame.size.height = 52
        moreButton.addTarget(self, action: #selector(loadMore), for: .touchUpInside)
        moreButton.setTitle("youtubeInbox.more".localized, for: .normal)
        tableView.tableFooterView = moreButton
    }

    private func observeChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadInbox),
            name: YouTubeCommentClient.didChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyTheme),
            name: ThemeManager.didChangeNotification,
            object: nil
        )
    }

    @objc
    func applyTheme() {
        let theme = ThemeManager.shared
        tableView.backgroundColor = theme.background
        tableView.separatorColor = theme.separator
        statusLabel.textColor = theme.secondaryText
        moreButton.tintColor = theme.accent
        updateProfile()
        tableView.reloadData()
    }

    @objc
    private func reloadInbox() {
        updateProfile()
        YouTubeCommentClient.shared.refreshProfile { [weak self] _ in self?.updateProfile() }
        requestGeneration += 1
        loading = false
        emptyPages = 0
        inboxItems = []
        continuation = nil
        usedContinuations = []
        tableView.reloadData()
        guard YouTubeCommentClient.shared.channel != nil else {
            showStatus("youtubeInbox.signIn".localized)
            refreshControl?.endRefreshing()
            return
        }
        fetch(continuation: nil)
    }

    @objc
    private func loadMore() {
        guard let continuation else {
            reloadInbox()
            return
        }
        fetch(continuation: continuation)
    }

    private func fetch(continuation token: YouTubeInboxContinuation?) {
        guard !loading else {
            return
        }
        loading = true
        moreButton.isEnabled = false
        if items.isEmpty {
            showStatus("youtubeInbox.loading".localized)
        }
        let expected = requestGeneration
        let body = (token?.kind ?? kind).body(continuation: token?.token)
        YouTubeCommentClient.shared.readNotifications(body: body) { [weak self] result in
            guard let self, self.requestGeneration == expected else {
                return
            }
            self.loading = false
            self.refreshControl?.endRefreshing()
            self.moreButton.isEnabled = true
            let page = result.flatMap { json in Result { try YouTubeNotificationModel.page(json) } }
            self.finish(page, token: token)
        }
    }

    private func finish(
        _ result: Result<YouTubeNotificationPage, Error>, token: YouTubeInboxContinuation?
    ) {
        switch result {
        case .success(let page):
            if let token { usedContinuations.insert(token) }
            let existing = Set(inboxItems.map(\.id))
            inboxItems.append(contentsOf: page.items.filter { !existing.contains($0.id) })
            continuation = page.continuation.flatMap { usedContinuations.contains($0) ? nil : $0 }
            YouTubeInboxService.shared.openedInbox()
            changeFilter()
        case .failure:
            let message = "youtubeInbox.error.load".localized
            if items.isEmpty { showStatus(message) } else { ToastView.show(message, in: view) }
            moreButton.setTitle("youtubeInbox.retry".localized, for: .normal)
            moreButton.isHidden = false
        }
    }

    @objc
    private func changeFilter() {
        tableView.backgroundView = items.isEmpty ? statusLabel : nil
        statusLabel.text = (loading ? "youtubeInbox.loading" : "youtubeInbox.empty").localized
        moreButton.setTitle("youtubeInbox.more".localized, for: .normal)
        moreButton.isHidden = continuation == nil
        tableView.reloadData()
        if items.isEmpty, let continuation, !loading, emptyPages < 3 {
            emptyPages += 1
            fetch(continuation: continuation)
        }
    }

    private func showStatus(_ text: String) {
        statusLabel.text = text
        tableView.backgroundView = statusLabel
        moreButton.isHidden = true
    }

    @objc
    func openAccount() {
        navigationController?.pushViewController(CommentAccountViewController(), animated: true)
    }

    @objc
    private func close() {
        dismiss(animated: true)
    }
}
