import AppKit
import SwiftUI
import XCTest
@testable import Capso

@MainActor
final class QuickAccessShadowRenderingTests: XCTestCase {
    func testSwiftUIPreviewRendersSoftShadowInsideItsGutter() throws {
        let item = try XCTUnwrap(QuickAccessPreviewDemo.makeItem(index: 0))
        let card = try XCTUnwrap(item.previewView)
        let content = card.frame(width: 288, height: 200)
            .modifier(QuickAccessCardShadow())
            .padding(QuickAccessStackStyle.shadowGutter)
            .environment(\.quickAccessStaticPreview, true)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let bitmap = NSBitmapImageRep(cgImage: try XCTUnwrap(renderer.cgImage))
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: URL(fileURLWithPath: "/private/tmp/capso-swiftui-shadow.png"))
        for x in stride(from: 0, to: bitmap.pixelsWide, by: 8) {
            XCTAssertLessThan(try XCTUnwrap(bitmap.colorAt(x: x, y: 0)).alphaComponent, 0.02)
            XCTAssertLessThan(try XCTUnwrap(bitmap.colorAt(x: x, y: bitmap.pixelsHigh - 1)).alphaComponent, 0.02)
        }
        XCTAssertGreaterThan(try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)).alphaComponent, 0.9)
    }
}
