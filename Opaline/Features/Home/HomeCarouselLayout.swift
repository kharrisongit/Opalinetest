import UIKit

final class HomeCarouselLayout: UICollectionViewFlowLayout {
    override func prepare() {
        guard let view = collectionView else {
            return
        }
        scrollDirection = .horizontal
        let width = min(560, view.bounds.width * 0.76)
        let available = view.bounds.height - view.adjustedContentInset.top
            - view.adjustedContentInset.bottom
        let height = max(1, available - 28)
        itemSize = CGSize(width: width, height: height)
        minimumLineSpacing = 14
        let side = max(0, (view.bounds.width - width) / 2)
        sectionInset = UIEdgeInsets(top: 12, left: side, bottom: 12, right: side)
        super.prepare()
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool { true }

    override func layoutAttributesForElements(
        in rect: CGRect
    ) -> [UICollectionViewLayoutAttributes]? {
        let items = super.layoutAttributesForElements(in: rect)?.compactMap {
            $0.copy() as? UICollectionViewLayoutAttributes
        }
        guard let view = collectionView, !UIAccessibility.isReduceMotionEnabled else {
            return items
        }
        for item in items ?? [] {
            let stride = max(1, itemSize.width + minimumLineSpacing)
            let offset = (item.center.x - view.bounds.midX) / stride
            let distance = min(1, abs(offset))
            var transform = CATransform3DIdentity
            transform.m34 = -1 / 900
            transform = CATransform3DRotate(transform, -offset * 0.12, 0, 1, 0)
            let scale = 1 - distance * 0.12
            item.transform3D = CATransform3DScale(transform, scale, scale, 1)
            item.alpha = 1 - distance * 0.25
            item.zIndex = Int((1 - distance) * 100)
        }
        return items
    }

    override func targetContentOffset(
        forProposedContentOffset proposedContentOffset: CGPoint,
        withScrollingVelocity velocity: CGPoint
    ) -> CGPoint {
        guard let view = collectionView else {
            return proposedContentOffset
        }
        let stride = itemSize.width + minimumLineSpacing
        let count = view.numberOfItems(inSection: 0)
        let proposed = round(proposedContentOffset.x / max(1, stride))
        let index = min(max(0, proposed), CGFloat(max(0, count - 1)))
        return CGPoint(x: index * stride, y: -view.adjustedContentInset.top)
    }
}
