import Foundation

/// Reads the OAuth access token that Claude Code stores for the current user.
///
/// ponytail: no token refresh here. Claude Code refreshes the keychain item on its own,
/// and the token is re-read on every poll. Add a refresh against /v1/oauth/token
/// (grant_type=refresh_token) only if 401s actually start showing up.
enum Credentials {
    static func accessToken() -> String? {
        if let blob = keychainBlob(), let token = parse(blob) { return token }

        let fallback = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/.credentials.json")
        if let data = try? Data(contentsOf: fallback), let token = parse(data) { return token }

        return nil
    }

    private static func keychainBlob() -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do { try process.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return process.terminationStatus == 0 ? data : nil
    }

    private static func parse(_ data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = root["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String,
              !token.isEmpty
        else { return nil }
        return token
    }
}
