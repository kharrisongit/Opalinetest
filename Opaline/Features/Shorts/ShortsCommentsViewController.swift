import UIKit

/// The comments sheet a short opens. A flat top-level list — replies and
/// sorting stay on the watch screen, where there is room for them.
final class ShortsCommentsViewController: UIViewController {
    private let videoId: String
    private let watchService: WatchService
    private let tableView = UITableView()
    private let titleLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .gray)
    private var comments: [Comment] = []
    private var continuation: String?
    private var isLoading = false
    private var loadGeneration = 0
    private let composer = InlineCommentComposer()
    private var keyboard: CommentKeyboardGuide?

    init(videoId: String, watchService: WatchService) {
        self.videoId = videoId
        self.watchService = watchService
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupHeader()
        setupComposer()
        setupTable()
        applyTheme()
        loadNextPage()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        keyboard?.update()
    }

    func loadNextPage() {
        guard !isLoading, comments.isEmpty || continuation != nil else {
            return
        }
        isLoading = true
        spinner.startAnimating()
        let generation = loadGeneration
        watchService.fetchComments(
            videoId: videoId,
            continuation: continuation,
            cancellationToken: nil
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.loadGeneration == generation else {
                    return
                }
                self.handle(result)
            }
        }
    }

    private func handle(_ result: Result<CommentsPage, Error>) {
        isLoading = false
        spinner.stopAnimating()
        guard case .success(let page) = result else {
            AppLog.player("shorts comments failed")
            continuation = nil
            return
        }
        if let title = page.title {
            titleLabel.text = title
        }
        continuation = page.continuation
        comments.append(contentsOf: page.comments)
        tableView.reloadData()
    }

    @objc
    private func closeTapped() {
        dismiss(animated: true)
    }

    private func applyTheme() {
        let theme = ThemeManager.shared
        view.backgroundColor = theme.background
        tableView.backgroundColor = theme.background
        titleLabel.textColor = theme.primaryText
        tableView.separatorColor = theme.separator
        composer.applyTheme()
    }

    private func setupHeader() {
        titleLabel.text = "player.comments.title".localized
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        let close = UIButton(type: .system)
        close.setTitle("common.close".localized, for: .normal)
        close.addTarget(
            self, action: #selector(closeTapped), for: .touchUpInside
        )
        for subview in [titleLabel, close, spinner] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(
                equalTo: guide.leadingAnchor, constant: 16
            ),
            titleLabel.topAnchor.constraint(
                equalTo: guide.topAnchor, constant: 16
            ),
            close.trailingAnchor.constraint(
                equalTo: guide.trailingAnchor, constant: -16
            ),
            close.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func setupTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        tableView.register(CommentCell.self, forCellReuseIdentifier: CommentCell.reuseId)
        view.addSubview(tableView)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(
                equalTo: titleLabel.bottomAnchor, constant: 16
            ),
            tableView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: composer.topAnchor)
        ])
    }
}

// MARK: - Table

extension ShortsCommentsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(
        _ tableView: UITableView, numberOfRowsInSection section: Int
    ) -> Int {
        comments.count
    }

    func tableView(
        _ tableView: UITableView, cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: CommentCell.reuseId, for: indexPath
        )
        let comment = comments[indexPath.row]
        (cell as? CommentCell)?.configure(comment, linkDelegate: self) { [weak self] in
            self?.showComposer(parent: comment)
        }
        return cell
    }

    func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        guard indexPath.row >= comments.count - 3 else {
            return
        }
        loadNextPage()
    }
}

extension ShortsCommentsViewController: UITextViewDelegate {}

extension ShortsCommentsViewController {
    private func setupComposer() {
        composer.configure(videoID: videoId)
        composer.onPosted = { [weak self] comment, target in
            self?.didPost(comment, isReply: target.parentID != nil)
        }
        composer.onConnect = { [weak self] in
            let navigation = RotatingNavigationController(
                rootViewController: CommentAccountViewController()
            )
            navigation.modalPresentationStyle = .formSheet
            self?.present(navigation, animated: true)
        }
        composer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(composer)
        let bottom = composer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        NSLayoutConstraint.activate([
            composer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            composer.trailingAnchor.constraint(equalTo: view.trailingAnchor), bottom
        ])
        keyboard = CommentKeyboardGuide(host: view, bottom: bottom)
    }

    private func showComposer(parent: Comment?) {
        composer.beginReply(to: parent)
    }

    private func didPost(_ comment: Comment, isReply: Bool) {
        loadGeneration += 1
        isLoading = false
        spinner.stopAnimating()
        if !isReply {
            comments.insert(comment, at: 0)
            tableView.reloadData()
            tableView.setContentOffset(.zero, animated: false)
        }
        UIAccessibility.post(
            notification: .announcement, argument: "nativeComments.posted".localized
        )
    }
}
