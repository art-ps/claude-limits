import Foundation

struct LimitRow: Sendable {
    /// "session", "weekly_all" or "weekly_scoped" — kept raw so the title can be
    /// localized at render time rather than frozen when the response was parsed.
    let kind: String
    /// Model name for a scoped limit, straight from the API.
    let scopeName: String?
    let percent: Int
    let severity: String
    let resetsAt: Date?
}

enum UsageResult: Sendable {
    case success([LimitRow])
    case failure(String)
}

enum UsageError: LocalizedError {
    case noToken
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .noToken: return L.s.noToken
        case .http(let code): return "HTTP \(code)"
        }
    }
}

enum UsageAPI {
    private static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    static func fetch(completion: @escaping @Sendable (UsageResult) -> Void) {
        guard let token = Credentials.accessToken() else {
            completion(.failure(UsageError.noToken.localizedDescription))
            return
        }

        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 20

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error.localizedDescription))
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200, let data else {
                completion(.failure(UsageError.http(status).localizedDescription))
                return
            }
            do {
                completion(.success(try decode(data)))
            } catch {
                completion(.failure(error.localizedDescription))
            }
        }.resume()
    }

    /// Only the three limits the menu bar shows; every other `kind` is dropped.
    static func decode(_ data: Data) throws -> [LimitRow] {
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let limits = root?["limits"] as? [[String: Any]] ?? []

        return limits.compactMap { entry in
            guard let kind = entry["kind"] as? String,
                  ["session", "weekly_all", "weekly_scoped"].contains(kind),
                  let percent = entry["percent"] as? Double
            else { return nil }

            let scope = entry["scope"] as? [String: Any]
            let model = scope?["model"] as? [String: Any]

            return LimitRow(
                kind: kind,
                scopeName: model?["display_name"] as? String,
                percent: Int(percent.rounded()),
                severity: (entry["severity"] as? String) ?? "normal",
                resetsAt: parseDate(entry["resets_at"] as? String)
            )
        }
    }

    // ponytail: formatters built per call — 3 dates every 5 minutes, caching them
    // would only buy a global-state headache under strict concurrency.
    private static func parseDate(_ string: String?) -> Date? {
        guard let string else { return nil }

        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return withFraction.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }
}
