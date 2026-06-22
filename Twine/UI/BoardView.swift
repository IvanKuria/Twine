import SwiftUI
import AppKit
import TwineKit

// MARK: - BoardView
//
// The visual centrepiece: a zoomable / pannable poster-style map with
// country fill, thread lines from Home to each visited place, and pin dots.
//
// Layout stack (bottom → top):
//   1. Ocean background (Color fill)
//   2. NSImage country backdrop (rasterised once per size)
//   3. SwiftUI Canvas – threads + pins (applies same transform as backdrop)
//
// The backdrop image is regenerated whenever the view's GeometryReader
// reports a new size; subsequent frames reuse the cached NSImage.

struct BoardView: View {

    // MARK: - Inputs

    let places: [Place]
    let home: Coordinate?

    @Binding var selectedPlaceID: UUID?
    @Binding var scale: CGFloat
    @Binding var offset: CGSize

    // MARK: - Private state

    /// Cached backdrop per size so we don't re-rasterise every frame.
    @State private var backdropCache: (size: CGSize, image: NSImage)? = nil

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack(alignment: .topLeading) {

                // 1. Ocean background
                Theme.ocean
                    .ignoresSafeArea()

                // 2. Country backdrop image
                backdropImage(for: size)
                    .resizable()
                    .frame(width: size.width, height: size.height)
                    .transformEffect(mapTransform(in: size))

                // 3. Canvas overlay — threads + pins
                Canvas { ctx, canvasSize in
                    drawThreads(ctx: ctx, size: canvasSize)
                    drawPins(ctx: ctx, size: canvasSize)
                }
                .frame(width: size.width, height: size.height)
                .transformEffect(mapTransform(in: size))
                .contentShape(Rectangle())

                // 4. Invisible tap target (full view size, no transform)
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        handleTap(at: location, in: size)
                    }
            }
            .clipped()
            .gesture(panGesture())
            .gesture(magnificationGesture())
            // Regenerate backdrop whenever the container size changes.
            .onChange(of: size) { _, newSize in
                backdropCache = nil
            }
        }
    }

    // MARK: - Backdrop helper

    private func backdropImage(for size: CGSize) -> Image {
        let nsImage: NSImage
        if let cached = backdropCache, cached.size == size {
            nsImage = cached.image
        } else {
            let img = MapGeometry.image(
                size: size,
                fill: Theme.mapFill,
                stroke: Theme.mapStroke,
                lineWidth: Theme.mapLineWidth
            )
            // Update cache on next tick to avoid modifying state mid-render.
            DispatchQueue.main.async {
                backdropCache = (size: size, image: img)
            }
            nsImage = img
        }
        return Image(nsImage: nsImage)
    }

    // MARK: - Transform

    /// Affine transform that applies `scale` (around canvas centre) then `offset`.
    private func mapTransform(in size: CGSize) -> CGAffineTransform {
        let cx = size.width / 2
        let cy = size.height / 2
        return CGAffineTransform(translationX: cx, y: cy)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -cx + offset.width / scale, y: -cy + offset.height / scale)
    }

    // MARK: - Canvas drawing helpers

    /// Convert a unit-space UnitPoint2D to canvas-pixel coordinates.
    private func canvasPoint(_ unit: UnitPoint2D, in size: CGSize) -> CGPoint {
        CGPoint(x: unit.x * size.width, y: unit.y * size.height)
    }

    private func drawThreads(ctx: GraphicsContext, size: CGSize) {
        guard let home else { return }
        let homeUnit = Projection.project(home)
        let homePoint = canvasPoint(homeUnit, in: size)

        var path = Path()
        for place in places {
            let placeUnit  = Projection.project(place.coordinate)
            let placePoint = canvasPoint(placeUnit, in: size)
            path.move(to: homePoint)
            path.addLine(to: placePoint)
        }
        ctx.stroke(
            path,
            with: .color(Theme.thread),
            style: StrokeStyle(lineWidth: Theme.threadWidth, lineCap: .round)
        )
    }

    private func drawPins(ctx: GraphicsContext, size: CGSize) {
        // Draw normal pins first, selected on top, Home last.
        for place in places where place.id != selectedPlaceID {
            drawPin(ctx: ctx, size: size, place: place, selected: false)
        }
        if let selID = selectedPlaceID, let sel = places.first(where: { $0.id == selID }) {
            drawPin(ctx: ctx, size: size, place: sel, selected: true)
        }
        if let home {
            drawHomeMarker(ctx: ctx, size: size, coordinate: home)
        }
    }

    private func drawPin(
        ctx: GraphicsContext,
        size: CGSize,
        place: Place,
        selected: Bool
    ) {
        let unit  = Projection.project(place.coordinate)
        let pt    = canvasPoint(unit, in: size)
        let r     = selected ? Theme.pinRadiusSelected : Theme.pinRadius
        let color = selected ? Theme.pinSelected : Theme.pin

        let rect  = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
        let dot   = Path(ellipseIn: rect)

        // White halo so the dot pops over light land and dark ocean alike.
        let haloRect = rect.insetBy(dx: -1.5, dy: -1.5)
        let halo = Path(ellipseIn: haloRect)
        ctx.fill(halo, with: .color(.white.opacity(0.75)))
        ctx.fill(dot, with: .color(color))
    }

    private func drawHomeMarker(ctx: GraphicsContext, size: CGSize, coordinate: Coordinate) {
        let unit = Projection.project(coordinate)
        let pt   = canvasPoint(unit, in: size)
        let r    = Theme.homeRadius

        // Filled circle with a contrasting ring.
        let innerRect = CGRect(x: pt.x - r + 2, y: pt.y - r + 2, width: (r - 2) * 2, height: (r - 2) * 2)
        let outerRect = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)

        let outer = Path(ellipseIn: outerRect)
        let inner = Path(ellipseIn: innerRect)

        ctx.fill(outer, with: .color(.white))
        ctx.fill(inner, with: .color(Theme.home))
        ctx.stroke(outer, with: .color(Theme.home), lineWidth: 1.2)
    }

    // MARK: - Gestures

    private func panGesture() -> some Gesture {
        DragGesture()
            .onChanged { value in
                offset = value.translation
            }
    }

    private func magnificationGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = (scale * value).clamped(to: 1...8)
            }
    }

    // MARK: - Hit testing

    /// Convert a tap in view coordinates back through the inverse of `mapTransform`
    /// to canvas coordinates, then find the nearest pin within `hitSlop` points.
    private func handleTap(at location: CGPoint, in size: CGSize) {
        let transform = mapTransform(in: size)
        guard let inv = transform.safeInverted() else {
            selectedPlaceID = nil
            return
        }
        // Apply inverse transform to get canvas-space location.
        let canvasLoc = location.applying(inv)

        var best: (id: UUID, dist: CGFloat)? = nil
        for place in places {
            let unit = Projection.project(place.coordinate)
            let pt   = canvasPoint(unit, in: size)
            let dist = hypot(canvasLoc.x - pt.x, canvasLoc.y - pt.y)
            // Convert hitSlop from view points to canvas points (divide by scale).
            if dist < Theme.hitSlop / scale {
                if best == nil || dist < best!.dist {
                    best = (place.id, dist)
                }
            }
        }
        selectedPlaceID = best?.id
    }
}

