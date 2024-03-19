import Foundation
import SwiftSoup
import TMDb

public class TMDBProvider: Provider {
    public var type: ProviderType = .local(id: .tmdb)
    public var title: String = "TMDB"
    public let langauge: String = ""
    public var subtitle: String = "English content"
    public var moviesURL: URL = URL(staticString: "https://api.themoviedb.org/3/discover/movie/")
    public var tvShowsURL: URL = URL(staticString: "https://api.themoviedb.org/3/discover/tv/")

    public var homeURL: URL = URL(staticString: "https://api.themoviedb.org")

    var imagesConfiguration: ImagesConfiguration?
    public var categories: [Category] = [
        .init(id: 8, name: "Netflix", poster: .init(staticString: "https://image.tmdb.org/t/p/w300/wwemzKWzjKYJFfCeiB57q3r4Bcm.png")),
        .init(id: 350, name: "Apple TV+", poster: .init(staticString: "https://image.tmdb.org/t/p/w300_filter(negate,000,666)/4KAy34EHvRM25Ih8wb82AuGU7zJ.png")),
        .init(id: 337, name: "Disney+", poster: .init(staticString: "https://www.themoviedb.org/t/p/w300/uzKjVDmQ1WRMvGBb7UNRE0wTn1H.png")),
        .init(id: 9, name: "Amazon Prime", poster: .init(staticString: "https://www.themoviedb.org/t/p/w300/ifhbNuuVnlwYy5oXA5VIb2YR8AZ.png")),
        .init(id: 15, name: "Hulu", poster: .init(staticString: "https://image.tmdb.org/t/p/w300/pqUTCleNUiTLAVlelGxUgWn1ELh.png")),
        .init(id: 1899, name: "MAX", poster: .init(staticString: "https://www.themoviedb.org/t/p/w300_filter(negate,000,666)/rAb4M1LjGpWASxpk6Va791A7Nkw.png")),
        .init(id: 531, name: "Paramount", poster: .init(staticString: "https://www.themoviedb.org/t/p/w300/fi83B1oztoS47xxcemFdPMhIzK.png")),
        .init(id: 43, name: "Starz", poster: .init(staticString: "https://www.themoviedb.org/t/p/w300/GMDGZk9iDG4WDijY3VgUgJeyus.png")),
        .init(id: 37, name: "Showtime", poster: .init(staticString: "https://www.themoviedb.org/t/p/w300/Allse9kbjiP6ExaQrnSpIhkurEi.png")),
        .init(id: 386, name: "Peacock", poster: .init(staticString: "https://www.themoviedb.org/t/p/w300/gIAcGTjKKr0KOHL5s4O36roJ8p7.png")),
        .init(id: 520, name: "Discovery+", poster: .init(staticString: "https://www.themoviedb.org/t/p/w300/1D1bS3Dyw4ScYnFWTlBOvJXC3nb.png")),
        .init(id: 34, name: "MGM+", poster: .init(staticString: "https://www.themoviedb.org/t/p/w300/89TXvQzvoKvyqD9EEogohzMJ8D6.png")),
        //anime providers//cartoon
        .init(id: 283, name: "Crunchyroll", poster: .init(staticString: "https://www.themoviedb.org/t/p/w300/81QfupgVijSH5v1H3VUbdlPm2r8.png")),
        .init(id: 318, name: "Adult Swim", poster: .init(staticString: "https://www.themoviedb.org/t/p/w300/tHZPHOLc6iF27G34cAZGPsMtMSy.png")),
        .init(id: 34, name: "Boomerang", poster: .init(staticString: "https://www.themoviedb.org/t/p/w300/lkMfZclFXosrByxWf459NrXBiRY.png")),
    ]
    enum TMDBProvider: Error {
        case missingPoster
    }

    public func convertMovieTMDBToIMDB(tmdb: Int) async throws -> String? {
        if imagesConfiguration == nil {
            try await setupImagesConfiguration()
        }
        let movieService = MovieService()
        return try await movieService.externalIDs(forMovie: tmdb).imdbId

    }

    public func convertTVTMDBToIMDB(tmdb: Int) async throws -> String? {
        if imagesConfiguration == nil {
            try await setupImagesConfiguration()
        }
        let movieService = TVSeriesService()
        return try await movieService.externalIDs(forTVSeries: tmdb).imdbId
    }

    public init() {
        let tmdbConfiguration = TMDbConfiguration(apiKey: Constants.TMDbAPIKey)
        TMDB.configure(tmdbConfiguration)
    }

