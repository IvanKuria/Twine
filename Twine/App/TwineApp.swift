import SwiftUI
import SwiftData

// MARK: - TwineApp

@main
struct TwineApp: App {
    var body: some Scene {
        WindowGroup {
            RootGate()
        }
        .modelContainer(Store.container())
    }
}

// MARK: - RootGate

/// Reads the model context (available after .modelContainer is set) so it can
/// build ImportCoordinator, then gates between Onboarding and ContentView.
private struct RootGate: View {

    @Environment(\.modelContext) private var modelContext
    @Query private var placeRecords: [PlaceRecord]

    /// True once the user has finished (or skipped) onboarding.
    @State private var onboardingDone: Bool = false

    // Hold library + coordinator alive for the lifetime of the root view.
    @State private var library = PhotoLibrary()
    @State private var coordinator: ImportCoordinator? = nil

    // MARK: - Derived

    /// Enter main view when: onboarding explicitly finished, OR there are already places.
    private var showMain: Bool {
        onboardingDone || !placeRecords.isEmpty
    }

    // MARK: - Body

    var body: some View {
        Group {
            if showMain {
                ContentView()
            } else {
                if let coord = coordinator {
                    Onboarding(
                        library: library,
                        coordinator: coord,
                        onFinished: { onboardingDone = true },
                        onSkip: { onboardingDone = true }
                    )
                    .frame(minWidth: 520, minHeight: 420)
                } else {
                    // Coordinator not yet built — show a brief spinner.
                    ProgressView()
                        .frame(minWidth: 300, minHeight: 200)
                }
            }
        }
        .onAppear {
            if coordinator == nil {
                coordinator = ImportCoordinator(library: library, modelContext: modelContext)
            }
        }
    }
}
