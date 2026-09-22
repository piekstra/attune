import Foundation

/// The app's single, opt-in network call: when a break timer ends, POST a
/// short "head back" message to a URL the user configured. Off unless the
/// URL is set; the request is fully visible below.
///
/// Designed around ntfy (https://ntfy.sh) — the free, open-source push
/// relay whose Android app makes this the Android answer — but any HTTP
/// endpoint works: Home Assistant webhooks, Pushover bridges, a shell
/// script behind a local server. The `Title`/`Tags` headers are ntfy
/// conventions that other receivers simply ignore.
public enum WebhookNotifier {

    public static func makeRequest(url: URL, message: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Break timer done", forHTTPHeaderField: "Title")
        request.setValue("bell", forHTTPHeaderField: "Tags")
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = message.data(using: .utf8)
        request.timeoutInterval = 10
        return request
    }

    /// Validated URL from the settings string; nil disables the feature.
    public static func validatedURL(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              url.host() != nil
        else { return nil }
        return url
    }

    /// Fire-and-forget send. A failed ping must never interrupt the user's
    /// break, so errors are logged and swallowed.
    public static func sendBreakEnded(
        urlString: String,
        breakLabel: String,
        session: URLSession = .shared
    ) {
        guard let url = validatedURL(from: urlString) else { return }
        let message = "Timer's up — head back 🔔 (\(breakLabel))"
        let task = session.dataTask(with: makeRequest(url: url, message: message)) { _, response, error in
            if let error {
                NSLog("Attune: webhook ping failed: \(error.localizedDescription)")
            } else if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                NSLog("Attune: webhook endpoint returned \(http.statusCode)")
            }
        }
        task.resume()
    }
}
