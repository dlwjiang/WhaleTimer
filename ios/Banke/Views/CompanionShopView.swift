import SwiftUI
import StoreKit

struct CompanionShopView: View {
    @Environment(\.dismiss) private var dismiss
    var initialPack: CompanionPack? = nil
    var body: some View {
        NavigationStack {
            CompanionShopContent(initialPack: initialPack)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct CompanionShopContent: View {
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var purchases: PurchaseStore
    var initialPack: CompanionPack? = nil

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Find your kind of company.").font(.title2.bold())
                        Text("Pick a world to focus in.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Always yours · Free", systemImage: "heart").font(.headline)
                        HStack {
                            ForEach(Companion.free) { companion in
                                companionButton(companion)
                            }
                        }
                    }.paperCard()
                    ForEach(CompanionPack.allCases) { pack in
                        NavigationLink { PackDetailView(pack: pack) } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                PackArtwork(pack: pack, pose: "idle").frame(height: 220)
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(pack.title).font(.headline)
                                        Text(pack.companions.map(\.name).joined(separator: " & ")).font(.subheadline)
                                        Text("2 companions · Voices · 1 scene").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if pack.isOwned(in: purchases.ownedProductIDs) {
                                        Label("Owned", systemImage: "checkmark.circle.fill").font(.caption)
                                    } else {
                                        VStack(alignment: .trailing, spacing: 5) {
                                            Text(purchases.products[pack.productID]?.displayPrice ?? L10n.text("Preview")).font(.headline)
                                            Text("One-time").font(.caption2)
                                        }
                                    }
                                }.padding(.horizontal, 16).padding(.bottom, 16)
                            }
                            .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 24))
                            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white))
                        }.buttonStyle(.plain).id(pack.id)
                    }
                    if CompanionPack.shouldOfferCollection(owned: purchases.ownedProductIDs) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("The three-pack collection").font(.title3.bold())
                            Text("All six companions and three scenes shown here. Future packs are not included.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            PurchaseButton(productID: CompanionPack.collectionProductID, title: "Get all three packs", theme: CompanionTheme(.luna))
                            Text("One purchase. No subscription.").font(.caption).foregroundStyle(.secondary)
                        }.paperCard()
                    }
                    storeFooter
                }.padding(20).frame(maxWidth: 660).frame(maxWidth: .infinity)
            }
            .background(Palette.paper.ignoresSafeArea())
            .foregroundStyle(Palette.ink)
            .navigationTitle(L10n.text("Companions"))
            .navigationBarTitleDisplayMode(.inline)
            .task { if purchases.products.isEmpty { await purchases.loadProducts() } }
            .onAppear {
                if let initialPack { reader.scrollTo(initialPack.id, anchor: .top) }
            }
        }
    }

    private func companionButton(_ companion: Companion) -> some View {
        Button { store.select(companion) } label: {
            VStack {
                Image("\(companion.rawValue)-idle").resizable().interpolation(.none).scaledToFit().frame(height: 100)
                Label(companion.name, systemImage: store.companion == companion ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline)
            }.frame(maxWidth: .infinity, minHeight: 140)
        }.buttonStyle(.plain).accessibilityLabel(L10n.text("Use %@", companion.name))
    }

    private var storeFooter: some View {
        VStack(spacing: 12) {
            if purchases.isLoadingProducts { ProgressView("Loading prices…") }
            if let message = purchases.message { Text(L10n.text(message)).font(.footnote).multilineTextAlignment(.center) }
            HStack {
                Button(L10n.text(purchases.isRestoring ? "Restoring…" : "Restore purchases")) { Task { await purchases.restore() } }
                    .disabled(purchases.isBusy)
                Spacer()
                Button("Reload prices") { Task { await purchases.loadProducts() } }.disabled(purchases.isLoadingProducts)
            }.font(.subheadline).frame(minHeight: 44)
            Text("Purchases use your Apple Account. Owned companions work offline.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text("Mochi, Pip, the timer, and all languages are free.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity)
    }
}

