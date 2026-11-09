import SwiftUI

struct SettingsView: View {
    @AppStorage(L10n.preferenceKey) private var languagePreference = "system"
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var purchases: PurchaseStore
    @EnvironmentObject private var audio: CompanionAudio
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(L10n.text("Focus: %lld min", store.state.settings.focusMinutes), value: setting(\.focusMinutes), in: 1...180)
                    Stepper(L10n.text("Short break: %lld min", store.state.settings.shortBreakMinutes), value: setting(\.shortBreakMinutes), in: 1...60)
                    Stepper(L10n.text("Long break: %lld min", store.state.settings.longBreakMinutes), value: setting(\.longBreakMinutes), in: 1...90)
                    let presets = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading)) : AnyLayout(HStackLayout())
                    presets {
                        preset("Gentle", focus: 15, rest: 3)
                        preset("Classic", focus: 25, rest: 5)
                        preset("Deep", focus: 50, rest: 10)
                    }.buttonStyle(.bordered)
                    preset("Quick try · 1 min focus + 1 min break", focus: 1, rest: 1)
                } header: { Text("Your rhythm") } footer: {
                    Text("Long break after four focus sessions. Duration changes apply to the next session.")
                }
                Section("Sounds and voices") {
                    Toggle("Sound enabled", isOn: setting(\.soundEnabled))
                    Toggle("Button sounds and completion bell", isOn: setting(\.effectsEnabled))
                    Toggle("Companion voices", isOn: setting(\.voicesEnabled))
                    Button("Preview voice") { store.previewVoice(store.companion) }
                    Button("Stop preview") { store.stopVoicePreview() }
                    if let caption = audio.caption, audio.captionCompanion == store.companion {
                        Text(caption).font(.callout).foregroundStyle(.secondary)
                    }
                    Text("Captions remain visible when muted. Voices follow your selected language.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Toggle("Keep screen awake while timing", isOn: setting(\.keepAwake))
                    if store.state.settings.notificationsEnabled {
                        Toggle("Session reminders", isOn: setting(\.notificationsEnabled))
                    } else {
                        Button("Enable session reminders") { Task { await store.requestNotifications() } }
                    }
                    if let message = store.notificationMessage { Text(L10n.text(message)).font(.footnote) }
                    Text("Reminders use iOS notifications. Focus modes and system settings may silence them.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Language") {
                    Picker("Language", selection: $languagePreference) {
                        Text("Follow device language").tag("system")
                        ForEach(AppLanguage.allCases) { language in Text(verbatim: language.nativeName).tag(language.rawValue) }
                    }
                    Text("All languages are free. Changing language does not reset your timer.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Your companions") {
                    ForEach(purchases.availableCompanions) { companion in
                        Button { store.select(companion) } label: {
                            HStack {
                                Image("\(companion.rawValue)-idle").resizable().scaledToFit().frame(width: 56, height: 56)
                                VStack(alignment: .leading) { Text(companion.name); Text(companion.role).font(.caption).foregroundStyle(.secondary) }
                                Spacer()
                                if companion == store.companion { Image(systemName: "checkmark.circle.fill") }
                            }
                        }
                    }
                }
                Section {
                    NavigationLink("Companion packs", destination: CompanionShopContent())
                } footer: { Text("Mochi, Pip, the timer, and all languages are free.") }
                Section {
                    Text("Your timer stays on this device. No account or ads. Purchases use the App Store.")
                    Text("On iPhone Duo, folding changes the layout, never the timer.")
                } header: { Text("Made for your study corner") }
            }
            .navigationTitle(L10n.text("Your rhythm"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .onDisappear { store.stopVoicePreview() }
    }

    private func setting<T>(_ keyPath: WritableKeyPath<TimerSettings, T>) -> Binding<T> {
        Binding(get: { store.state.settings[keyPath: keyPath] }, set: { value in
            var settings = store.state.settings
            settings[keyPath: keyPath] = value
            store.updateSettings(settings)
        })
    }

    private func preset(_ title: String, focus: Int, rest: Int) -> some View {
        Button(L10n.text(title)) {
            var settings = store.state.settings
            settings.focusMinutes = focus
            settings.shortBreakMinutes = rest
            store.updateSettings(settings)
        }
    }
}

