import Foundation
import SwiftSoup

struct AnimesultraResolver: Resolver {
    let name = "AnimesultraResolver"
    static let domains: [String] = ["w2.animesultra.net"]
    private let baseURL: URL = URL(staticString: "https://w2.animesultra.net/")

    func getMediaURL(url: URL) async throws -> [Stream] {
        let stringContent = try await Utilities.downloadPage(url: url) // This function returns a String
        guard let data = stringContent.data(using: .utf8) else {
            throw NSError(domain: "DataConversionError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Unable to convert string to Data"])
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        
        let sPattern = "data-class=(.+?) .+?data-server-id=(.+?)"
        let document = try SwiftSoup.parse(response.html) // Parse the HTML content from the JSON
        let playerBoxes: Elements = try document.select(".player_box")

        return try await playerBoxes.array().compactMap { box -> URL? in
            let videoUrlString = try box.text()
            guard let videoUrl = URL(string: videoUrlString) else {
                return nil
            }
            return videoUrl
        }
        .concurrentMap {
            return try? await HostsResolver.resolveURL(url: $0)
        }
        .compactMap { $0 }
        .flatMap { $0 }
    }

    struct Response: Decodable {
        let status: Bool
        let html: String
    }
}
