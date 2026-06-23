import SwiftUI
import AppKit
import TwineKit

// MARK: - PosterView
//
// Pure SwiftUI composition — safe for ImageRenderer (no MapKit, no NSViewRepresentable).
// Layout: header (app name + tagline) / BoardView snapshot / stats footer.

struct PosterView: View {

    let places: [Place]
    let home: Coordinate?
    let size: CGSize

    private var stats: Stats {
        StatsBuilder.build(places: places, home: home)
    }

    private var threadMiles: Int {
        Int(stats.threadKilometers * 0.621371)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            mapArea
            statsFooter
        }
        .frame(width: size.width, height: size.height)
        .background(Theme.ocean)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Text("Twine")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.176, green: 0.337, blue: 0.529))
            Text("Your world, pinned.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    // MARK: - Map area

    private var boardSize: CGSize {
        let w = size.width - 40
        let h = size.height - 160  // header ~72 + footer ~88
        return CGSize(width: max(w, 100), height: max(h, 100))
    }

    private var mapArea: some View {
        // Constant bindings — no interaction needed for a static poster.
        BoardView(
            places: places,
            home: home,
            selectedPlaceID: .constant(nil),
            scale: .constant(1.0),
            offset: .constant(.zero)
        )
        .frame(width: boardSize.width, height: boardSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Stats footer

    private var statsFooter: some View {
        HStack(spacing: 0) {
            statCell(value: "\(stats.countries)", label: "countries")
            divider
            statCell(value: "\(stats.cities)", label: "cities")
            divider
            statCell(value: "\(threadMiles)", label: "thread mi")
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
    }

    private var divider: some View {
        Divider()
            .frame(height: 32)
            .padding(.horizontal, 8)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.176, green: 0.337, blue: 0.529))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - PosterExporter

enum PosterExporter {

    /// Renders `PosterView` at `size` at 3× pixel density.
    /// Must be called on the MainActor (ImageRenderer requirement).
    @MainActor
    static func render(places: [Place], home: Coordinate?, size: CGSize) -> NSImage? {
        let poster = PosterView(places: places, home: home, size: size)
        let renderer = ImageRenderer(content: poster)
        renderer.scale = 3
        return renderer.nsImage
    }
}

// MARK: - ExportView

/// Drop this into a toolbar or menu — it owns the render + save panel flow.
struct ExportView: View {

    let places: [Place]
    let home: Coordinate?

    var body: some View {
        Button {
            exportPoster()
        } label: {
            Label("Export Poster", systemImage: "square.and.arrow.up")
        }
        .help("Save a high-res PNG poster of your map")
    }

    // MARK: - Export action

    @MainActor
    func exportPoster() {
        let size = CGSize(width: 1080, height: 720)

        guard let image = PosterExporter.render(places: places, home: home, size: size) else {
            return
        }

        guard let pngData = pngData(from: image) else { return }

        let panel = NSSavePanel()
        panel.title = "Save Twine Poster"
        panel.nameFieldStringValue = "twine-poster.png"
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try pngData.write(to: url)
        } catch {
            // Non-fatal: user sees no file. Could surface an alert in a future iteration.
        }
    }

    // MARK: - NSImage → PNG Data

    private func pngData(from image: NSImage) -> Data? {
        guard
            let tiff = image.tiffRepresentation,
            let rep  = NSBitmapImageRep(data: tiff)
        else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

// MARK: - Preview

#Preview("PosterView — sample places") {
    let paris   = Place(id: UUID(), coordinate: Coordinate(latitude:  48.857, longitude:   2.352),
                        city: "Paris",    country: "France",    continent: "Europe")
    let tokyo   = Place(id: UUID(), coordinate: Coordinate(latitude:  35.682, longitude: 139.691),
                        city: "Tokyo",    country: "Japan",     continent: "Asia")
    let nyc     = Place(id: UUID(), coordinate: Coordinate(latitude:  40.713, longitude: -74.006),
                        city: "New York", country: "USA",       continent: "North America")
    let nairobi = Place(id: UUID(), coordinate: Coordinate(latitude:  -1.286, longitude:  36.818),
                        city: "Nairobi",  country: "Kenya",     continent: "Africa")
    let sydney  = Place(id: UUID(), coordinate: Coordinate(latitude: -33.868, longitude: 151.209),
                        city: "Sydney",   country: "Australia", continent: "Oceania")

    PosterView(
        places: [paris, tokyo, nyc, nairobi, sydney],
        home: Coordinate(latitude: 37.334, longitude: -122.009), // Cupertino
        size: CGSize(width: 900, height: 600)
    )
    .frame(width: 900, height: 600)
}
