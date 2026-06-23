import Foundation

final class ClaudeAPI {
    private let baseURL = "https://api.anthropic.com/v1"
    private let model = "claude-sonnet-4-20250514"

    func askClaude(context: String, apiKey: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard !apiKey.isEmpty else {
            completion(.failure(ClaudeError.missingKey))
            return
        }

        var request = URLRequest(url: URL(string: "\(baseURL)/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 60

        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [["role": "user", "content": context]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(ClaudeError.badResponse))
                return
            }
            if let errorObj = json["error"] as? [String: Any],
               let message = errorObj["message"] as? String {
                completion(.failure(ClaudeError.api(message)))
                return
            }
            if let content = json["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String {
                completion(.success(text))
            } else {
                completion(.failure(ClaudeError.badResponse))
            }
        }.resume()
    }
}

enum ClaudeError: LocalizedError {
    case missingKey
    case badResponse
    case api(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: return "Claude API key not set. Open Anna on iPhone and add your key."
        case .badResponse: return "Unexpected response from Claude."
        case .api(let msg): return msg
        }
    }
}