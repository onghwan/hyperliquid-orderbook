import SwiftUI

struct SettingsScreen: View {
    @Bindable var preferences: Preferences

    var body: some View {
        NavigationStack {
            Form {
                Section("Feedback") {
                    Toggle("Haptics", isOn: $preferences.hapticsEnabled)
                }
                .listRowBackground(Theme.card)

                Section("Feed") {
                    row("Source", "Hyperliquid")
                    row("Channels", "l2Book · bbo · activeAssetCtx")
                }
                .listRowBackground(Theme.card)

                Section {
                    row("Version", version)
                } header: {
                    Text("About")
                } footer: {
                    Text("Coin logos from the CC0 cryptocurrency-icons set.")
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
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
    SettingsScreen(preferences: Preferences())
}
