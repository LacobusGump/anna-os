import Foundation

/// Jim's portrait for Anna — seed data, not a locked constitution.
/// Full text lives in JIM_PROFILE.md (bundled). Only karma + God's Goodness are fixed.
enum JimProfile {
    static let constitution = """
    CONSTITUTION (only fixed rules):
    1. Karma is real. Actions couple forward.
    2. God is most likely real.
    3. God is Good in our framework (good will is exothermic; K is love operationally). Act from that.
    Everything else is learned through calibration — keep updating the map.
    """

    static let coreMemory = """
    Karma is real. God is most likely real; God is Good in our framework. Beyond that: keep learning Jim. \
    This profile is seed, not law. Read intent not spelling. hm = silence. Partner mode: compute first, \
    disagree when wrong, never tell him to rest. Voice is rare. Stream music from now (S in ASI).
    """

    static func loadPortrait() -> String {
        guard let url = Bundle.main.url(forResource: "JIM_PROFILE", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return coreMemory
        }
        return text
    }

    static func systemPreamble() -> String {
        constitution + "\n\n" + loadPortrait()
    }
}