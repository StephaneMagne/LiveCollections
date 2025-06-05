//
//  CollectionDataActor.swift
//  LiveCollections
//
//  Created by Stephane Magne on 2025-06-05.
//  Copyright © 2025 Scribd. All rights reserved.
//

import UIKit

public final actor CollectionDataActor<Item: UniquelyIdentifiable> {

    // data
    @MainActor
    public private(set) var items: [Item]

    // view
    @MainActor
    private weak var view: DeltaUpdatableView?

    // controllers
    private let dataCalculator = ItemDataCalculator<Item>()

    // init
    @MainActor
    public init(items: [Item] = [], view: DeltaUpdatableView? = nil) {
        self.items = items

        if let view {
            setView(view)
            reloadData()
        }
    }
}

// MARK: - State API

public extension CollectionDataActor {

    @MainActor
    func count() -> Int {
        return items.count
    }

    @MainActor
    func isEmpty() -> Bool {
        return items.isEmpty
    }
}

// MARK: - Set Up API

public extension CollectionDataActor {

    @MainActor
    func setView(_ view: DeltaUpdatableView) {
        guard view !== self.view else { return }
        self.view = view
        reloadData()
    }
}

// MARK: - Update API

public extension CollectionDataActor {

    func update(_ updatedItems: [Item], animated: Bool = true) async {
        if animated {
            await updateAnimated(updatedItems)
        } else {
            await updateNonAnimated(updatedItems)
        }
    }
}

// MARK: - Update Private

private extension CollectionDataActor {

    func updateAnimated(_ updatedItems: [Item]) async {
        
    }

    @MainActor
    func updateNonAnimated(_ updatedItems: [Item]) async {
        self.items = updatedItems
        reloadData()
    }

    @MainActor
    func reloadData() {
        self.view?.reloadData()
    }
}

// MARK: - ItemDataActorProvider

extension CollectionDataActor: ItemDataActorProvider {

    @MainActor
    func setItems(_ items: [Item]) {
        self.items = items
    }
}
