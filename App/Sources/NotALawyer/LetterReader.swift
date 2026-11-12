import AppKit
import ImageIO
import NotALawyerCore
import PDFKit
import Vision

/// A letter from an authority, read on this Mac. Kept in memory only: no copy, no cache of the
/// recognised text and no thumbnail is written to disk. It's dropped when closed, unless the
/// user saves it to My documents.
struct LetterReading {
    struct Line {
        var text: String
        /// Vision's confidence, 0–1. Nil when the text came from a PDF's text layer or was pasted.
        var confidence: Float?
        /// Where the line is on its page, normalised with the origin at the bottom left (Vision's convention).
        var box: CGRect?
        var page: Int?

        /// Low enough that a date or number on this line may have been misread.
        var unsure: Bool { (confidence ?? 1) < 0.6 }
    }

    enum Check { case matches, differs }

    var name: String
    /// The file it came from; nil for pasted text.
    var url: URL?
    /// The pages as images, to show beside the text. Empty for pasted text.
    var pages: [NSImage]
    var lines: [Line]
    var text: String
    var facts: [LetterFact]
    /// What the reader said about each fact, by `LetterFact.id`.
    var checks: [Int: Check] = [:]
    var savedToDocuments = false

    init(name: String, url: URL?, pages: [NSImage], lines: [Line], coveredLaws: Set<String>) {
        self.name = name
        self.url = url
        self.pages = pages
        self.lines = lines
        text = lines.map(\.text).joined(separator: "\n")
        facts = LetterFacts.find(in: text, coveredLaws: coveredLaws)
    }

    func line(of fact: LetterFact) -> Line? { lines.indices.contains(fact.line) ? lines[fact.line] : nil }
}

/// Reads letters and documents on this Mac: PDFKit for PDFs with text, Vision for photos and scans.
enum LetterReader {
    /// What reading a file gives back; built off the main thread, then handed over once.
    struct Source: @unchecked Sendable {
        var pages: [NSImage] = []
        var lines: [LetterReading.Line] = []
    }

    /// Enough pages for any letter; a longer file is probably not a letter.
    static let maxPages = 12

    static func read(_ url: URL) -> Source {
        let ext = url.pathExtension.lowercased()
        if ext == "pdf", let pdf = PDFDocument(url: url) {
            var source = Source()
            for index in 0..<min(pdf.pageCount, maxPages) {
                guard let page = pdf.page(at: index) else { continue }
                let image = page.thumbnail(of: CGSize(width: 1700, height: 2200), for: .mediaBox)
                source.pages.append(image)
                let text = page.string ?? ""
                if text.trimmingCharacters(in: .whitespacesAndNewlines).count > 40 {
                    source.lines += text.components(separatedBy: .newlines).map { .init(text: $0, page: index) }
                } else if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                    // A scan with no text layer.
                    source.lines += recogniseLines(cg).map { .init(text: $0.text, confidence: $0.confidence, box: $0.box, page: index) }
                }
            }
            return source
        }
        if ["txt", "md"].contains(ext) {
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
            return Source(lines: text.components(separatedBy: .newlines).map { .init(text: $0) })
        }
        guard let image = orientedImage(url) else { return Source() }
        return Source(pages: [NSImage(cgImage: image, size: .zero)],
                      lines: recogniseLines(image).map { .init(text: $0.text, confidence: $0.confidence, box: $0.box, page: 0) })
    }

    static func lines(pasted text: String) -> [LetterReading.Line] {
        text.components(separatedBy: .newlines).map { .init(text: $0) }
    }

    /// A photo the right way up: phones store the rotation separately from the pixels.
    private static func orientedImage(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 3000,
            kCGImageSourceShouldCache: false,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    struct RecognisedLine {
        var text: String
        var confidence: Float
        var box: CGRect
    }

    /// Vision's text recogniser, on this Mac, in German and English. Synchronous: call it off the main thread.
    static func recogniseLines(_ image: CGImage) -> [RecognisedLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["de-DE", "en-US"]
        do { try VNImageRequestHandler(cgImage: image).perform([request]) } catch { return [] }
        return (request.results ?? []).compactMap { observation in
            observation.topCandidates(1).first.map { RecognisedLine(text: $0.string, confidence: $0.confidence, box: observation.boundingBox) }
        }
    }
}
