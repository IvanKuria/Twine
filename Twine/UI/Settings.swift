import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }

            CreditsTab()
                .tabItem { Label("Credits", systemImage: "info.circle") }
        }
        .frame(width: 420)
        .padding()
    }
}

// MARK: - General tab

private struct GeneralSettingsTab: View {

    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("defaultSort")   private var defaultSort: String = "date"
    @AppStorage("exportScale")   private var exportScale: Double = 2.0

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        LoginItem.setEnabled(newValue)
                    }
                    .onAppear {
                        launchAtLogin = LoginItem.isEnabled
                    }
            }

            Section("Map board") {
                Picker("Default sort", selection: $defaultSort) {
                    Text("Date").tag("date")
                    Text("Name").tag("name")
                    Text("Country").tag("country")
                }
                .pickerStyle(.menu)

                Picker("Export resolution", selection: $exportScale) {
                    Text("1x").tag(1.0)
                    Text("2x").tag(2.0)
                    Text("3x").tag(3.0)
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Credits tab

private struct CreditsTab: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            Text("Twine")
                .font(.title2.bold())
                .foregroundStyle(Theme.ocean)

            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1")")
                .font(Theme.labelFont)
                .foregroundStyle(.secondary)

            Divider()

            Group {
                AttributionRow(
                    title: "Geo data",
                    detail: "Copyright GeoNames, licensed under CC BY 4.0",
                    url: URL(string: "https://www.geonames.org")
                )

                AttributionRow(
                    title: "Map shapes",
                    detail: "Natural Earth (public domain)",
                    url: URL(string: "https://www.naturalearthdata.com")
                )
            }

            Spacer()

            Text("Built with SwiftUI on macOS.")
                .font(Theme.labelFont)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - AttributionRow

private struct AttributionRow: View {
    let title: String
    let detail: String
    let url: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            if let url {
                Link(detail, destination: url)
                    .font(Theme.labelFont)
            } else {
                Text(detail)
                    .font(Theme.labelFont)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
