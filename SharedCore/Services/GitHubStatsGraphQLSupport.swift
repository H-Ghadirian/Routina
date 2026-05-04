import Foundation

func fetchViewerLogin(accessToken: String) async throws -> String {
    let payload: GitHubViewerLoginPayload = try await decodeGitHubGraphQLResponse(
        query: """
        query ViewerLogin {
          viewer {
            login
          }
        }
        """,
        variables: [:],
        accessToken: accessToken
    )
    return payload.viewer.login
}

func decodeGitHubGraphQLResponse<T: Decodable>(
    query: String,
    variables: [String: String],
    accessToken: String
) async throws -> T {
    guard let url = URL(string: "https://api.github.com/graphql") else {
        throw GitHubStatsError.invalidResponse
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
    request.setValue("Routina", forHTTPHeaderField: "User-Agent")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.httpBody = try JSONEncoder().encode(
        GitHubGraphQLRequest(query: query, variables: variables)
    )

    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubStatsError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            let payload = try makeGitHubDecoder().decode(GitHubGraphQLResponse<T>.self, from: data)
            if let errors = payload.errors, let firstError = errors.first {
                throw mapGitHubGraphQLError(firstError.message)
            }
            guard let value = payload.data else {
                throw GitHubStatsError.invalidResponse
            }
            return value
        case 401 where httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0":
            throw GitHubStatsError.rateLimited
        case 403 where httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0":
            throw GitHubStatsError.rateLimited
        case 401:
            throw GitHubStatsError.unauthorized
        case 403:
            throw GitHubStatsError.rateLimited
        default:
            throw GitHubStatsError.invalidResponse
        }
    } catch let error as GitHubStatsError {
        throw error
    } catch {
        throw GitHubStatsError.networkFailure(error.localizedDescription)
    }
}

func mapGitHubGraphQLError(_ message: String) -> GitHubStatsError {
    let lowered = message.lowercased()
    if lowered.contains("rate limit") {
        return .rateLimited
    }
    if lowered.contains("bad credentials")
        || lowered.contains("requires authentication")
        || lowered.contains("resource not accessible")
    {
        return .unauthorized
    }
    return .networkFailure(message)
}
