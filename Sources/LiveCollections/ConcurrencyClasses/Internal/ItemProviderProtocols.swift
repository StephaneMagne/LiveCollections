//
//  ItemProviderProtocols.swift
//  LiveCollections
//
//  Created by Stephane Magne on 2025-06-05.
//  Copyright © 2025 Scribd. All rights reserved.
//

import Foundation

protocol ItemDataActorProvider<Item>: AnyObject {
    associatedtype Item: UniquelyIdentifiable

    @MainActor
    var items: [Item] { get }

    @MainActor
    func setItems(_ items: [Item])
}

protocol ItemViewProvider: AnyObject {
    @MainActor
    var view: DeltaUpdatableViewAsync? { get }
}

@MainActor
public protocol DeltaUpdatableViewAsync: AnyObject {

    /// Basic view frame getter
    var frame: CGRect { get }

    /// Basic reloadData function
    func reloadData()

    func performAnimationsAsync(section: Int,
                                delta: IndexDelta,
                                updateData: @escaping @MainActor () -> Void,
                                completion: (@MainActor () -> Void)?) async
}

