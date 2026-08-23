import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if os(macOS) || os(Linux)

// MARK: - Grok Bot (Sand) Usage Status

/// Weekly Grok Bot usage, fetched from Cursor's dashboard RPC service.
///
/// The Grok Bot desktop app ("sand") renders its account-menu weekly meter from
/// `POST /aiserver.v1.DashboardService/GetSandUsageStatus` on api2.cursor.sh,
/// authenticated with the same app session token CodexBar already reads from
/// Cursor's global state DB. The RPC accepts an empty JSON body over the
/// connect protocol and returns plain JSON.
public struct CursorGrokBotUsageStatus: Codable, Sendable, Equatable {
    /// Percent of the included weekly pool used (0-100). Omitted proto3 field = 0%.
    public let usagePercent: Double?
    public let currentPeriodStart: String?
    public let nextResetTimestampUtc: String?
    public let hasAvailableUsage: Bool?
    public let hasNonZeroIncludedLimit: Bool?
    public let grokPlanLabel: String?

    public init(
        usagePercent: Double?,
        currentPeriodStart: String?,
        nextResetTimestampUtc: String?,
        hasAvailableUsage: Bool?,
        hasNonZeroIncludedLimit: Bool?,
        grokPlanLabel: String?)
    {
        self.usagePercent = usagePercent
        self.currentPeriodStart = currentPeriodStart
        self.nextResetTimestampUtc = nextResetTimestampUtc
        self.hasAvailableUsage = hasAvailableUsage
        self.hasNonZeroIncludedLimit = hasNonZeroIncludedLimit
        self.grokPlanLabel = grokPlanLabel
    }

    public var resetsAt: Date? {
        Self.parseISO8601(self.nextResetTimestampUtc)
    }

    static func parseISO8601(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }
}

// MARK: - Grok Bot Usage Probe

/// Best-effort fetcher for the Grok Bot weekly usage window.
///
/// Requires the Cursor.app local auth token (Bearer); browser-cookie sessions do not
/// carry it. All failures are contained by the caller — a missing or rejected Grok Bot
/// window must never break the main Cursor snapshot.
public struct CursorGrokBotUsageProbe: Sendable {
    private let baseURL: URL
    private var timeout: TimeInterval
    private let urlSession: any ProviderHTTPTransport

    public init(
        baseURL: URL = URL(string: "https://api2.cursor.sh")!,
        timeout: TimeInterval = 8.0,
        urlSession: any ProviderHTTPTransport = ProviderHTTPClient.shared)
    {
        self.baseURL = baseURL
        self.timeout = timeout
        self.urlSession = urlSession
    }

    /// Fetches the Grok Bot usage status with the given app access token.
    ///
    /// Returns nil on any failure (auth rejection, schema drift, network error) —
    /// the caller renders "no Grok Bot window" instead of a wrong number.
    public func fetch(accessToken: String) async -> CursorGrokBotUsageStatus? {
        let url = self.baseURL.appendingPathComponent(
            "aiserver.v1.DashboardService/GetSandUsageStatus")
        var request = URLRequest(url: url)
        request.timeoutInterval = self.timeout
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)

        do {
            let (data, response) = try await self.urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200
            else {
                return nil
            }
            return try JSONDecoder().decode(CursorGrokBotUsageStatus.self, from: data)
        } catch {
            return nil
        }
    }
}

#endif
