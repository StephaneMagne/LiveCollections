//
//  UIKit+AsyncDeltaUpdates.swift
//  LiveCollections
//
//  Created by Stephane Magne on 2025-06-05.
//  Copyright © 2025 Scribd. All rights reserved.
//

import UIKit

// MARK: - Update Collection View

@MainActor
extension UICollectionView: DeltaUpdatableViewAsync {

    public func performAnimationsAsync(section: Int,
                                       delta: IndexDelta,
                                       updateData: @escaping @MainActor () -> Void,
                                       completion: (@MainActor () -> Void)?) {

        guard delta.hasChanges, isViewVisibleOnScreen else {
            updateData()
            completion?()
            if delta.hasChanges {
                reloadData()
            }
            return
        }
    }

    public func performAnimationsAsync(for sectionUpdate: SectionUpdate) {

        let indexDelta = IndexPathsToAnimate.build(for: sectionUpdate)

        performBatchUpdates { [weak self] in
            guard let self else { return }
            sectionUpdate.update()
            self.deleteItems(at: indexDelta.deletedIndexPaths)
            indexDelta.movedIndexPathPairs.forEach {
                self.moveItem(at: $0.source, to: $0.target)
            }
            self.insertItems(at: indexDelta.insertedIndexPaths)
        } completion: { [weak self] _ in
            guard let self else { return }
            self.performBatchUpdates {
                self.reloadItems(at: indexDelta.automaticReloadIndexPaths)
            } completion: { _ in
                sectionUpdate.completion?()
            }
        }
    }
}

// MARK: UIView + Visibility

private extension UIView {

    var isViewVisibleOnScreen: Bool {
        return window != nil && frame != .zero
    }
}



