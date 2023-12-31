import Foundation
import SwiftSoup

struct PelisplusResolver: Resolver {
    let name = "Pelisplus"
    static let domains: [String] = ["pelisplus.icu"]

    enum PelisplusResolverError: Error {
        case videoNotFound
    }

    func getMediaURL(url: URL) async throws -> [Stream] {
        let pageContent = try await Utilities.downloadPage(url: url)
        let pageDocument = try SwiftSoup.parse(pageContent)
        let script = try pageDocument.select("script").filter {
            try $0.html().contains("playerInstance.setup")
        }.first?.html() ?? ""

        guard let path = Utilities.extractURLs(content: script.replacingOccurrences(of: "'", with: " '")).filter({ $0.pathExtension == "m3u8"}).first else {
            throw PelisplusResolverError.videoNotFound
        }
        return [.init(Resolver: "Pelisplus.icu", streamURL: path)]

    }

}
