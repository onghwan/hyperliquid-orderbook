import SwiftUI

struct SettingsScreen: View {
    @Environment(Preferences.self) var preferences
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var bindablePreferences = preferences
        
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $bindablePreferences.appearance) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Theme.card)
                
                Section("Feedback") {
                    Toggle("Haptics", isOn: $bindablePreferences.hapticsEnabled)
                }
                .listRowBackground(Theme.card)

                Section("Feed") {
                    row("Source", "Hyperliquid")
                    row("Channels", "l2Book · bbo · activeAssetCtx")
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
        }
        // Not redundant with the app-level modifier: a sheet is its own
        // presentation and doesn't inherit the colour scheme from the window.
        .preferredColorScheme(preferences.appearance.colorScheme)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer(minLength: 16)
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    SettingsScreen()
}
