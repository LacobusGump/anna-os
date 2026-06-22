import Foundation

class ClaudeAPI {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1"
    private let model = "claude-opus-4-8"

    init() {
        // Get from environment or use placeholder
        self.apiKey = ProcessInfo.processInfo.environment["CLAUDE_API_KEY"] ?? ""
    }

    func askClaude(context: String, completion: @escaping (String) -> Void) {
        guard !apiKey.isEmpty else {
            completion("Claude API key not set. Set CLAUDE_API_KEY environment variable.")
            return
        }

        let url = URL(string: "\(baseURL)/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [
                [
                    "role": "user",
                    "content": context
                ]
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion("Error: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                completion("No response from Claude")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let content = json["content"] as? [[String: Any]],
                   let textBlock = content.first as? [String: Any],
                   let text = textBlock["text"] as? String {
                    completion(text)
                } else {
                    completion("Unexpected response format")
                }
            } catch {
                completion("Failed to parse response: \(error)")
            }
        }.resume()
    }
}
