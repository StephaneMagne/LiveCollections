//
//  ItemDataCalculatorActor.swift
//  LiveCollections
//
//  Created by Stephane Magne on 2025-06-05.
//  Copyright © 2025 Scribd. All rights reserved.
//

final actor ItemDataProcessor<Item: UniquelyIdentifiable> {

    private let queue = ItemQueue<Item>()

    private let calculator = ItemDataCalculatorActor<Item>()

    func enqueueUpdate(_ updatedItems: [Item],
                       animated: Bool,
                       itemProvider: some ItemDataActorProvider<Item>,
                       viewProvider: ItemViewProvider,
                       completion: (() -> Void)?) async {
        if let (itemsToProcess, animateItems, itemCompletion) = await queue.processNext(updatedItems, animated: animated, completion: completion) {
            await calculator.processItems(itemsToProcess,
                                          animated: animateItems,
                                          on: queue,
                                          itemProvider: itemProvider,
                                          viewProvider: viewProvider,
                                          completion: itemCompletion)
        }
    }
}

// MARK: Update

private final class ItemDataCalculatorActor<Item: UniquelyIdentifiable> {

    func processItems(_ updatedItems: [Item],
                      animated: Bool,
                      on queue: ItemQueue<Item>,
                      itemProvider: some ItemDataActorProvider<Item>,
                      viewProvider: ItemViewProvider,
                      completion: (() -> Void)?) async {

        let processCompletion: @MainActor () -> Void = { [weak self] in
            completion?()
            Task {
                await self?.processNext(on: queue, itemProvider: itemProvider, viewProvider: viewProvider)
            }
        }

        guard let view = await viewProvider.view else {
            await itemProvider.setItems(updatedItems)
            await processCompletion()
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

        guard animated else {
            await updateData()
            await MainActor.run {
                view.reloadData()
                processCompletion()
            }
            return
        }

        let (delta, deletedItems) = await calculateDelta(updatedItems, itemProvider: itemProvider)

        let calculationCompletion: @MainActor () -> Void = {
            if deletedItems.isEmpty == false {
                // send deleted items here
            }
            processCompletion()
        }

        guard delta.hasChanges else {
            await updateData()
            await calculationCompletion()
            return
        }

        await view.performAnimationsAsync(section: 0, delta: delta, updateData: updateData, completion: calculationCompletion)
    }

    func calculateDelta(_ updatedItems: [Item],
                        itemProvider: some ItemDataActorProvider<Item>) async -> (delta: IndexDelta, deletedItems: [Item]) {

        let items = await itemProvider.items
        let deltaCalculator = DeltaCalculator<Item>(startingData: items, updatedData: updatedItems)
        let (delta, deletedItems) = deltaCalculator.calculateItemDelta()
        return (delta: delta, deletedItems: deletedItems)
    }

    func processNext(on queue: ItemQueue<Item>,
                     itemProvider: some ItemDataActorProvider<Item>,
                     viewProvider: ItemViewProvider) async {
        if let (itemsToProcess, animateItems, completion) = await queue.processNext() {
            await processItems(itemsToProcess,
                               animated: animateItems,
                               on: queue,
                               itemProvider: itemProvider,
                               viewProvider: viewProvider,
                               completion: completion)
        }
    }
}

// MARK: - Processing Queue

private final actor ItemQueue<Item> {

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
