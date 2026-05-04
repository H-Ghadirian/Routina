import Foundation

struct GitHubResponseMetadata: Sendable {
    let hasNextPage: Bool
}

func decodeGitHubResponse<T: Decodable>(
    components: URLComponents,
    accessToken: String?,
    decoder: JSONDecoder = makeGitHubDecoder()
) async throws -> T {
    let (value, _) = try await decodeGitHubResponseWithMetadata(
        components: components,
        accessToken: accessToken,
        as: T.self,
        decoder: decoder
    )
    return value
}

func decodeGitHubResponseWithMetadata<T: Decodable>(
    components: URLComponents,
    accessToken: String?,
    as type: T.Type,
    decoder: JSONDecoder = makeGitHubDecoder()
) async throws -> (T, GitHubResponseMetadata) {
    guard let url = components.url else {
        throw GitHubStatsError.invalidResponse
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
    request.setValue("Routina", forHTTPHeaderField: "User-Agent")
    if let accessToken, !accessToken.isEmpty {
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }

    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubStatsError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            let value = try decoder.decode(type, from: data)
            let linkHeader = httpResponse.value(forHTTPHeaderField: "Link") ?? ""
            return (
                value,
                GitHubResponseMetadata(hasNextPage: linkHeader.contains("rel=\"next\""))
            )
        case 401 where httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0":
            throw GitHubStatsError.rateLimited
        case 403 where httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0":
            throw GitHubStatsError.rateLimited
        case 401:
            throw GitHubStatsError.unauthorized
        case 403:
            throw GitHubStatsError.rateLimited
        case 404:
            throw GitHubStatsError.repositoryNotFound
        default:
            throw GitHubStatsError.invalidResponse
        }
    } catch let error as GitHubStatsError {
        throw error
    } catch {
        throw GitHubStatsError.networkFailure(error.localizedDescription)
    }
}

func makeGitHubDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}

func makeGitHubComponents(path: String) -> URLComponents {
    var components = URLComponents()
    components.scheme = "https"
    components.host = "api.github.com"
    components.path = path
    return components
}
