
import Foundation
import SwiftSoup

public struct GeoAnimeProvider: Provider {
    public init() {}

    public let locale: Locale = Locale(identifier: "en")
    public let type: ProviderType = .init(.geoanime)
    public let title: String = "GeoDubbedanime"
    public let langauge: String = ""

    public let baseURL: URL = URL(staticString: "https://genoanime.com")
    public var moviesURL: URL = URL(staticString: "https://genoanime.com/browse?genre=dubbed")

    public var tvShowsURL: URL = URL(staticString: "https://genoanime.com/browse?sort=top_rated&")


    private var homeURL: URL {
        baseURL.appendingPathComponent("home")
    }

    enum GeoAnimeProviderError: Error {
        case missingMovieInformation
        case episodeLinkNotFound
        case invalidURL
    }

    public func parsePage(url: URL) async throws -> [MediaContent] {
        let content = try await Utilities.downloadPage(url: url)
        let document = try SwiftSoup.parse(content)
        let rows: Elements = try document.select(".col-lg-10 .product__item")

        return try rows.array().compactMap { item in
            let path: String = try item.select("a").attr("href").replacingOccurrences(of: ".", with: "")
            var webURL: URL

            if path.hasPrefix("https") {
                webURL = try URL(path)
            } else {
                // Remove the dot (.) from the path
                let cleanedPath = path.replacingOccurrences(of: "./", with: "")
                webURL = baseURL.appendingPathComponent(cleanedPath)
            }

            let title: String = try item.select(".product__item__text h5 a").text()
            let posterPath: String = try item.select(".product__item__pic").attr("data-setbg")
            var fullPosterURL: URL

            if let posterURL = URL(string: posterPath), posterURL.scheme != nil {
                // If posterPath is a valid absolute URL
                fullPosterURL = posterURL
            } else {
                // If posterPath is a relative URL
                let absolutePosterPath = posterPath.hasPrefix("/") ? posterPath : "/" + posterPath
                fullPosterURL = baseURL.appendingPathComponent(absolutePosterPath)
            }

            let posterURL = try URL(posterPath)
            let sfullPosterURL = baseURL.appendingPathComponent(posterURL.path)

            let epType = try item.select(".ep").text()
            let type: MediaContent.MediaContentType = epType.contains("Movie") ? .movie : .tvShow

            return MediaContent(
                title: title,
                webURL: webURL,
                posterURL: sfullPosterURL,
                type: type,
                provider: self.type
            )
        }
    }

    public func latestMovies(page: Int) async throws -> [MediaContent] {
        return try await parsePage(url: moviesURL.appending(["page": String(page)]))
    }

    public func latestTVShows(page: Int) async throws -> [MediaContent] {
        return try await parsePage(url: tvShowsURL)
    }

    public func fetchMovieDetails(for url: URL) async throws -> Movie {
        throw GeoAnimeProviderError.missingMovieInformation
    }

    public func fetchTVShowDetails(for url: URL) async throws -> TVshow {
        let pageContent = try await Utilities.downloadPage(url: url)
        let pageDocument = try SwiftSoup.parse(pageContent)

        // Extract title and poster URL
        let title = try pageDocument.select("title").text().replacingOccurrences(of: "Episode List on Genoanime", with:  "").replacingOccurrences(of: "Watch", with: "")
        let posterPath = try pageDocument.select("meta[property=og:image]").attr("content")
        let posterURL = try URL(posterPath)

        let episodesDiv = try pageDocument.select(".tab-content .tab-pane.fade.in.active")
        let episodeElements = try episodesDiv.select("a.episode")

        var episodes: [Episode] = []
        var episodeURLs: [URL] = []

        for (index, episodeElement) in episodeElements.enumerated() {
            let episodeNumberText = try episodeElement.text().replacingOccurrences(of: "Ep ", with: "")
            let episodeNumber = Int(episodeNumberText) ?? (index + 1)
            let episodeLink = try episodeElement.attr("href").replacingOccurrences(of: "..", with: "")
            let episodeURL = baseURL.appendingPathComponent(episodeLink)
            let source = Source(hostURL: episodeURL)

            episodes.append(Episode(number: episodeNumber, sources: [source]))
            episodeURLs.append(episodeURL)
        }

        let season = Season(seasonNumber: 1, webURL: url, episodes: episodes)
        let tvShow = TVshow(title: title, webURL: url, posterURL: posterURL, seasons: [season])

        return tvShow
    }

    public func search(keyword: String, page: Int) async throws -> [MediaContent] {
        var components = URLComponents(url: URL(staticString: "https://genoanime.com/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "ani", value: keyword)
        ]

        guard let searchURL = components.url else {
            throw GeoAnimeProviderError.invalidURL
        }

        return try await parsePage(url: searchURL)
    }

     

    enum MediaType {
        case movie
        case tvShow
    }

    public func home() async throws -> [MediaContentSection] {
        let subbedURL = baseURL.appendingPathComponent("browse").appending(["sort": "latest", "genre": "subbed"])
        let dubbedURL = baseURL.appendingPathComponent("browse").appending(["sort": "latest", "genre": "dubbed"])
        let oVAURL = baseURL.appendingPathComponent("browse").appending(["sort": "latest", "genre": "OVA"])
        let specialURL = baseURL.appendingPathComponent("browse").appending(["sort": "latest", "genre": "Special"])

        let subbed = try await parsePage(url: subbedURL)
        let dubbed = try await parsePage(url: dubbedURL)
        let ova = try await parsePage(url: oVAURL)
        let special = try await parsePage(url: specialURL)

        return [
            .init(title: "Subbed", media: subbed),
            .init(title: "Dubbed", media: dubbed),
            .init(title: "OVA Series", media: ova),
            .init(title: "Special", media: special)
        ]
    }

    private struct Response: Codable {
        let html: String
    }
}
