import Foundation
import PDFKit
import Vision

/// Sorts a document by what it says, on this Mac: PDFKit reads PDFs, Vision reads photos and
/// scans. The text is used only to choose the type, a language level and a date; it isn't sent
/// anywhere or given to the model.
enum DocumentClassifier {
    struct Result {
        var kind: DocumentKind
        /// e.g. "Level B1"
        var detail: String?
        var issued: Date?
    }

    static func classify(_ url: URL) async -> Result {
        let text = await readText(url)
        return classify(text: text, fileName: url.deletingPathExtension().lastPathComponent)
    }

    // MARK: Reading

    static func readText(_ url: URL) async -> String {
        if url.pathExtension.lowercased() == "pdf", let pdf = PDFDocument(url: url) {
            let text = (0..<min(pdf.pageCount, 6)).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n")
            if text.trimmingCharacters(in: .whitespacesAndNewlines).count > 40 { return text }
            // A scanned PDF has no text layer: recognise the first page as an image.
            if let page = pdf.page(at: 0) {
                let image = page.thumbnail(of: CGSize(width: 1800, height: 2400), for: .mediaBox)
                if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) { return await recognise(cg) }
            }
            return text
        }
        if ["txt", "md"].contains(url.pathExtension.lowercased()) {
            return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return "" }
        return await recognise(image)
    }

    static func recognise(_ image: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let lines = (request.results as? [VNRecognizedTextObservation])?.compactMap { $0.topCandidates(1).first?.string } ?? []
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["de-DE", "en-US"]
            do { try VNImageRequestHandler(cgImage: image).perform([request]) } catch { continuation.resume(returning: "") }
        }
    }

    // MARK: Sorting

    /// Words that appear on each kind of document, weighted by how telling they are.
    static let signals: [(DocumentKind, [(String, Int)])] = [
        (.languageCertificate, [("telc", 3), ("goethe-zertifikat", 4), ("goethe-institut", 3), ("testdaf", 4),
                                ("deutsch-test für zuwanderer", 5), ("zertifikat deutsch", 4), ("sprachprüfung", 3),
                                ("referenzrahmen", 2), ("ösd", 3), ("sprachniveau", 2)]),
        (.citizenshipTest, [("einbürgerungstest", 5), ("test leben in deutschland", 5), ("leben in deutschland", 3)]),
        (.integrationCourse, [("zertifikat integrationskurs", 5), ("integrationskurs", 3), ("orientierungskurs", 3)]),
        (.pensionRecord, [("versicherungsverlauf", 5), ("deutsche rentenversicherung", 4), ("renteninformation", 4),
                          ("beitragszeiten", 2), ("pflichtbeiträge", 2)]),
        (.payslip, [("gehaltsabrechnung", 5), ("entgeltabrechnung", 5), ("lohnabrechnung", 5), ("auszahlungsbetrag", 3),
                    ("gesamtbrutto", 3), ("nettobezug", 3)]),
        (.taxAssessment, [("einkommensteuerbescheid", 5), ("steuerbescheid", 4), ("finanzamt", 2), ("festgesetzt", 1)]),
        (.employmentContract, [("arbeitsvertrag", 5), ("probezeit", 2), ("kündigungsfrist", 2), ("arbeitnehmer", 1),
                               ("employment contract", 5)]),
        (.rentalContract, [("mietvertrag", 5), ("vermieter", 2), ("kaltmiete", 3), ("wohnfläche", 2), ("nebenkosten", 1)]),
        (.residenceCard, [("aufenthaltstitel", 4), ("zusatzblatt", 4), ("niederlassungserlaubnis", 2),
                          ("aufenthaltserlaubnis", 2), ("residence permit", 3), ("blaue karte eu", 2)]),
        (.passport, [("reisepass", 4), ("passport", 4), ("passeport", 4), ("p<", 3)]),
        (.degree, [("zeugnis", 3), ("urkunde", 2), ("bachelor of", 3), ("master of", 3), ("diplom", 3),
                   ("hochschulabschluss", 3), ("abschlusszeugnis", 4)]),
        (.registration, [("meldebescheinigung", 5), ("einwohnermeldeamt", 3), ("bürgeramt", 2), ("anmeldung", 2)]),
        (.decision, [("rechtsbehelfsbelehrung", 4), ("bescheid", 2), ("hiermit wird", 2), ("widerspruch", 1)]),
        (.application, [("antrag auf", 3), ("antragsteller", 2), ("antragstellerin", 2)]),
    ]

    static func classify(text: String, fileName: String) -> Result {
        let t = text.lowercased()
        let scored = signals.map { kind, words in (kind, words.reduce(0) { $0 + (t.contains($1.0) ? $1.1 : 0) }) }
        let best = scored.max { $0.1 < $1.1 }
        let kind = (best?.1 ?? 0) >= 3 ? best!.0 : DocumentStore.guessKind(from: fileName)
        var detail: String?
        if kind == .languageCertificate || kind == .integrationCourse,
           let level = text.firstMatch(of: /\b(A1|A2|B1|B2|C1|C2)\b/) {
            detail = "Level \(level.1)"
        }
        return Result(kind: kind, detail: detail, issued: latestDate(in: text))
    }

    /// The latest plausible date written on the document, as dd.mm.yyyy.
    static func latestDate(in text: String) -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        return text.matches(of: /\b(\d{1,2})\.(\d{1,2})\.((?:19|20)\d{2})\b/).compactMap { m -> Date? in
            guard let d = Int(m.1), let mo = Int(m.2), let y = Int(m.3), (1...31).contains(d), (1...12).contains(mo) else { return nil }
            return calendar.date(from: DateComponents(year: y, month: mo, day: d))
        }
        .filter { $0 <= Date() }
        .max()
    }
}
