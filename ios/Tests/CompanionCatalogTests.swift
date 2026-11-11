import Foundation
import Testing
@testable import BankeCore

@Test func packsPartitionPaidCompanionsAndUnknownProductsUnlockNothing() {
    #expect(Companion.free == [.mochi, .pip, .pebble])
    #expect(Companion.allCases.count == 12)
    let paid = CompanionPack.allCases.flatMap(\.companions)
    #expect(Set(paid).count == 9)
    #expect(Set(paid).union(Companion.free) == Set(Companion.allCases))
    #expect(Companion.allCases.filter { $0.isAvailable(in: ["unknown.product"]) } == Companion.free)
    for pack in CompanionPack.allCases {
        #expect(pack.companions.count == 3)
        #expect(Companion.allCases.filter { $0.isAvailable(in: [pack.productID]) } == Companion.free + pack.companions)
    }
}

@Test func paidCompanionSurvivesStateRoundTripWithoutChangingDeadline() throws {
    var state = StudyState()
    state.session.start(at: Date(timeIntervalSince1970: 1_800_000_000))
    state.companion = .nova
    let restored = StudyState.restore(try JSONEncoder().encode(state))
    #expect(restored.companion == .nova)
    #expect(restored.session.deadline == state.session.deadline)
    #expect(restored.completedInCycle == 0)
}

@Test func collectionIsOfferedOnlyBeforeOwningAnyPack() {
    #expect(CompanionPack.shouldOfferCollection(owned: []))
    for pack in CompanionPack.allCases {
        #expect(!CompanionPack.shouldOfferCollection(owned: [pack.productID]))
    }
    #expect(!CompanionPack.shouldOfferCollection(owned: [CompanionPack.collectionProductID]))
    #expect(Companion.allCases.allSatisfy { $0.isAvailable(in: [CompanionPack.collectionProductID]) })
}
