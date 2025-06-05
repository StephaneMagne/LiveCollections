//
//  CollectionDataActor.swift
//  LiveCollections
//
//  Created by Stephane Magne on 2025-06-05.
//  Copyright © 2025 Scribd. All rights reserved.
//

import UIKit

public final actor CollectionDataActor<Item: UniquelyIdentifiable>: ItemViewProvider {

    // data
    @MainActor
    public private(set) var items: [Item]

    // view
    @MainActor
    private(set) weak var view: DeltaUpdatableViewAsync?

    // controllers
    private let dataCalculator = ItemDataCalculatorActor<Item>()

    // init
    @MainActor
    public init(items: [Item] = [], view: DeltaUpdatableViewAsync? = nil) {
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
    func setView(_ view: DeltaUpdatableViewAsync) {
        guard view !== self.view else { return }
        self.view = view
        reloadData()
    }
}

// MARK: - Update API

public extension CollectionDataActor {

    func update(_ updatedItems: [Item], animated: Bool = true, completion: (() -> Void)? = nil) async {
        await dataCalculator.update(updatedItems,
                                    animated: animated,
                                    itemProvider: self,
                                    viewProvider: self,
                                    completion: completion)
    }
}

// MARK: - Update Private

private extension CollectionDataActor {

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
