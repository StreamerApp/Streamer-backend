import Foundation
import SwiftSoup

struct YugenAnimeResolver: Resolver {
    let name = "YugenAnime"
    static let domains: [String] = ["yugenanime.tv"]

    enum YugenAnimeResolverError: Error {
        case urlNotValid, contentFetchingError, parsingError
    }

    func getMediaURL(url: URL) async throws -> [Stream] {
        // Fetch and parse the main content
        guard let content = try? await Utilities.downloadPage(url: url) else {
            throw YugenAnimeResolverError.contentFetchingError
        }
        let document = try SwiftSoup.parse(content)

        // Extract the src attribute of the iframe with id "main-embed"
        let iframeSrcs = try document.select("iframe#main-embed").array().map {
            try $0.attr("src")
        }

        // Convert relative URLs to absolute URLs and filter out invalid ones
        let validURLs = try iframeSrcs.compactMap { src -> URL? in
            guard var absoluteSrc = URL(string: src, relativeTo: url)?.absoluteString else {
                throw YugenAnimeResolverError.urlNotValid
            }
            if src.starts(with: "//") {
                absoluteSrc = "https:" + src
            }
            return URL(string: absoluteSrc)
        }

        // Resolve URLs concurrently and flatten the results
        let streams = try await validURLs.concurrentMap { videoURL -> [Stream] in
            guard let resolvedStreams = try? await HostsResolver.resolveURL(url: videoURL) else {
                return []
            }
            return resolvedStreams
        }
        .flatMap { $0 }

        return streams
    }

    // Helper methods (if any, e.g., `concurrentMap`) go here...
}
