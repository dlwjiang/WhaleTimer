import SwiftUI

@main
struct BankeApp: App {
    @AppStorage(L10n.preferenceKey) private var languagePreference = "system"
    @State private var deviceLanguage = AppLanguage.resolve(preference: "system")
    @StateObject private var purchases: PurchaseStore
    @StateObject private var store: StudyStore

    init() {
        let purchases = PurchaseStore()
        _purchases = StateObject(wrappedValue: purchases)
        _store = StateObject(wrappedValue: StudyStore(purchases: purchases))
    }

    var body: some Scene {
        WindowGroup {
            StudyView()
                .environmentObject(store)
                .environmentObject(store.audio)
                .environmentObject(purchases)
                .environment(\.locale, Locale(identifier: (languagePreference == "system" ? deviceLanguage : AppLanguage.resolve(preference: languagePreference)).rawValue))
                .tint(Palette.fern)
                .onChange(of: languagePreference) { _, _ in store.languageChanged() }
                .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in
                    deviceLanguage = AppLanguage.resolve(preference: "system")
                    if languagePreference == "system" { store.languageChanged() }
                }
                .task { await purchases.start() }
                .onChange(of: purchases.ownedProductIDs) { _, _ in store.reconcileCompanionAccess() }
                .onChange(of: purchases.hasLoadedEntitlements) { _, _ in store.reconcileCompanionAccess() }
        }
    }
}
