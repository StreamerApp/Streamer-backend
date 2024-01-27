import Foundation
import SwiftSoup

public struct AnimesultraAnimeProvider: Provider {
    public init() {}
    
    public let locale: Locale = Locale(identifier: "fr")
    public let type: ProviderType = .init(.animesultra)
    public let title: String = "Animesultra"
    public let langauge: String = ""
    
  
    public let baseURL: URL = URL(staticString: "https://w2.animesultra.net")
    public var moviesURL: URL = URL(staticString: "https://w2.animesultra.net/anime-vostfr")
    public var tvShowsURL: URL = URL(staticString: "https://w2.animesultra.net/anime-vostfr")
    
    private var homeURL: URL {
        baseURL
    }
    public var categories: [Category] = [
        .init(id: 0, name: "Avant Garde"),
        .init(id: 1, name: "Boys Love"),
        .init(id: 2, name: "Cars"),
        .init(id: 3, name: "Comedy"),
        .init(id: 4, name: "Dementia"),
        .init(id: 5, name: "Demons"),
        .init(id: 6, name: "Drama"),
        .init(id: 7, name: "Ecchi"),
        .init(id: 8, name: "Fantasy"),
        .init(id: 9, name: "Game"),
        .init(id: 10, name: "Girls Love"),
        .init(id: 11, name: "Gourmet"),
        .init(id: 12, name: "Harem"),
        .init(id: 13, name: "Hentai"),
        .init(id: 14, name: "Historical"),
        .init(id: 15, name: "Horror"),
        .init(id: 16, name: "Josei"),
        .init(id: 17, name: "Kids"),
        .init(id: 18, name: "Magic"),
        .init(id: 19, name: "Martial Arts"),
        .init(id: 20, name: "Mecha"),
        .init(id: 21, name: "Military"),
        .init(id: 22, name: "Music"),
        .init(id: 23, name: "Mystery"),
        .init(id: 24, name: "Parody"),
        .init(id: 25, name: "Police"),
        .init(id: 26, name: "Psychological"),
        .init(id: 27, name: "Romance"),
        .init(id: 28, name: "Samurai"),
        .init(id: 29, name: "School"),
        .init(id: 30, name: "Sci-Fi"),
        .init(id: 31, name: "Seinen"),
        .init(id: 32, name: "Shoujo"),
        .init(id: 33, name: "Shoujo Ai"),
        .init(id: 34, name: "Shounen"),
        .init(id: 35, name: "Shounen Ai"),
        .init(id: 36, name: "Slice of Life"),
        .init(id: 37, name: "Space"),
        .init(id: 38, name: "Sports"),
        .init(id: 39, name: "Suspense"),
        .init(id: 40, name: "Super Power"),
        .init(id: 41, name: "Supernatural"),
        .init(id: 42, name: "Thriller"),
        .init(id: 43, name: "Vampire"),
        .init(id: 44, name: "Yaoi"),
        .init(id: 45, name: "Yuri")
    ]
    enum AnimesultraError: Error {
        case invalidURL
        case networkError
        case dataParsingError
        case episodeCountError
        case noepnumbvalue
        case invalidEpisodeData
        case invalidPosterURL
        case invalidSeasonData
         
