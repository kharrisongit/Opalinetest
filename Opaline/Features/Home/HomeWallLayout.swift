import UIKit

/// A staggered, two-dimensional thumbnail canvas. Only visible rows get attributes.
final class HomeWallLayout: UICollectionViewLayout {
    var zoom: CGFloat = 1
    private var columns = 7
    private var tile = CGSize(width: 124, height: 84)
    private var contentSize = CGSize.zero
    private let gap: CGFloat = 8

    override var collectionViewContentSize: CGSize { contentSize }

    override func prepare() {
        super.prepare()
        guard let view = collectionView else {
            return
        }
        let base = min(168, max(112, view.bounds.width / 3.2))
        tile = CGSize(width: base * zoom, height: base * zoom * 0.72)
        let count = view.numberOfItems(inSection: 0)
        columns = min(7, max(1, count))
        let rows = Int(ceil(Double(count) / Double(columns)))
        contentSize = CGSize(
            width: max(
                view.bounds.width,
                CGFloat(columns) * (tile.width + gap) + tile.width / 2 + gap
            ),
            height: max(view.bounds.height + 1, CGFloat(rows) * (tile.height + gap) + gap)
        )
    }

    override func layoutAttributesForItem(
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        let row = indexPath.item / columns
        let column = indexPath.item % columns
        let shift = row.isMultiple(of: 2) ? CGFloat.zero : (tile.width + gap) / 2
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.frame = CGRect(
            x: gap + CGFloat(column) * (tile.width + gap) + shift,
            y: gap + CGFloat(row) * (tile.height + gap),
            width: tile.width,
            height: tile.height
        )
        applyFocus(attributes)
        return attributes
    }

    override func layoutAttributesForElements(
        in rect: CGRect
    ) -> [UICollectionViewLayoutAttributes]? {
        guard let view = collectionView else {
            return []
        }
        let count = view.numberOfItems(inSection: 0)
        let first = max(0, Int(rect.minY / (tile.height + gap)) - 1) * columns
        let last = min(count, (Int(rect.maxY / (tile.height + gap)) + 2) * columns)
        guard first < last else {
            return []
        }
        let attributes = (first..<last).compactMap {
            layoutAttributesForItem(at: IndexPath(item: $0, section: 0))
        }
        return attributes.filter { $0.frame.intersects(rect) }
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool { true }

    private func applyFocus(_ attributes: UICollectionViewLayoutAttributes) {
        guard !UIAccessibility.isReduceMotionEnabled, let view = collectionView else {
            return
        }
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        let distance = hypot(attributes.center.x - center.x, attributes.center.y - center.y)
        let radius = max(view.bounds.width, view.bounds.height) * 0.65
        let scale = 1 - min(1, distance / max(1, radius)) * 0.14
        attributes.transform = CGAffineTransform(scaleX: scale, y: scale)
    }
}
