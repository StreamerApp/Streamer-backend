import Foundation
import SwiftSoup

struct AniwaveAnimeResolver: Resolver {
    let name = "Aniwave"
    static let domains: [String] = ["aniwave.to"]

    @EnviromentValue(key: "vrfSolverURL", defaultValue: URL(staticString: "https://google.com"))
    private var vrfSolverURL: URL

    struct Response: Codable {
        let result: String
    }

    func getMediaURL(url: URL) async throws -> [Stream] {
        let urls = try await getSources(url: url)
        let subtitles = try await urls.concurrentMap {
            try? await self.getSubtitles(url: $0)
        }.compactMap { $0 }.flatMap { $0 }.unique()

        return try await urls
            .concurrentMap {
                return try? await HostsResolver.resolveURL(url: $0)
            }
            .compactMap { $0 }
            .flatMap { $0 }
            .map {
                Stream(stream: $0, subtitles: subtitles)
            }

    }

    func getSources(url: URL) async throws -> [URL] {
        let dataId = url.lastPathComponent
        let vrf = try await encodeVrf(text: dataId)
        let data = try await Utilities.requestData(url: url, parameters: ["vrf": vrf])

        // https://flixtor.video/ajax/server/838771?vrf=ZExJX053anY%3D
        let servers = try JSONDecoder().decode(Response.self, from: data)

        let document = try SwiftSoup.parse(servers.result)
        let rows: Elements = try document.select(".servers")
        return try await rows.array().concurrentMap { row -> URL? in
            let id: String = try row.attr("data-ep-id")
            let epVrf = try await encodeVrf(text: id)

            // https://flixtor.video/ajax/server/838771?vrf=ZExJX053anY%3D
            let url = try URL("https://\(url.host ?? "")").appendingPathComponent("ajax/server").appendingPathComponent(id)
            let data = try await Utilities.requestData(url: url, parameters: ["vrf": epVrf], extraHeaders: ["if-none-match": ""])
            let serversResponse = try JSONDecoder().decode(MediaResponse.self, from: data)
            return URL(string: try await decryptVrf(text: serversResponse.result.url))
        }.compactMap { $0 }
    }

    func getSubtitles(url: URL) async throws -> [Subtitle] {
        var subtitles: [Subtitle] = []
        if let subtitleInfo = url.queryParameters?["sub.info"],
           let subtitleURL = URL(string: subtitleInfo) {
            let data = try await Utilities.requestData(url: subtitleURL)
            let subtitlesResponse = try JSONDecoder().decode([SubtitleResponse].self, from: data)

            subtitles = subtitlesResponse.compactMap {
                if let language = SubtitlesLangauge(rawValue: $0.label) {
                    return Subtitle(url: $0.file, language: language)
                } else {
                    return nil
                }
            }
        }
        return subtitles
    }

    struct SubtitleResponse: Codable, Identifiable {
        var id: String {
            file.absoluteString
        }
        let file: URL
        let label: String
        let kind: String
    }
    struct MediaResponse: Codable {
        let result: URLResponse

    }
    struct URLResponse: Codable {
        let url: String

    }

}

private extension AniwaveAnimeResolver {

    func encodeVrf(text: String) async throws -> String {
        struct SearchData: Codable {
            let url: String
        }
        let url = vrfSolverURL.appendingPathComponent("aniwave-vrf").appending([
            "query": text
        ])
        let data = try await Utilities.requestData(url: url)
        let result = try JSONDecoder().decode(SearchData.self, from: data).url
        return result
    }
    func decryptVrf(text: String) async throws -> String {
        struct SearchData: Codable {
            let url: String
        }
        let url = vrfSolverURL.appendingPathComponent("aniwave-decrypt").appending([
            "query": text
        ])
        let data = try await Utilities.requestData(url: url)
        return try JSONDecoder().decode(SearchData.self, from: data).url
    }

}
