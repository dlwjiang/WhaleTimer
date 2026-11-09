import XCTest
import StoreKit
import StoreKitTest
@testable import Banke

/// Exercises Apple's local StoreKit service, including verified transactions and updates.
@MainActor
final class PurchaseStoreTests: XCTestCase {
    private var session: SKTestSession!
    private var purchases: PurchaseStore!

    override func setUp() async throws {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Companions", withExtension: "storekit"))
        session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        purchases = PurchaseStore()
        await purchases.start()
        XCTAssertEqual(purchases.products.count, 4, purchases.message ?? "Missing products")
    }

    override func tearDown() async throws {
        purchases = nil
        session.clearTransactions()
        session.resetToDefaultState()
        session = nil
    }

    func testProductsAndFreeAccess() {
        XCTAssertEqual(Set(purchases.products.keys), CompanionPack.productIDs)
        XCTAssertEqual(purchases.availableCompanions, [.mochi, .pip])
        for pack in CompanionPack.allCases {
            XCTAssertEqual(purchases.products[pack.productID]?.price, Decimal(string: "3.99"))
            XCTAssertEqual(purchases.products[pack.productID]?.type, .nonConsumable)
        }
        XCTAssertEqual(purchases.products[CompanionPack.collectionProductID]?.price, Decimal(string: "8.99"))
    }

    func testIndividualPurchaseRestoresWithoutDoubleCharging() async throws {
        let id = CompanionPack.midnightCafe.productID
        await purchases.purchase(id)
        XCTAssertEqual(purchases.availableCompanions, [.mochi, .pip, .jun, .bean])
        XCTAssertFalse(CompanionPack.shouldOfferCollection(owned: purchases.ownedProductIDs))
        let count = session.allTransactions().count
        await purchases.purchase(id)
        await purchases.purchase(CompanionPack.collectionProductID)
        XCTAssertEqual(session.allTransactions().count, count)
        let recreated = PurchaseStore()
        await recreated.start()
        XCTAssertEqual(recreated.ownedProductIDs, [id])
        await recreated.restore()
        XCTAssertEqual(recreated.availableCompanions, [.mochi, .pip, .jun, .bean])
    }

    func testCollectionUnlocksAllAndRefundRemovesAccess() async throws {
        await purchases.purchase(CompanionPack.collectionProductID)
        XCTAssertEqual(purchases.availableCompanions, Companion.allCases)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "BankePurchaseTests.refund"))
        defaults.removePersistentDomain(forName: "BankePurchaseTests.refund")
        defer { defaults.removePersistentDomain(forName: "BankePurchaseTests.refund") }
        let study = StudyStore(purchases: purchases, defaults: defaults)
        study.select(.nova)
        var settings = study.state.settings
        settings.soundEnabled = false
        study.updateSettings(settings)
        study.primaryAction()
        try await eventually { study.session.status == .running }
        let deadline = study.session.deadline
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        try await eventually { self.purchases.ownedProductIDs.isEmpty }
        study.reconcileCompanionAccess()
        XCTAssertEqual(study.companion, .mochi)
        XCTAssertEqual(study.state.companion, .mochi)
        XCTAssertEqual(study.session.deadline, deadline)
        XCTAssertEqual(study.session.status, .running)
        study.select(.atlas)
        XCTAssertEqual(study.companion, .mochi)
        XCTAssertEqual(purchases.availableCompanions, [.mochi, .pip])
        study.reset()
    }

    func testPendingApprovalUnlocksOnlyAfterConfirmation() async throws {
        session.askToBuyEnabled = true
        let id = CompanionPack.moonlightAcademy.productID
        await purchases.purchase(id)
        XCTAssertEqual(purchases.availableCompanions, [.mochi, .pip])
        XCTAssertTrue(purchases.pendingProductIDs.contains(id))
        XCTAssertTrue(purchases.isPendingConflict(CompanionPack.collectionProductID))
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: transaction.identifier)
        try await eventually { self.purchases.ownedProductIDs.contains(id) }
        XCTAssertEqual(purchases.availableCompanions, [.mochi, .pip, .luna, .atlas])
        XCTAssertFalse(purchases.pendingProductIDs.contains(id))
    }

    func testFailedAndCancelledPurchasesNeverGrantAccess() async throws {
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        await purchases.purchase(CompanionPack.orbitalNightShift.productID)
        XCTAssertEqual(purchases.availableCompanions, [.mochi, .pip])
        XCTAssertFalse(purchases.isBusy)
        try await session.setSimulatedError(.generic(.notAvailableInStorefront), forAPI: .purchase)
        await purchases.purchase(CompanionPack.orbitalNightShift.productID)
        XCTAssertTrue(purchases.ownedProductIDs.isEmpty)
        XCTAssertNotNil(purchases.message)
        XCTAssertFalse(purchases.isBusy)
    }

    func testUnverifiedPurchaseNeverGrantsAccess() async throws {
        try await session.setSimulatedError(.verification(.invalidSignature), forAPI: .verification)
        await purchases.purchase(CompanionPack.midnightCafe.productID)
        XCTAssertEqual(purchases.availableCompanions, [.mochi, .pip])
        XCTAssertNotNil(purchases.message)
    }

    func testStoreAndRestoreFailureKeepExistingAccess() async throws {
        await purchases.purchase(CompanionPack.orbitalNightShift.productID)
        let owned = purchases.ownedProductIDs
        try await session.setSimulatedError(.generic(.notAvailableInStorefront), forAPI: .loadProducts)
        await purchases.loadProducts()
        XCTAssertEqual(purchases.ownedProductIDs, owned)
        XCTAssertNotNil(purchases.message)
        try await session.setSimulatedError(.generic(.notAvailableInStorefront), forAPI: .appStoreSync)
        await purchases.restore()
        XCTAssertEqual(purchases.ownedProductIDs, owned)
        XCTAssertNotNil(purchases.message)
        XCTAssertFalse(purchases.isRestoring)
    }

    private func eventually(_ condition: @escaping @MainActor () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(8)
        while !condition(), Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertTrue(condition(), "StoreKit transaction update did not arrive")
    }
}
