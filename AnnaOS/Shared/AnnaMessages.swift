import Foundation

enum AnnaMessageType: String, Codable {
    case askClaude
    case claudeResponse
    case speak
    case playMusic
    case pauseMusic
    case skipMusic
    case musicState
    case phoneStatus
    case syncMemory
    case syncLifeMemory
    case error
}

struct AnnaMessage: Codable {
    let type: AnnaMessageType
    let payload: String
    let context: String?
    let userUtterance: String?
    let songTitle: String?
    let isPlaying: Bool?

    init(
        type: AnnaMessageType,
        payload: String = "",
        context: String? = nil,
        userUtterance: String? = nil,
        songTitle: String? = nil,
        isPlaying: Bool? = nil
    ) {
        self.type = type
        self.payload = payload
        self.context = context
        self.userUtterance = userUtterance
        self.songTitle = songTitle
        self.isPlaying = isPlaying
    }

    func encoded() -> [String: Any] {
        guard let data = try? JSONEncoder().encode(self),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ["type": type.rawValue, "payload": payload]
        }
        return dict
    }

    static func decode(from dict: [String: Any]) -> AnnaMessage? {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let message = try? JSONDecoder().decode(AnnaMessage.self, from: data) else {
            return nil
        }
        return message
    }
}