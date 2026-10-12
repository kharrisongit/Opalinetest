import AVFoundation
import UIKit

final class HomeExplorerView: UIView {
    let mode: HomeLayout
    let collection: UICollectionView
    let hint = UILabel()
    let preview = HomeCarouselPreview()
    var videos: [Video] = []
    var hasMore = false
    var onPlay: ((Video) -> Void)?
    var onMore: (() -> Void)?
    var onRefresh: (() -> Void)?
    var canPreview: (() -> Bool)?
    var previewWork: DispatchWorkItem?
    var previewTimer: Timer?
    var interrupted = false
    var scrolling = false

    var isAtStart: Bool {
        mode == .wall ? collection.contentOffset.y <= 1 : collection.contentOffset.x <= 1
    }
    var didCenterWall = false

    var previewAllowed: Bool {
        HomePreviewPolicy.allows(
            visible: mode == .carousel && window != nil && canPreview?() == true,
            active: UIApplication.shared.applicationState == .active && !interrupted,
            mainPlayerInUse: VideoRouter.shared.currentVideo != nil,
            airPlay: BackgroundPlaybackService.isAirPlayActive(player: nil)
        ) && !scrolling && !collection.isDragging && !collection.isDecelerating
    }

    init(mode: HomeLayout) {
        self.mode = mode
        collection = UICollectionView(
            frame: .zero,
            collectionViewLayout: mode == .wall ? HomeWallLayout() : HomeCarouselLayout()
        )
        super.init(frame: .zero)
        setupCollection()
        setupHeader()
        observeChanges()
        preview.stillAllowed = { [weak self] in self?.previewAllowed == true }
        preview.onStatus = { [weak self] status in self?.centerCell?.previewStatus.text = status }
        applyTheme()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        previewTimer?.invalidate()
        guard window != nil, mode == .carousel else {
            stopPreview()
            return
        }
        previewTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.checkPreview()
        }
        schedulePreview()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        collection.collectionViewLayout.invalidateLayout()
        if mode == .wall, !didCenterWall, !videos.isEmpty, collection.bounds.width > 0 {
            collection.layoutIfNeeded()
            scrollToStart()
            didCenterWall = true
        }
    }

    func update(videos newVideos: [Video], hasMore: Bool) {
        collection.refreshControl?.endRefreshing()
        self.hasMore = hasMore
        guard videos.map(\.id) != newVideos.map(\.id) else {
            return
        }
        stopPreview()
        let oldCount = videos.count
        let append = oldCount > 0 && newVideos.prefix(oldCount).map(\.id) == videos.map(\.id)
        if append {
            collection.performBatchUpdates {
                videos = newVideos
                let additions = (oldCount..<newVideos.count).map { IndexPath(item: $0, section: 0) }
                collection.insertItems(at: additions)
            }
        } else {
            videos = newVideos
            collection.reloadData()
            didCenterWall = false
            scrollToStart()
        }
        setNeedsLayout()
        schedulePreview()
    }

    func scrollToStart() {
        scrolling = false
        stopPreview()
        collection.layoutIfNeeded()
        let center = max(0, (collection.contentSize.width - collection.bounds.width) / 2)
        let x = mode == .wall ? center : 0
        collection.setContentOffset(
            CGPoint(x: x, y: -collection.adjustedContentInset.top),
            animated: false
        )
        schedulePreview()
    }

    @objc
    func refresh() { stopPreview(); onRefresh?() }

    @objc
    func applyTheme() {
        backgroundColor = ThemeManager.shared.background
        collection.backgroundColor = backgroundColor
        hint.textColor = ThemeManager.shared.secondaryText
        stopPreview()
        collection.reloadData()
        schedulePreview()
    }

    private func setupCollection() {
        collection.register(
            HomeExplorerCell.self, forCellWithReuseIdentifier: HomeExplorerCell.reuseID
        )
        collection.dataSource = self
        collection.delegate = self
        collection.decelerationRate = mode == .carousel ? .fast : .normal
        collection.alwaysBounceVertical = mode == .wall
        collection.showsHorizontalScrollIndicator = false
        collection.translatesAutoresizingMaskIntoConstraints = false
        addSubview(collection)
        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(Self.refresh), for: .valueChanged)
        collection.refreshControl = refresh
        if mode == .wall {
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:)))
            collection.addGestureRecognizer(pinch)
        }
    }

    private func setupHeader() {
        let key = mode == .wall ? "home.explorer.wallHint" : "home.explorer.carouselHint"
        hint.text = key.localized
        hint.font = .systemFont(ofSize: 12)
        hint.numberOfLines = 2
        let refresh = UIButton(type: .system)
        refresh.setTitle("home.explorer.refresh".localized, for: .normal)
        refresh.addTarget(self, action: #selector(Self.refresh), for: .touchUpInside)
        refresh.setContentHuggingPriority(.required, for: .horizontal)
        let header = UIStackView(arrangedSubviews: [hint, refresh])
        header.spacing = 12
        header.alignment = .center
        header.translatesAutoresizingMaskIntoConstraints = false
        addSubview(header)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            header.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            header.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
            collection.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4),
            collection.leadingAnchor.constraint(equalTo: leadingAnchor),
            collection.trailingAnchor.constraint(equalTo: trailingAnchor),
            collection.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    deinit { previewTimer?.invalidate(); previewWork?.cancel() }
}
