import SwiftUI
import AppKit
import SwiftData

// MARK: - Onboarding

struct Onboarding: View {

    let library: PhotoLibrary
    @Bindable var coordinator: ImportCoordinator
    let onFinished: () -> Void
    var onSkip: () -> Void = {}

    @State private var auth: PhotoAuth = .notDetermined

    var body: some View {
        ZStack {
            Theme.ocean
                .ignoresSafeArea()

            switch auth {
            case .notDetermined:
                NotDeterminedView(library: library, coordinator: coordinator, auth: $auth, onSkip: onSkip)

            case .denied:
                DeniedView(onSkip: onSkip)

            case .limited:
                LimitedView(onSkip: onSkip)

            case .full:
                FullView(coordinator: coordinator)
            }
        }
        .onAppear {
            auth = library.authorization()
        }
        .onChange(of: coordinator.phase) { _, newPhase in
            if newPhase == .done {
                // Brief pause so user can read the summary before transitioning.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onFinished()
                }
            }
        }
    }
}

// MARK: - NotDetermined

private struct NotDeterminedView: View {
    let library: PhotoLibrary
    let coordinator: ImportCoordinator
    @Binding var auth: PhotoAuth
    let onSkip: () -> Void

    var body: some View {
        HeroLayout {
            Image(systemName: "map.fill")
                .font(.system(size: 72, weight: .thin))
                .foregroundStyle(Theme.pin)

            VStack(spacing: 8) {
                Text("Twine")
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Your life. On a map.")
                    .font(.system(size: 17, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            TwineButton(title: "Scan my photos") {
                Task {
                    let result = await library.requestAccess()
                    auth = result
                    if result == .full {
                        await coordinator.run()
                    }
                }
            }

            Button("Add places manually") { onSkip() }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Denied

private struct DeniedView: View {
    let onSkip: () -> Void

    var body: some View {
        HeroLayout {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(Theme.pin)

            VStack(spacing: 8) {
                Text("Photo access needed")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Twine needs access to your photo library to place pins on your map. Open System Settings to grant access.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }

            TwineButton(title: "Open System Settings") {
                openPhotosPrivacySettings()
            }

            Button("Continue without photos") { onSkip() }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Limited

private struct LimitedView: View {
    let onSkip: () -> Void

    var body: some View {
        HeroLayout {
            Image(systemName: "photo.stack")
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(Theme.home)

            VStack(spacing: 8) {
                Text("Limited Photo Access")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                Text("Twine has limited photo access. Grant Full Access so your whole map can populate.")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }

            TwineButton(title: "Open System Settings") {
                openPhotosPrivacySettings()
            }

            Button("Continue without photos") { onSkip() }
                .buttonStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Full (running + done)

private struct FullView: View {
    let coordinator: ImportCoordinator

    var body: some View {
        HeroLayout {
            if coordinator.phase == .done {
                // Summary
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundStyle(Theme.pin)

                VStack(spacing: 8) {
                    Text("Imported!")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    if coordinator.noLocationCount > 0 {
                        Text("\(coordinator.noLocationCount) photos had no location and were skipped.")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 340)
                    }
                }
            } else {
                // Progress
                SpinnerIcon(isActive: coordinator.phase != .idle)

                VStack(spacing: 16) {
                    Text(phaseLabel)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                        .contentTransition(.numericText())

                    ProgressView(value: coordinator.progress)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 300)
                        .tint(Theme.pin)
                }
            }
        }
    }

    private var phaseLabel: String {
        switch coordinator.phase {
        case .idle:      return "Starting…"
        case .scanning:  return "Scanning photos…"
        case .geocoding: return "Looking up locations…"
        case .saving:    return "Saving to map…"
        case .done:      return "Done"
        }
    }
}

// MARK: - SpinnerIcon (macOS 14 compatible)

private struct SpinnerIcon: View {
    let isActive: Bool
    @State private var angle: Double = 0

    var body: some View {
        Image(systemName: "arrow.2.circlepath")
            .font(.system(size: 56, weight: .thin))
            .foregroundStyle(Theme.pin)
            .rotationEffect(.degrees(angle))
            .onAppear {
                guard isActive else { return }
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
    }
}

// MARK: - Shared helpers

private func openPhotosPrivacySettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
        NSWorkspace.shared.open(url)
    }
}

/// Vertically-centered hero column with consistent spacing.
private struct HeroLayout<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 28) {
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(48)
    }
}

/// Primary branded button.
private struct TwineButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(Theme.pin, in: RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Not Determined") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: PlaceRecord.self, configurations: config)
    let library = PhotoLibrary()
    let coordinator = ImportCoordinator(
        library: library,
        modelContext: container.mainContext
    )
    return Onboarding(library: library, coordinator: coordinator, onFinished: {}, onSkip: {})
        .frame(width: 520, height: 420)
        .modelContainer(container)
}