private struct PackDetailView: View {
    let pack: CompanionPack
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var purchases: PurchaseStore
    @EnvironmentObject private var audio: CompanionAudio
    @State private var pose = "idle"
    private let poses = ["idle", "focus", "rest", "happy"]
    private var theme: CompanionTheme { CompanionTheme(pack.companions[0]) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                PackArtwork(pack: pack, pose: pose).frame(height: 340)
                Text(pack.subtitle).font(.title3).multilineTextAlignment(.center)
                ViewThatFits(in: .horizontal) {
                    HStack { poseButtons }
                    VStack { poseButtons }
                }
                Text("Preview poses and voices. Your timer keeps running.")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                ForEach(pack.companions) { companion in
                    HStack(spacing: 16) {
                        Image("\(companion.rawValue)-\(pose)").resizable().interpolation(.none).scaledToFit().frame(width: 78, height: 88).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(companion.name).font(.headline)
                            Text(companion.role).font(.subheadline)
                            Text(companion.greeting).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    Button("Preview voice") { store.previewVoice(companion) }
                        .buttonStyle(.bordered)
                    if audio.captionCompanion == companion, let caption = audio.caption {
                        Text(caption).font(.callout).multilineTextAlignment(.center)
                        Button("Stop preview") { store.stopVoicePreview() }
                    }
                    if pack.isOwned(in: purchases.ownedProductIDs) {
                        Button(L10n.text(store.companion == companion ? "Selected · %@" : "Use %@", companion.name)) { store.select(companion) }
                            .buttonStyle(GlassKey(theme: theme))
                    }
                }
                if !pack.isOwned(in: purchases.ownedProductIDs) {
                    PurchaseButton(productID: pack.productID, title: L10n.text("Get %@", pack.title), theme: theme)
                    Text("Both companions, four poses each, all voice languages, scene and timer colors. No subscription.")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                if let message = purchases.message { Text(L10n.text(message)).font(.footnote).multilineTextAlignment(.center) }
            }.padding(20).frame(maxWidth: 660).frame(maxWidth: .infinity)
        }
        .background(theme.soft.ignoresSafeArea()).foregroundStyle(Palette.ink)
        .navigationTitle(pack.title).navigationBarTitleDisplayMode(.inline)
        .onDisappear { store.stopVoicePreview() }
    }

    private var poseButtons: some View {
        ForEach(poses, id: \.self) { value in
            Button { pose = value } label: {
                Text(L10n.text(value.capitalized)).font(.subheadline).padding(.horizontal, 12).frame(minHeight: 44)
                    .background(pose == value ? theme.accent : .white.opacity(0.65), in: Capsule())
                    .foregroundStyle(pose == value ? .white : theme.accent)
            }.buttonStyle(.plain).accessibilityAddTraits(pose == value ? .isSelected : [])
        }
    }
}

private struct PurchaseButton: View {
    let productID: String
    let title: String
    let theme: CompanionTheme
    @EnvironmentObject private var purchases: PurchaseStore
    var body: some View {
        Button { Task { await purchases.purchase(productID) } } label: {
            VStack(spacing: 3) {
                if purchases.purchasingID == productID { ProgressView().tint(theme.accent) }
                else if purchases.pendingProductIDs.contains(productID) { Text("Awaiting approval") }
                else if let product = purchases.products[productID] {
                    Text(L10n.text(title)).multilineTextAlignment(.center)
                    Text(product.displayPrice).font(.headline)
                } else { Text(L10n.text(purchases.isLoadingProducts ? "Loading price…" : "Currently unavailable")) }
            }.padding(10)
        }
        .buttonStyle(GlassKey(theme: theme))
        .disabled(purchases.isBusy || !purchases.hasLoadedEntitlements || purchases.products[productID] == nil || purchases.isPendingConflict(productID))
    }
}

private struct PackArtwork: View {
    let pack: CompanionPack
    let pose: String
    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(pack.companions) { companion in
                    Image("\(companion.rawValue)-\(pose)").resizable().interpolation(.none).scaledToFit()
                        .frame(width: proxy.size.width / 2, height: proxy.size.height * 0.88)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
            .padding(.bottom, 8)
            .background {
                Image(pack.backdrop).resizable().scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height).clipped()
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel([pack.title, pack.companions.map(\.name).joined(separator: ", "), L10n.text(pose.capitalized)].joined(separator: ", "))
        }
    }
}
