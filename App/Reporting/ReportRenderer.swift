import SwiftUI
import CoreGraphics

/// Renders a SwiftUI view to single-page PDF data via `ImageRenderer`.
@MainActor
enum ReportRenderer {
    static func pdf(_ view: BatteryReportView) -> Data? {
        let size = BatteryReportView.pageSize
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(size)

        let pdfData = NSMutableData()
        var rendered = false
        renderer.render { _, renderInContext in
            var mediaBox = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
                  let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }
            ctx.beginPDFPage(nil)
            // ImageRenderer's closure already maps into the context's coordinate space.
            renderInContext(ctx)
            ctx.endPDFPage()
            ctx.closePDF()
            rendered = true
        }
        return rendered ? (pdfData as Data) : nil
    }
}