        // Add more error cases as needed
    }
    
    
    public func parsePage(url: URL) async throws -> [MediaContent] {
        let content = try await Utilities.downloadPage(url: url)
        
        // Check if the content is empty
        guard !content.isEmpty else {
            throw AnimesultraError.dataParsingError
        }
        
        let document = try SwiftSoup.parse(content)
        let rows: Elements = try document.select(".flw-item")
        
        return try rows.array().compactMap { item in
            let posterAnchor = try item.select("a.film-poster-ahref")
            let path: String = try posterAnchor.attr("href")
            guard let webURL = URL(string: path) else {
                throw AnimesultraError.invalidURL
            }
            
            let titleAnchor = try item.select("h3.film-name a.dynamic-name")
            let title: String = try titleAnchor.text().replacingOccurrences(of: "VOSTFR", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            let posterPath: String = try item.select("img.film-poster-img").attr("data-src")
            guard let posterURL = URL(string: posterPath) else {
                throw AnimesultraError.invalidURL
            }
            
            let episodeInfo: String = try item.select("div.tick-item.tick-eps").text()
            let type: MediaContent.MediaContentType = episodeInfo.contains("Ep") ? .tvShow : .movie
            
            return MediaContent(
                title: title,
                webURL: webURL,
                posterURL: posterURL,
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
        throw AnimesultraError.dataParsingError
    }
    
   
   
    public func fetchTVShowDetails(for url: URL) async throws -> TVshow {
        // https://kaido.to/watch/to-heart-5267
        let pageContent = try await Utilities.downloadPage(url: url)
        let pageDocument = try SwiftSoup.parse(pageContent)

        let title = try pageDocument.select("title").text().replacingOccurrences(of: "VOSTFR Streaming  » AnimesUltra", with: "")
        let posterPath = try pageDocument.select("div.film-poster img").attr("src")
                
        let posterURL = baseURL.appendingPathComponent(posterPath)
        let sID = try pageDocument.select("meta[property=og:url]").attr("content").split("/")[4].split("-")[0]
        let id = sID

        // https://zoro.to/ajax/v2/episode/list/18079
        let requestUrl = baseURL.appendingPathComponent("engine/ajax/full-story.php").appending("newsId", value: id)
        let data = try await Utilities.requestData(url: requestUrl)
        let content = try JSONDecoder().decode(Response.self, from: data)
        let document = try SwiftSoup.parse(content.html)
        let rows: Elements = try document.select(".ss-list .ssl-item")
        let episodes = try rows.array().map { row -> Episode in
            let episodeLinks: Elements?
            let episodeUrls: [String]

            if let episodeVo = try? document.select("div[id$=vo]"), !episodeVo.isEmpty {
                episodeLinks = episodeVo
            } else if let episodeFm = try? document.select("div[id$=fm]"), !episodeFm.isEmpty {
                episodeLinks = episodeFm
            } else if let episodeSm = try? document.select("div[id$=se]"), !episodeSm.isEmpty {
                episodeLinks = episodeSm
            } else {
                // Handle the case where no episode links are found
                episodeLinks = nil
            }

            if let episodeLinks = episodeLinks {
                episodeUrls = try episodeLinks.array().map { try $0.text() }
            } else {
                // Handle the case where no episode links were found for any type
                episodeUrls = []
            }

            let number: String = try row.attr("data-number")
            let episodeNumber = Int(number) ?? 1

            // Ensure that episodeNumber is within the bounds of episodeUrls array
            let episodeIndex = max(1, min(episodeNumber, episodeUrls.count))

            let episodeLink = episodeUrls[episodeIndex - 1]
            let url = try URL(episodeLink)
            let source = Source(hostURL: url)
            return Episode(number: episodeNumber, sources: [source])
        }.sorted()
        
        let season = Season(seasonNumber: 1, webURL: url, episodes: episodes)
        return TVshow(title: title, webURL: url, posterURL: posterURL, seasons: [season])
    }


    public func search(keyword: String, page: Int) async throws -> [MediaContent] {
        var components = URLComponents(url: URL(staticString: "https://w2.animesultra.net/index.php?story={searchTerms}&do=search&subaction=search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "searchTerms", value: keyword)
        ]
        
        guard let searchURL = components.url else {
            throw AnimesultraError.invalidURL
        }
        
        return try await parsePage(url: searchURL)
    }
    
    enum MediaType {
        case movie
        case tvShow
    }
    
    public func home() async throws -> [MediaContentSection] {
        do {
            var items = try await parsePage(url: homeURL)
            guard items.count >= 6 else {
                return []
            }
            
            // Create sections based on the HTML structure
            let topViewedDay = MediaContentSection(title: NSLocalizedString("Tendance", comment: ""),
                                                  media: Array(items.prefix(10)))
            items.removeFirst(3)
            
            let topViewedWeek = MediaContentSection(title: NSLocalizedString("Dernier épisode Ajouté", comment: ""),
                                                   media: Array(items.prefix(10)))
            
            let categoriesSection = MediaContentSection(title: "Categories", media: [], categories: categories)
            
            // Return both Categories and Genres sections
            return [topViewedDay, topViewedWeek, categoriesSection]
        } catch {
            throw AnimesultraError.networkError
        }
    }
    
    private struct Response: Codable {
        let html: String
    }
}
