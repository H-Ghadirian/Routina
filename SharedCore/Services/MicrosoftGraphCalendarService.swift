import AuthenticationServices
import CryptoKit
import Foundation
import Security

#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum MicrosoftGraphCalendarError: Error, Equatable {
    case notConfigured
    case signInCanceled
    case invalidCallback
    case tokenExchangeFailed
    case eventsFetchFailed
}

struct MicrosoftGraphAccount: Equatable {
    let displayName: String
    let email: String?
}

struct MicrosoftGraphSignInResult: Equatable {
    let accessToken: String
    let account: MicrosoftGraphAccount?
}

@MainActor
final class MicrosoftGraphCalendarService: NSObject, ASWebAuthenticationPresentationContextProviding {
    private let callbackScheme = "routina"
    private let redirectURI = "routina://auth/microsoft"
    private var authSession: ASWebAuthenticationSession?

    func signIn() async throws -> MicrosoftGraphSignInResult {
        let clientID = Self.configuredClientID()
        guard !clientID.isEmpty else {
            throw MicrosoftGraphCalendarError.notConfigured
        }

        let verifier = Self.randomString()
        let challenge = Self.codeChallenge(for: verifier)
        let state = Self.randomString()
        var components = URLComponents(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_mode", value: "query"),
            URLQueryItem(name: "scope", value: "offline_access User.Read Calendars.Read"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]
        guard let authURL = components?.url else {
            throw MicrosoftGraphCalendarError.invalidCallback
        }

        let callbackURL = try await authenticate(with: authURL)
        guard let callbackComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              callbackComponents.queryItems?.first(where: { $0.name == "state" })?.value == state,
              let code = callbackComponents.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw MicrosoftGraphCalendarError.invalidCallback
        }

        let token = try await exchangeCode(
            code,
            verifier: verifier,
            clientID: clientID
        )
        let account = try? await account(accessToken: token.accessToken)
        return MicrosoftGraphSignInResult(accessToken: token.accessToken, account: account)
    }

