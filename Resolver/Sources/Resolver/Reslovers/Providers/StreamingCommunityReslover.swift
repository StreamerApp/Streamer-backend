import Foundation
import SwiftSoup

struct StreamingCommunityResolver: Resolver {
    let name = "StreamingCommunity"
    static let domains: [String] = ["streamingcommunity.dance"]

    func canHandle(url: URL) -> Bool {
        Self.domains.firstIndex(of: url.host!) != nil || url.host?.contains("streamingcommunity") == true
    }

    func getMediaURL(url: URL) async throws -> [Stream] {

        let pageContent = try await Utilities.downloadPage(url: url)
        let document = try SwiftSoup.parse(pageContent)
        let path = try document.select("iframe").attr("src").removingPercentEncoding?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        // https://vixcloud.co/embed/183340
        let embedURL = try URL(path)
        let embedID = embedURL.lastPathComponent

        let embedContent = try await Utilities.downloadPage(url: embedURL)
        let embedDocument = try SwiftSoup.parse(embedContent)
        let script = try embedDocument.select("script").array().filter { try $0.html().contains("window.video")}.first?.html() ?? ""

        let win_video = script.matches(for: "window.video = (\\{.*\\})").first?.replacingOccurrences(of: "'", with: "\"")
        let win_param = script.matches(for: "params: (\\{[\\s\\S]*\\}),").first?.replacingOccurrences(of: "'", with: "\"")

        guard let videoData = win_video?.data(using: .utf8), let paramData = win_param?.data(using: .utf8) else {
            throw ProviderError.noContent
        }

        let paramResponse = try JSONDecoder().decode(VideoData.self, from: videoData)
        let videoResponse = try JSONDecoder().decode(VideoResponse.self, from: paramData)
        let playlistURL = URL(staticString: "https://vixcloud.co/playlist/")
        .appendingPathComponent(embedID)
        .appending([
            "token": videoResponse.token,
            "token360p": videoResponse.token360p,
            "token480p": videoResponse.token480p,
            "token720p": videoResponse.token720p,
            "token1080p": videoResponse.token1080p,
            "expires": videoResponse.expires
        ])
        .appendingPathExtension("m3u")

        return [.init(Resolver: "StreamingCommunity", streamURL: playlistURL, quality: .init(quality: "\(paramResponse.quality ?? 0)"))]
    }

    struct VideoData: Codable {
        let id: Int
        let name: String
        let filename: String
        let size: Int
        let quality: Int
        let duration: Int
        let views: Int
        let is_viewable: Int
        let status: String
        let fps: Int
        let legacy: Int
        let folder_id: String
        let created_at_diff: String
    }
    struct VideoResponse: Codable {
        let token: String
        let token360p: String
        let token480p: String
        let token720p: String
        let token1080p: String
        let expires: String
    }
}