    func setupImagesConfiguration() async throws {
        let configurationService = ConfigurationService()
        let apiConfiguration = try await configurationService.apiConfiguration()
        self.imagesConfiguration = apiConfiguration.images
    }

    public func parsePage(url: URL) async throws -> [MediaContent] {
        return []
    }

    public func latestCategory(id: Int, page: Int) async throws -> [MediaContent] {
        if imagesConfiguration == nil {
            try await setupImagesConfiguration()
        }
        guard let category = categories.first(where: { $0.id == id }) else {
            return []
        }
        let discoverService = DiscoverService()
        let shows =  try await discoverService.tvSeries(sortedBy: .popularity(descending: true), page: page, withWatchProviders: category.id, watchRegion: "US").results.compactMap { convert($0)}
        let movies =  try await discoverService.movies(sortedBy: .popularity(descending: true), page: page, withWatchProviders: category.id, watchRegion: "US").results.compactMap { convert($0)}
        return (movies + shows).shuffled()
    }

    public func latestMovies(page: Int) async throws -> [MediaContent] {
        if imagesConfiguration == nil {
            try await setupImagesConfiguration()
        }
        let movieService = MovieService()
        return try await movieService.popular(page: page).results.compactMap { movie -> MediaContent? in
            return convert(movie)
        }
    }

    public func latestTVShows(page: Int) async throws -> [MediaContent] {
        if imagesConfiguration == nil {
            try await setupImagesConfiguration()
        }

        let tvSeriesService = TVSeriesService()
        return try await tvSeriesService.popular(page: page).results.compactMap { tvseries -> MediaContent? in
            return convert(tvseries)
        }
    }

    public func fetchMovieDetails(for url: URL) async throws -> Movie {
        if imagesConfiguration == nil {
            try await setupImagesConfiguration()
        }
        let id = Int(url.lastPathComponent) ?? 0

        let movieService = MovieService()
        let response = try await movieService.details(forMovie: id)
        guard let posterURL = imagesConfiguration?.posterURL(for: response.posterPath) else {
            throw TMDBProvider.missingPoster
        }

        var year: Int?

        if let releaseDate = response.releaseDate {
            let calendarDate = Calendar.current.dateComponents([ .year], from: releaseDate)
            year = calendarDate.year
        }

        return Movie(
            title: response.title,
            webURL: url,
            posterURL: posterURL,
            year: year,
            sources: Self.generateSourcesFor(movieID: id)
        )
    }

    public func fetchTVShowDetails(for url: URL) async throws -> TVshow {
        if imagesConfiguration == nil {
            try await setupImagesConfiguration()
        }

        let id = Int(url.lastPathComponent) ?? 0

        let tvSeriesService = TVSeriesService()
        let tvSeasonService = TVSeasonService()

        let response = try await tvSeriesService.details(forTVSeries: id)

        let seasons = try await response.seasons?.concurrentMap { season -> Season? in
            let updatedSeason = try? await tvSeasonService.details(forSeason: season.seasonNumber, inTVSeries: id)
            let episodes = updatedSeason?.episodes?.compactMap { episode -> Episode? in
                let sources = Self.generateSourcesFor(tvShowID: id, seasonNumber: episode.seasonNumber, episodeNumber: episode.episodeNumber)
                return Episode(number: episode.episodeNumber, sources: sources)
            }
            return Season(seasonNumber: season.seasonNumber, webURL: url, episodes: episodes)
        }
            .compactMap { $0 }
            .filter { ($0.episodes?.count ?? 0) != 0 }

        guard let posterURL = imagesConfiguration?.posterURL(for: response.posterPath) else {
            throw TMDBProvider.missingPoster
        }
        var year: Int?
        if let releaseDate = response.firstAirDate {
            let calendarDate = Calendar.current.dateComponents([ .year], from: releaseDate)
            year = calendarDate.year
        }

        return TVshow(title: response.name, webURL: url, posterURL: posterURL, year: year, seasons: seasons)
    }

    public func search(keyword: String, page: Int) async throws -> [MediaContent] {
        if imagesConfiguration == nil {
            try await setupImagesConfiguration()
        }

        let searchService = SearchService()
        let response = try await searchService.searchAll(query: keyword)

        return response.results.compactMap { media -> MediaContent? in

            switch media {
            case .movie(let movie):
                return convert(movie)
            case .tvSeries(let tvseries):
                return convert(tvseries)
            case .person:
                return nil

            }

        }
    }