    func suggestions(
        accessToken: String,
        from startDate: Date,
        through endDate: Date,
        existingTasks: [RoutineTask],
        calendar: Calendar
    ) async throws -> [CalendarTaskSuggestion] {
        let existingMarkers = CalendarTaskImportSupport.existingSourceMarkers(in: existingTasks)
        let events = try await events(accessToken: accessToken, from: startDate, through: endDate)
        return events.map { event in
            let markerID = "outlook:\(event.id)"
            let marker = "Calendar event: \(markerID)"
            let deadline = event.isAllDay ? calendar.startOfDay(for: event.startDate) : event.startDate
            return CalendarTaskSuggestion(
                id: markerID,
                eventIdentifier: markerID,
                calendarIdentifier: "outlook",
                calendarTitle: "Outlook",
                eventTitle: event.subject,
                eventStartDate: event.startDate,
                eventEndDate: event.endDate,
                isAllDay: event.isAllDay,
                taskTitle: CalendarTaskImportSupport.defaultTaskTitle(for: event.subject),
                deadline: deadline,
                reviewState: existingMarkers.contains(marker) ? .duplicate : .pending
            )
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(macOS)
        return NSApplication.shared.windows.first ?? ASPresentationAnchor()
        #else
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        if let window = windowScenes.flatMap(\.windows).first(where: { $0.isKeyWindow }) {
            return window
        }
        if let windowScene = windowScenes.first {
            return ASPresentationAnchor(windowScene: windowScene)
        }
        preconditionFailure("Microsoft sign in requires an active window scene.")
        #endif
    }

    private func authenticate(with url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackScheme
            ) { callbackURL, error in
                self.authSession = nil
                if error != nil {
                    continuation.resume(throwing: MicrosoftGraphCalendarError.signInCanceled)
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: MicrosoftGraphCalendarError.invalidCallback)
                    return
                }
                continuation.resume(returning: callbackURL)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            authSession = session
            session.start()
        }
    }

    private func exchangeCode(
        _ code: String,
        verifier: String,
        clientID: String
    ) async throws -> TokenResponse {
        guard let url = URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token") else {
            throw MicrosoftGraphCalendarError.tokenExchangeFailed
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formBody([
            "client_id": clientID,
            "scope": "offline_access User.Read Calendars.Read",
            "code": code,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": verifier,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let token = try? JSONDecoder().decode(TokenResponse.self, from: data) else {
            throw MicrosoftGraphCalendarError.tokenExchangeFailed
        }
        return token
    }

    private func account(accessToken: String) async throws -> MicrosoftGraphAccount {
        guard let url = URL(string: "https://graph.microsoft.com/v1.0/me?$select=displayName,mail,userPrincipalName") else {
            throw MicrosoftGraphCalendarError.eventsFetchFailed
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let user = try? JSONDecoder().decode(GraphUser.self, from: data) else {
            throw MicrosoftGraphCalendarError.eventsFetchFailed
        }
        return MicrosoftGraphAccount(
            displayName: user.displayName,
            email: user.mail ?? user.userPrincipalName
        )
    }

    private func events(
        accessToken: String,
        from startDate: Date,
        through endDate: Date
    ) async throws -> [GraphCalendarEvent] {
        var components = URLComponents(string: "https://graph.microsoft.com/v1.0/me/calendarView")
        components?.queryItems = [
            URLQueryItem(name: "startDateTime", value: Self.graphDateFormatter.string(from: startDate)),
            URLQueryItem(name: "endDateTime", value: Self.graphDateFormatter.string(from: endDate)),
            URLQueryItem(name: "$orderby", value: "start/dateTime"),
            URLQueryItem(name: "$top", value: "50"),
        ]
        guard let url = components?.url else {
            throw MicrosoftGraphCalendarError.eventsFetchFailed
        }

        var allEvents: [GraphCalendarEvent] = []
        var nextURL: URL? = url
        while let pageURL = nextURL {
            var request = URLRequest(url: pageURL)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("outlook.timezone=\"UTC\"", forHTTPHeaderField: "Prefer")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let page = try? JSONDecoder().decode(GraphCalendarEventPage.self, from: data) else {
                throw MicrosoftGraphCalendarError.eventsFetchFailed
            }
            allEvents.append(contentsOf: page.value.compactMap(Self.suggestionEvent(from:)))
            nextURL = page.nextLink.flatMap(URL.init(string:))
        }
        return allEvents.sorted {
            if $0.startDate == $1.startDate {
                return $0.subject.localizedCaseInsensitiveCompare($1.subject) == .orderedAscending
            }
            return $0.startDate < $1.startDate
        }
    }

    private static func suggestionEvent(from event: GraphEventResponse) -> GraphCalendarEvent? {
        let subject = event.subject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subject.isEmpty,
              let startDate = parseGraphDate(event.start.dateTime),
              let endDate = parseGraphDate(event.end.dateTime) else {
            return nil
        }
        return GraphCalendarEvent(
            id: event.id,
            subject: subject,
            startDate: startDate,
            endDate: endDate,
            isAllDay: event.isAllDay
        )
    }

    private static func parseGraphDate(_ value: String) -> Date? {
        for formatter in graphDateParsers {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return ISO8601DateFormatter().date(from: value)
    }

    private static func configuredClientID() -> String {
        (Bundle.main.object(forInfoDictionaryKey: "RoutinaMicrosoftGraphClientID") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private static func randomString() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private static func codeChallenge(for verifier: String) -> String {
        let data = Data(verifier.utf8)
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncodedString()
    }

    private static func formBody(_ values: [String: String]) -> Data {
        values
            .map { key, value in
                "\(key)=\(Self.percentEncoded(value))"
            }
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }

    private static func percentEncoded(_ value: String) -> String {
        var allowedCharacters = CharacterSet.urlQueryAllowed
        allowedCharacters.remove(charactersIn: "&+=?")
        return value.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? value
    }

    private static let graphDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static let graphDateParsers: [DateFormatter] = {
        ["yyyy-MM-dd'T'HH:mm:ss.SSSSSSS", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss.SSS"].map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            return formatter
        }
    }()
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
    }
}

private struct GraphUser: Decodable {
    let displayName: String
    let mail: String?
    let userPrincipalName: String?
}

private struct GraphCalendarEvent {
    let id: String
    let subject: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
}

private struct GraphCalendarEventPage: Decodable {
    let value: [GraphEventResponse]
    let nextLink: String?

    private enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}

private struct GraphEventResponse: Decodable {
    let id: String
    let subject: String
    let isAllDay: Bool
    let start: GraphDateTime
    let end: GraphDateTime
}

private struct GraphDateTime: Decodable {
    let dateTime: String
}
