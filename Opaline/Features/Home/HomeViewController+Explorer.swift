import UIKit

extension HomeViewController {
    func applyExplorerLayout() {
        explorer?.stopPreview()
        explorer?.removeFromSuperview()
        explorer = nil
        let mode = HomeLayout.selected
        let custom = mode == .wall || mode == .carousel
        collectionView?.isHidden = custom
        topBarHider.showBars()
        guard custom else {
            return
        }
        let browser = HomeExplorerView(mode: mode)
        explorer = browser
        browser.onPlay = { [weak self] video in
            // Carousel Play explicitly opens the standard watch player, including for Shorts.
            self?.explorer?.stopPreview()
            var standard = video
            standard.isShort = false
            self?.openVideo(standard)
        }
        browser.onMore = { [weak self] in self?.loadMoreForExplorer() }
        browser.onRefresh = { [weak self] in self?.handleRefresh() }
        browser.canPreview = { [weak self] in
            guard let self else {
                return false
            }
            return self.explorerVisible && self.presentedViewController == nil
                && self.navigationController?.presentedViewController == nil
        }
        installExplorer(browser)
        updateExplorerFeed()
    }

    private func installExplorer(_ browser: HomeExplorerView) {
        browser.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(browser, at: 1)
        NSLayoutConstraint.activate([
            browser.topAnchor.constraint(equalTo: chipBar.bottomAnchor),
            browser.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            browser.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            browser.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    func updateExplorerFeed() {
        explorer?.update(videos: sections.flatMap(\.videos), hasMore: currentContinuation != nil)
    }

    private func loadMoreForExplorer() {
        guard !isLoadingInitial, !isLoadingMore, currentContinuation != nil else {
            return
        }
        isLoadingMore = true
        handleLoadMore()
    }
}
