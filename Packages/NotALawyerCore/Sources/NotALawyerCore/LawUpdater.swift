import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Downloads the current official XML from gesetze-im-internet.de (spec §8).
///
/// This is the app's only connection to the internet, and it only runs when the user asks.
/// Each law is checked by parsing it before it replaces the old file, so a bad download
/// never leaves the app without laws.
public enum LawUpdater {
    public static let host = "www.gesetze-im-internet.de"

    public static func update(into directory: URL, sources: [LawSource] = LawSource.v1) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let session = URLSession(configuration: .ephemeral)
        for source in sources {
            try NetworkPolicy.check(source.xmlZipURL, purpose: "Law update: \(source.law)")
            let (zip, response) = try await session.download(from: source.xmlZipURL)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw LawUpdateError.download(source.law, http.statusCode)
            }
            let xml = try unzipXML(zip)
            _ = try LawXMLParser.parse(data: xml, source: source)
            try xml.write(to: directory.appendingPathComponent("\(source.slug).xml"), options: .atomic)
            try? FileManager.default.removeItem(at: zip)
        }
        let today = Date().formatted(.iso8601.year().month().day())
        try today.write(to: directory.appendingPathComponent(LawIndex.checkedFile), atomically: true, encoding: .utf8)
    }

    /// Extracts the one `.xml` file from the archive (AufenthV also ships form images, which we skip).
    static func unzipXML(_ zip: URL) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-p", zip.path, "*.xml"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0, !data.isEmpty else { throw LawUpdateError.unzip }
        return data
    }
}

public enum LawUpdateError: Error, LocalizedError {
    case download(String, Int)
    case unzip

    public var errorDescription: String? {
        switch self {
        case .download(let law, let code): "Couldn't download \(law) (error \(code))."
        case .unzip: "Couldn't unpack the downloaded law file."
        }
    }
}
