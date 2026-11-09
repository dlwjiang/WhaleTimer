import Foundation
import Combine
import StoreKit

/// Access comes only from StoreKit-verified non-consumables, never a saved Boolean.
@MainActor
final class PurchaseStore: ObservableObject {
    @Published private(set) var products: [String: Product] = [:]
    @Published private(set) var ownedProductIDs: Set<String> = []
    @Published private(set) var hasLoadedEntitlements = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isRestoring = false
    @Published private(set) var purchasingID: String?
    @Published private(set) var pendingProductIDs: Set<String> = []
    @Published var message: String?
    private var updatesTask: Task<Void, Never>?
    private var refreshVersion = 0
    private var started = false

    var availableCompanions: [Companion] {
        Companion.allCases.filter { $0.isAvailable(in: ownedProductIDs) }
    }
    var isBusy: Bool { purchasingID != nil || isRestoring }

    func start() async {
        guard !started else { return }
        started = true
        // Listen before taking a snapshot so approvals outside the app are not lost.
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                await self?.handle(result)
            }
        }
        await refreshEntitlements()
        await loadProducts()
    }

    deinit { updatesTask?.cancel() }

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let fetched = try await Product.products(for: CompanionPack.productIDs)
            products = Dictionary(uniqueKeysWithValues: fetched.filter { $0.type == .nonConsumable }.map { ($0.id, $0) })
            if products.count != CompanionPack.productIDs.count {
                message = "Some packs are unavailable. You can still preview them and use owned companions."
            } else { message = nil }
        } catch {
            message = "Couldn’t load the store. Check your connection and retry. Owned companions remain available."
        }
    }

    func refreshEntitlements() async {
        refreshVersion += 1
        let version = refreshVersion
        var owned = Set<String>()
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productType == .nonConsumable,
                  CompanionPack.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            owned.insert(transaction.productID)
        }
        guard version == refreshVersion else { return }
        ownedProductIDs = owned
        hasLoadedEntitlements = true
        pendingProductIDs.subtract(owned)
    }

    func isPendingConflict(_ productID: String) -> Bool {
        pendingProductIDs.contains(productID) ||
        (productID == CompanionPack.collectionProductID && !pendingProductIDs.isEmpty) ||
        pendingProductIDs.contains(CompanionPack.collectionProductID)
    }

    func purchase(_ productID: String) async {
        guard !isBusy, hasLoadedEntitlements, !isPendingConflict(productID) else { return }
        guard CompanionPack.productIDs.contains(productID), let product = products[productID] else {
            message = "This pack is unavailable. Please try again later."
            return
        }
        if productID == CompanionPack.collectionProductID {
            guard CompanionPack.shouldOfferCollection(owned: ownedProductIDs) else { return }
        } else if let pack = CompanionPack.allCases.first(where: { $0.productID == productID }), pack.isOwned(in: ownedProductIDs) {
            return
        }
        purchasingID = productID
        message = nil
        defer { purchasingID = nil }
        do {
            switch try await product.purchase() {
            case .success(let result): await handle(result)
            case .pending:
                pendingProductIDs.insert(productID)
                message = "Awaiting approval. Companions unlock when the App Store confirms the purchase."
            case .userCancelled: break
            @unknown default: message = "The purchase hasn’t completed. Please try again later."
            }
        } catch {
            message = "Couldn’t finish the purchase. Retry, or restore purchases if you were charged."
        }
    }

    func restore() async {
        guard !isBusy else { return }
        isRestoring = true
        message = nil
        defer { isRestoring = false }
        do {
            // Only an explicit user action calls sync, which can ask for Apple Account sign-in.
            try await AppStore.sync()
            await refreshEntitlements()
            message = ownedProductIDs.isEmpty ? "No companion purchases were found for this Apple Account." : "Your companion purchases are restored."
        } catch { message = "Couldn’t restore purchases. Check your connection and Apple Account, then retry." }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            message = "The App Store couldn’t verify this purchase. Restore purchases or retry."
            return
        }
        guard CompanionPack.productIDs.contains(transaction.productID), transaction.productType == .nonConsumable else { return }
        // Invalidate an in-flight snapshot before applying the verified update.
        refreshVersion += 1
        if transaction.revocationDate == nil { ownedProductIDs.insert(transaction.productID) }
        else { ownedProductIDs.remove(transaction.productID) }
        hasLoadedEntitlements = true
        pendingProductIDs.remove(transaction.productID)
        message = nil
        await transaction.finish()
        await refreshEntitlements()
    }
}
