import UIKit

extension HomeExplorerView: UICollectionViewDataSource, UICollectionViewDelegate {
    var centerIndex: Int? {
        let point = CGPoint(x: collection.bounds.midX, y: collection.bounds.midY)
        return collection.indexPathsForVisibleItems.min {
            let first = collection.layoutAttributesForItem(at: $0)?.center ?? .zero
            let second = collection.layoutAttributesForItem(at: $1)?.center ?? .zero
            let firstDistance = hypot(first.x - point.x, first.y - point.y)
            return firstDistance < hypot(second.x - point.x, second.y - point.y)
        }?.item
    }

    var centerCell: HomeExplorerCell? {
        centerIndex.flatMap {
            collection.cellForItem(at: IndexPath(item: $0, section: 0)) as? HomeExplorerCell
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        videos.count
    }

    func collectionView(
        _ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: HomeExplorerCell.reuseID, for: indexPath
        )
        let video = videos[indexPath.item]
        (cell as? HomeExplorerCell)?.configure(video, carousel: mode == .carousel) { [weak self] in
            self?.stopPreview()
            self?.onPlay?(video)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if mode == .wall {
            onPlay?(videos[indexPath.item])
        } else {
            stopPreview()
            scrolling = true
            collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
            // UIKit does not send the animation callback when already centered.
            if indexPath.item == centerIndex { scrolling = false; schedulePreview() }
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        if hasMore, indexPath.item >= videos.count - 14 { onMore?() }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrolling = false
        stopPreview()
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { schedulePreview() }
    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrolling = false
        schedulePreview()
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didEndDisplaying cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        if let cell = cell as? HomeExplorerCell, preview.superview === cell.previewHost {
            stopPreview()
        }
    }
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { schedulePreview() }
    }

    @objc
    func pinch(_ gesture: UIPinchGestureRecognizer) {
        guard let layout = collection.collectionViewLayout as? HomeWallLayout else {
            return
        }
        let point = gesture.location(in: collection)
        let previous = layout.zoom
        layout.zoom = min(1.8, max(0.65, previous * gesture.scale))
        gesture.scale = 1
        let ratio = layout.zoom / previous
        let relative = CGPoint(
            x: point.x - collection.contentOffset.x,
            y: point.y - collection.contentOffset.y
        )
        layout.invalidateLayout()
        collection.layoutIfNeeded()
        let size = collection.contentSize
        collection.contentOffset = CGPoint(
            x: min(
                max(0, point.x * ratio - relative.x),
                max(0, size.width - collection.bounds.width)
            ),
            y: min(
                max(0, point.y * ratio - relative.y),
                max(0, size.height - collection.bounds.height)
            )
        )
    }
}