    public func home() async throws -> [MediaContentSection] {
        if imagesConfiguration == nil {
            try await setupImagesConfiguration()
        }

        let trendingService = TrendingService()
        let tendingMoviesWeek = try await trendingService.movies(inTimeWindow: .week).results.compactMap { convert($0)}
        let tendingMoviesDay = try await trendingService.movies(inTimeWindow: .day).results.compactMap { convert($0)}

        let tendingTvSeriesWeek = try await trendingService.tvSeries(inTimeWindow: .week).results.compactMap { convert($0)}
        let tendingTvSeriesDay = try await trendingService.tvSeries(inTimeWindow: .day).results.compactMap { convert($0)}
        var mediaSections =  [
            MediaContentSection(title: "Trending Movies Today", media: tendingMoviesDay),
            MediaContentSection(title: "Trending Movies This Week", media: tendingMoviesWeek),
            MediaContentSection(title: "Trending TV Shows Today", media: tendingTvSeriesDay),
            MediaContentSection(title: "Trending TV Shows This Week", media: tendingTvSeriesWeek),
            MediaContentSection(title: "Popular Networks", media: [], categories: categories)
        ]

        return mediaSections
    }

    public static func generateSourcesFor(movieID: Int) -> [Source] {
        // https://us-west2-compute-proxied.streamflix.one/player?id=472054
        let embedURL = URL(staticString: "https://us-west2-compute-proxied.streamflix.one/api/player/movies").appendingQueryItem(name: "id", value: movieID)
        // https://api.9animetv.live/movie/884605
        let animetv = URL(staticString: "https://api.9animetv.live/movie").appendingPathComponent(movieID)
        let vidsrcURL = URL(staticString: "https://v2.vidsrc.me/embed/").appendingPathComponent(movieID)
        let databasegdriveplayerURL = URL(staticString: "https://databasegdriveplayer.xyz/player.php").appendingQueryItem(name: "tmdb", value: movieID)
        // https://myfilestorage.xyz/453395.mp4
        let myfilestorageURL = URL(staticString: "https://myfilestorage.xyz").appendingPathComponent("\(movieID).mp4")
        @EnviromentValue(key: "showbox_url", defaultValue: URL(staticString: "https://google.com/"))
        var movieboxprovider_url
        let superStreamURL = movieboxprovider_url.appendingPathComponent("tmdb/movie/").appendingPathComponent(movieID)

        return [
            //            .init(hostURL: superStreamURL),
            //            .init(hostURL: embedURL),
            //            .init(hostURL: animetv),
            //            .init(hostURL: vidsrcURL),
            //            .init(hostURL: databasegdriveplayerURL),
            //            .init(hostURL: myfilestorageURL)
        ]
    }

    public static func generateSourcesFor(tvShowID: Int, seasonNumber: Int, episodeNumber: Int) -> [Source] {
        let embedURL = URL(staticString: "https://us-west2-compute-proxied.streamflix.one/api/player/tv")
            .appendingQueryItem(name: "id", value: tvShowID)
            .appendingQueryItem(name: "s", value: seasonNumber)
            .appendingQueryItem(name: "e", value: episodeNumber)

        let animetv = URL(staticString: "https://api.9animetv.live/tv")
            .appendingPathComponent("\(tvShowID)-\(seasonNumber)-\(episodeNumber)" )

        let vidsrcURL = URL(staticString: "https://v2.vidsrc.me/embed/").appendingPathComponent(tvShowID).appendingPathComponent("\(seasonNumber)-\(episodeNumber)")
        let databasegdriveplayerURL = URL(staticString: "https://databasegdriveplayer.xyz/player.php?type=series")
            .appendingQueryItem(name: "tmdb", value: tvShowID)
            .appendingQueryItem(name: "season", value: seasonNumber)
            .appendingQueryItem(name: "episode", value: episodeNumber)
        @EnviromentValue(key: "showbox_url", defaultValue: URL(staticString: "https://google.com/"))
        var movieboxprovider_url
        let superStreamURL = movieboxprovider_url.appendingPathComponent("tmdb/tv/")
            .appendingPathComponent(tvShowID)
            .appendingPathComponent(seasonNumber)
            .appendingPathComponent(episodeNumber)

        return [
            //            .init(hostURL: superStreamURL),
            //            .init(hostURL: embedURL),
            //            .init(hostURL: animetv),
            //            .init(hostURL: vidsrcURL),
            //            .init(hostURL: databasegdriveplayerURL)
        ]
    }
}
