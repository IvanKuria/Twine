import SwiftUI
import SwiftData
import TwineKit

// MARK: - PinDetail

/// Detail panel shown when a place pin is selected.
/// Displays the representative hero photo, city/country, date range, visit count,
/// a horizontal photo strip, and an editable note (persisted via SwiftData).
struct PinDetail: View {

    @Bindable var record: PlaceRecord
    @State private var loader = ThumbnailLoader()

    // Loaded images keyed by assetID
    @State private var heroImage: NSImage? = nil
    @State private var stripImages: [String: NSImage] = [:]

    // MARK: - Constants

    private let heroSize    = CGSize(width: 600, height: 260)
    private let thumbSize   = CGSize(width: 120, height: 120)
    private let stripCap    = 12

    // MARK: - Derived data

    private var allAssetIDs: [String] {
        record.visits.flatMap(\.assetIDs)
    }

    private var stripAssetIDs: [String] {
        // Exclude the representative asset to avoid duplication in the strip.
        let rep = record.representativeAssetID
        let others = allAssetIDs.filter { $0 != rep }
        return Array(others.prefix(stripCap))
    }

    private var dateRangeLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM yyyy"
        switch (record.firstDate, record.lastDate) {
        case let (first?, last?) where first != last:
            return "\(fmt.string(from: first)) – \(fmt.string(from: last))"
        case let (first?, _):
            return fmt.string(from: first)
        default:
            return "Unknown dates"
        }
    }

    private var visitCount: Int { record.visits.count }

    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Hero photo ──────────────────────────────────────────────
                heroPhoto
                    .frame(maxWidth: .infinity)
                    .frame(height: heroSize.height)
                    .clipped()
                    .task(id: record.representativeAssetID) {
                        heroImage = nil
                        guard let id = record.representativeAssetID else { return }
                        heroImage = await loader.image(for: id, target: heroSize)
                    }

                // ── Info block ───────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 12) {

                    // City + country
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.city)
                            .font(.title2.bold())
                        Text(record.country)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Date range + stats
                    HStack(spacing: 16) {
                        Label(dateRangeLabel, systemImage: "calendar")
                            .font(Theme.labelFont)
                            .foregroundStyle(.secondary)

                        if visitCount > 0 {
                            Label(
                                visitCount == 1 ? "1 visit" : "\(visitCount) visits",
                                systemImage: "airplane"
                            )
                            .font(Theme.labelFont)
                            .foregroundStyle(.secondary)
                        }

                        if record.photoCount > 0 {
                            Label("\(record.photoCount) photos", systemImage: "photo.on.rectangle")
                                .font(Theme.labelFont)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // ── Photo strip ──────────────────────────────────────────
                    if !stripAssetIDs.isEmpty {
                        photoStrip
                    }

                    Divider()

                    // ── Note field ───────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Note", systemImage: "note.text")
                            .font(Theme.labelFont.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextEditor(
                            text: Binding(
                                get: { record.note ?? "" },
                                set: { record.note = $0.isEmpty ? nil : $0 }
                            )
                        )
                        .font(.body)
                        .frame(minHeight: 80)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                                .fill(Color(nsColor: .textBackgroundColor))
                                .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.cardCornerRadius)
                                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
                        )
                    }
                }
                .padding(16)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Subviews

    @ViewBuilder
    private var heroPhoto: some View {
        if let img = heroImage {
            Image(nsImage: img)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color(nsColor: .quaternaryLabelColor)
                Image(systemName: "photo")
                    .font(.system(size: 40))
                    .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
            }
        }
    }

    @ViewBuilder
    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 6) {
                ForEach(stripAssetIDs, id: \.self) { assetID in
                    ThumbnailCell(
                        assetID: assetID,
                        size: thumbSize,
                        image: stripImages[assetID]
                    )
                    .task(id: assetID) {
                        if stripImages[assetID] == nil {
                            let img = await loader.image(for: assetID, target: thumbSize)
                            stripImages[assetID] = img
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .frame(height: thumbSize.height + 4)
    }
}

// MARK: - ThumbnailCell

private struct ThumbnailCell: View {
    let assetID: String
    let size: CGSize
    let image: NSImage?

    var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(nsColor: .quaternaryLabelColor)
                    Image(systemName: "photo")
                        .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
    }
}

// MARK: - Preview

#Preview("PinDetail") {
    // Build an in-memory container for the preview.
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: PlaceRecord.self, configurations: config)

    let record = PlaceRecord(
        id: UUID(),
        lat: 48.857,
        lon: 2.352,
        city: "Paris",
        country: "France",
        continent: "Europe",
        photoCount: 142,
        representativeAssetID: nil,   // No real PHAsset in preview
        note: "Wonderful croissants near the Marais.",
        isManual: false,
        firstDate: Calendar.current.date(from: DateComponents(year: 2019, month: 6, day: 10)),
        lastDate:  Calendar.current.date(from: DateComponents(year: 2022, month: 9, day: 3)),
        visitsJSON: "[]"
    )
    container.mainContext.insert(record)

    return PinDetail(record: record)
        .frame(width: 420, height: 600)
        .modelContainer(container)
}
