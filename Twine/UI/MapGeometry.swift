import AppKit
import Foundation
import SwiftUI
import TwineKit

// MARK: - GeoJSON Decodable types

private struct FeatureCollection: Decodable {
    let features: [Feature]
}

private struct Feature: Decodable {
    let geometry: Geometry?
}

private struct Geometry: Decodable {
    let type: String
    // Polygon:      [[[Double]]]
    // MultiPolygon: [[[[Double]]]]
    let polygonRings: [[[Double]]]?       // Polygon coords
    let multiPolygonRings: [[[[Double]]]]? // MultiPolygon coords

    enum CodingKeys: String, CodingKey {
        case type, coordinates
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decode(String.self, forKey: .type)
        switch type {
        case "Polygon":
            polygonRings = try? c.decode([[[Double]]].self, forKey: .coordinates)
            multiPolygonRings = nil
        case "MultiPolygon":
            multiPolygonRings = try? c.decode([[[[Double]]]].self, forKey: .coordinates)
            polygonRings = nil
        default:
            polygonRings = nil
            multiPolygonRings = nil
        }
    }
}

// MARK: - MapGeometry

enum MapGeometry {

    // Each element is a closed SwiftUI Path representing one country polygon ring,
    // in unit space (0...1, y-down equirectangular via Projection).
    static func countryPaths() -> [Path] { _paths }

    // Rasterise the static country layer into an NSImage of `size`.
    // The result is computed once per unique (size, fill, stroke, lineWidth) call
    // site; callers are expected to hold the image themselves if caching matters.
    static func image(
        size: CGSize,
        fill: NSColor,
        stroke: NSColor,
        lineWidth: CGFloat
    ) -> NSImage {
        let img = NSImage(size: size)
        img.lockFocus()
        defer { img.unlockFocus() }

        let sx = size.width, sy = size.height

        for path in _paths {
            // Scale unit path -> pixel path
            var transform = CGAffineTransform(scaleX: sx, y: sy)
            let cgPath = path.cgPath.copy(using: &transform) ?? path.cgPath

            let nsPath = NSBezierPath(cgPath: cgPath)
            fill.setFill()
            nsPath.fill()
            stroke.setStroke()
            nsPath.lineWidth = lineWidth
            nsPath.stroke()
        }
        return img
    }

    // MARK: - Private cache

    private static let _paths: [Path] = loadPaths()

    private static func loadPaths() -> [Path] {
        guard
            let url = Bundle.main.url(forResource: "ne_110m_countries", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else {
            // Resource not found — return empty rather than crash.
            assertionFailure("ne_110m_countries.json not found in app bundle")
            return []
        }

        guard let fc = try? JSONDecoder().decode(FeatureCollection.self, from: data) else {
            assertionFailure("Failed to decode ne_110m_countries.json")
            return []
        }

        var paths: [Path] = []
        paths.reserveCapacity(fc.features.count * 2)

        for feature in fc.features {
            guard let geom = feature.geometry else { continue }
            switch geom.type {
            case "Polygon":
                if let rings = geom.polygonRings {
                    for ring in rings {
                        if let p = makePath(ring: ring) { paths.append(p) }
                    }
                }
            case "MultiPolygon":
                if let polys = geom.multiPolygonRings {
                    for poly in polys {
                        for ring in poly {
                            if let p = makePath(ring: ring) { paths.append(p) }
                        }
                    }
                }
            default:
                break
            }
        }
        return paths
    }

    /// Build a closed SwiftUI Path from one GeoJSON coordinate ring.
    /// Each coordinate is `[longitude, latitude]`.
    private static func makePath(ring: [[Double]]) -> Path? {
        guard ring.count >= 2 else { return nil }
        var path = Path()
        var started = false
        for coord in ring {
            guard coord.count >= 2 else { continue }
            let pt = Projection.project(Coordinate(latitude: coord[1], longitude: coord[0]))
            let cgpt = CGPoint(x: pt.x, y: pt.y)
            if !started {
                path.move(to: cgpt)
                started = true
            } else {
                path.addLine(to: cgpt)
            }
        }
        guard started else { return nil }
        path.closeSubpath()
        return path
    }
}
