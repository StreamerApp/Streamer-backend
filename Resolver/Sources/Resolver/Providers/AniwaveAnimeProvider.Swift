
import Foundation
import SwiftSoup

public struct AniwaveAnimeProvider: Provider {
    public init() {}

    public let locale: Locale = Locale(identifier: "en")
    public let type: ProviderType = .init(.aniwave)
    public let title: String = "AniwaveAnimeProvider"
    public let langauge: String = ""

    public let baseURL: URL = URL(staticString: "https://aniwave.to")
    public var moviesURL: URL {
        baseURL.appendingPathComponent("movie")
    }
    public var tvShowsURL: URL {
        baseURL.appendingPathComponent("tv")
    }

    private var homeURL: URL {
        baseURL
    }
    @EnviromentValue(key: "vrfSolverURL", defaultValue: URL(staticString: "https://google.com"))
    private var vrfSolverURL: URL
    enum GogoAnimeHDProviderError: Error {
        case missingMovieInformation
        case invalidURL
    }

    public func parsePage(url: URL) async throws -> [MediaContent] {
        let content = try await  Utilities.downloadPage(url: url)
        let document = try SwiftSoup.parse(content)
        let rows: Elements = try document.select(".inner")
        return try rows.array().compactMap { row -> MediaContent? in
            let path = try row.select("a").attr("href")
            let title: String = try row.select("a.name").text()
            let posterPath: String = try row.select("img").attr("src")

            guard let posterURL = URL(string: posterPath) else {
                return nil
            }
            let webURL = baseURL.appendingPathComponent(path)
            return MediaContent(
                title: title,
                webURL: webURL,
                posterURL: posterURL,
                type: .tvShow,
                provider: self.type
            )
        }

    }

    public func latestMovies(page: Int) async throws -> [MediaContent] {
        return try await parsePage(url: moviesURL.appending(["page": String(page)]))
    }

    public func latestTVShows(page: Int) async throws -> [MediaContent] {
        return try await parsePage(url: tvShowsURL.appending(["page": String(page)]))
    }

    public func fetchMovieDetails(for url: URL) async throws -> Movie {
        throw GogoAnimeHDProviderError.missingMovieInformation
    }

    
  
        
        
    public func fetchTVShowDetails(for url: URL) async throws -> TVshow {
        let pageContent = try await Utilities.downloadPage(url: url)
        let pageDocument = try SwiftSoup.parse(pageContent)
        let details = try pageDocument.select("div.poster")
        let title = try pageDocument.select(".names").text()
        let posterPath = try details.select("img").attr("src")
        let posterURL = try URL(posterPath)

        let dataId = try pageDocument.select("div.rating").attr("data-id")
        let requestUrl = baseURL.appendingPathComponent("ajax/episode/list").appendingPathComponent(dataId)
        let releaseDate = try pageDocument.select("[itemprop=dateCreated]").text()
        let year = Int(releaseDate.components(separatedBy: " ").last ?? "2023")

        let vrf = try await encodeVrf(text: dataId)

        let data = try await Utilities.requestData(url: requestUrl, parameters: ["vrf": vrf])
        let content = try JSONDecoder().decode(Response.self, from: data)
        let document = try SwiftSoup.parse(content.result)
        let rows: Elements = try document.select(".ep-range")
        let epDataId = try rows.select("a").attr("data-ids")
        //moved the vrfServer before the  episodes in order for it to work
        let vrfServer = try await encodeVrf(text: epDataId)

        let seasons = try rows.array().map { seasonDoc in

            let episodes = try seasonDoc.select("a").array().map { row in
                let epInfo = try row.attr("data-num")
                let episodeNumber = Int(epInfo) ?? 1
                let epDataId = try row.attr("data-ids")

                // Constructing source URL with VRF parameter
                let sourceUrl = self.baseURL
                    .appendingPathComponent("ajax/server/list")
                    .appendingPathComponent(epDataId)
                var components = URLComponents(url: sourceUrl, resolvingAgainstBaseURL: false)
                components?.queryItems = [URLQueryItem(name: "vrf", value: vrfServer)]
                guard let finalSourceUrl = components?.url else {
                    throw GogoAnimeHDProviderError.invalidURL
                }

                return Episode(number: episodeNumber, sources: [Source(hostURL: finalSourceUrl)])
            }

            let seasonInfo = try seasonDoc.attr("data-season")
            let seasonNumber = Int(seasonInfo) ?? 1
            let seasonURL = baseURL.appendingPathComponent(seasonNumber)
            return Season(seasonNumber: seasonNumber, webURL: seasonURL, episodes: episodes)
        }

        return TVshow(title: title, webURL: url, posterURL: posterURL, year: year, seasons: seasons)
    }



    
    public func search(keyword: String, page: Int) async throws -> [MediaContent] {
        let query = keyword.replacingOccurrences(of: " ", with: "+")
        let url = baseURL.appendingPathComponent("filter").appending("keyword", value: query)
        return try await parsePage(url: url)
    }


    public func home() async throws -> [MediaContentSection] {

        let recentURL = URL(staticString: "https://aniwave.to/newest").appending(["page": String(1), "type": String(1)])
        let recent = try await parsePage(url: recentURL)
        let dubURL = URL(staticString: "https://aniwave.to/filter?keyword=&language%5B%5D=dub&sort=release_date").appending(["page": String(1), "type": String(2)])
        let dub = try await parsePage(url: dubURL)
        let UpdatedURL = URL(staticString: "https://aniwave.to/updated").appending(["page": String(1), "type": String(3)])
        let Updated = try await parsePage(url: UpdatedURL)
        

        return [.init(title: "Newest", media: recent), .init(title: "Dub", media: dub), .init(title: "Updated", media: Updated)]
    }

}
private extension AniwaveAnimeProvider {
    struct Response: Codable {
        let result: String
    }

    func encodeVrf(text: String) async throws -> String {
        struct SearchData: Codable {
            let url: String
        }
        let url = vrfSolverURL.appendingPathComponent("aniwave-vrf").appending([
            "query": text
        ])
        let data = try await Utilities.requestData(url: url)
        let result = try JSONDecoder().decode(SearchData.self, from: data).url
        return result.replacingOccurrences(of: "/", with: "%2F").replacingOccurrences(of: "=", with: "%3D")
    }
}

