//
//  ItemDataCalculatorActor.swift
//  LiveCollections
//
//  Created by Stephane Magne on 2025-06-05.
//  Copyright © 2025 Scribd. All rights reserved.
//

final actor ItemDataCalculatorActor<Item: UniquelyIdentifiable> {

    private let itemProcessingQueue = ItemProcessingQueue<Item>()

    func update(_ updatedItems: [Item],
                animated: Bool,
                itemProvider: some ItemDataActorProvider<Item>,
                viewProvider: ItemViewProvider,
                completion: (() -> Void)?) async {
        if let (itemsToProcess, animateItems, itemCompletion) = await itemProcessingQueue.processNext(updatedItems, animated: animated, completion: completion) {
            await processItems(itemsToProcess,
                               animated: animateItems,
                               itemProvider: itemProvider,
                               viewProvider: viewProvider,
                               completion: itemCompletion)
        }
    }
}

// MARK: Update

private extension ItemDataCalculatorActor {

    func processItems(_ updatedItems: [Item],
                      animated: Bool,
                      itemProvider: some ItemDataActorProvider<Item>,
                      viewProvider: ItemViewProvider,
                      completion: (() -> Void)?) async {

        guard let view = await viewProvider.view else {
            await itemProvider.setItems(updatedItems)
            return
        }

        let updateData: @MainActor () -> Void = { [weak itemProvider, weak viewProvider] in
            guard let itemProvider, let viewProvider else { return }

            itemProvider.setItems(updatedItems)

            let currentView = viewProvider.view

            Task { @MainActor in
                if view !== currentView {
                    currentView?.reloadData()
                }
            }
        }

        let (delta, deletedItems) = await calculateDelta(updatedItems, itemProvider: itemProvider)

        let calculationCompletion: () -> Void = { [weak self] in
            completion?()
            if deletedItems.isEmpty == false {
                // send deleted items here
            }
            Task {
                await self?.processNext(itemProvider: itemProvider, viewProvider: viewProvider)
            }
        }

        guard delta.hasChanges else {
            await updateData()
            calculationCompletion()
            return
        }

        await view.performAnimationsAsync(section: 0, delta: delta, updateData: updateData, completion: completion)
    }

    func calculateDelta(_ updatedItems: [Item],
                        itemProvider: some ItemDataActorProvider<Item>) async -> (delta: IndexDelta, deletedItems: [Item]) {

        let items = await itemProvider.items
        let deltaCalculator = DeltaCalculator<Item>(startingData: items, updatedData: updatedItems)
        let (delta, deletedItems) = deltaCalculator.calculateItemDelta()
        return (delta: delta, deletedItems: deletedItems)
    }

    func processNext(itemProvider: some ItemDataActorProvider<Item>,
                     viewProvider: ItemViewProvider) async {
        if let (itemsToProcess, animateItems, completion) = await itemProcessingQueue.processNext() {
            await processItems(itemsToProcess,
                               animated: animateItems,
                               itemProvider: itemProvider,
                               viewProvider: viewProvider,
                               completion: completion)
        }
    }
}

// MARK: - Processing Queue

private final actor ItemProcessingQueue<Item> {

    private var currentlyProcessing: [Item]?

    private var waitingToProcess: (items: [Item], animated: Bool, completion: (() -> Void)?)?

    func processNext(_ items: [Item]? = nil,
                     animated: Bool? = nil,
                     completion: (() -> Void)? = nil) -> (items: [Item], animated: Bool, completion: (() -> Void)?)? {
        if let items {
            return processOrEnqueue(items, animated: animated ?? true, completion: completion)
        } else {
            return dequeueWaiting()
        }
    }

    private func processOrEnqueue(_ items: [Item],
                                  animated: Bool,
                                  completion: (() -> Void)?) -> (items: [Item], animated: Bool, completion: (() -> Void)?)? {
        if currentlyProcessing == nil {
            currentlyProcessing = items
            return (items, animated, completion)
        } else {
            waitingToProcess = (items, animated, completion)
            return nil
        }
    }

    private func dequeueWaiting() -> (items: [Item], animated: Bool, completion: (() -> Void)?)? {
        let next = waitingToProcess
        currentlyProcessing = waitingToProcess?.items
        waitingToProcess = nil
        return next
    }
}
