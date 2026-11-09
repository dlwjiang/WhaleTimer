import Foundation

enum CompanionPack: String, CaseIterable, Identifiable, Sendable {
    case midnightCafe, moonlightAcademy, orbitalNightShift
    var id: String { rawValue }
    var productID: String { "app.banke.companions.\(rawValue).v1" }
    static let collectionProductID = "app.banke.companions.collection.v1"
    static let productIDs = Set(allCases.map(\.productID) + [collectionProductID])

    var title: String {
        switch self {
        case .midnightCafe: L10n.text("Midnight Café")
        case .moonlightAcademy: L10n.text("Moonlight Academy")
        case .orbitalNightShift: L10n.text("Orbital Night Shift")
        }
    }
    var subtitle: String {
        switch self {
        case .midnightCafe: L10n.text("A warm window for your late-night ideas.")
        case .moonlightAcademy: L10n.text("One more page under a sky full of stars.")
        case .orbitalNightShift: L10n.text("A small crew for your next big mission.")
        }
    }
    var companions: [Companion] {
        switch self {
        case .midnightCafe: [.jun, .bean]
        case .moonlightAcademy: [.luna, .atlas]
        case .orbitalNightShift: [.nova, .orbit]
        }
    }
    var backdrop: String { "scene-\(rawValue)" }
    func isOwned(in productIDs: Set<String>) -> Bool {
        productIDs.contains(productID) || productIDs.contains(Self.collectionProductID)
    }
    static func shouldOfferCollection(owned productIDs: Set<String>) -> Bool {
        // StoreKit does not automatically credit earlier individual purchases.
        allCases.allSatisfy { !$0.isOwned(in: productIDs) }
    }
}

enum Companion: String, CaseIterable, Codable, Identifiable, Sendable {
    case mochi, pip, jun, bean, luna, atlas, nova, orbit
    var id: String { rawValue }
    static let free: [Companion] = [.mochi, .pip]
    var pack: CompanionPack? {
        switch self {
        case .mochi, .pip: nil
        case .jun, .bean: .midnightCafe
        case .luna, .atlas: .moonlightAcademy
        case .nova, .orbit: .orbitalNightShift
        }
    }
    var name: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    var role: String {
        switch self {
        case .mochi: L10n.text("Your quiet desk cat")
        case .pip: L10n.text("Your botanical study buddy")
        case .jun: L10n.text("Your midnight barista")
        case .bean: L10n.text("Your café cat")
        case .luna: L10n.text("Your star-atlas scholar")
        case .atlas: L10n.text("Your little library owl")
        case .nova: L10n.text("Your orbital study partner")
        case .orbit: L10n.text("Your pocket mission robot")
        }
    }
    var greeting: String { L10n.voice("greeting", companion: self) }
    func isAvailable(in productIDs: Set<String>) -> Bool { pack?.isOwned(in: productIDs) ?? true }
}