// MARK: - CGAffineTransform helpers

private extension CGAffineTransform {
    /// Returns the inverted transform, or nil if singular (determinant == 0).
    func safeInverted() -> CGAffineTransform? {
        let det = a * d - b * c
        guard det != 0 else { return nil }
        return self.inverted()
    }
}

// MARK: - Comparable clamping

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview

#Preview("Board — sample places") {
    @Previewable @State var selected: UUID? = nil
    @Previewable @State var scale:    CGFloat = 1.0
    @Previewable @State var offset:   CGSize  = .zero

    let paris   = Place(id: UUID(), coordinate: Coordinate(latitude:  48.857, longitude:   2.352),
                        city: "Paris",    country: "France", continent: "Europe")
    let tokyo   = Place(id: UUID(), coordinate: Coordinate(latitude:  35.682, longitude: 139.691),
                        city: "Tokyo",    country: "Japan",  continent: "Asia")
    let nyc     = Place(id: UUID(), coordinate: Coordinate(latitude:  40.713, longitude: -74.006),
                        city: "New York", country: "USA",    continent: "North America")
    let nairobi = Place(id: UUID(), coordinate: Coordinate(latitude:  -1.286, longitude:  36.818),
                        city: "Nairobi",  country: "Kenya",  continent: "Africa")

    BoardView(
        places: [paris, tokyo, nyc, nairobi],
        home: Coordinate(latitude: 37.334, longitude: -122.009), // Cupertino
        selectedPlaceID: $selected,
        scale: $scale,
        offset: $offset
    )
    .frame(width: 900, height: 500)
}
