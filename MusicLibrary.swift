import Foundation

struct Song: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let filename: String
    let trackNumber: Int
}

class MusicLibrary {
    let allSongs: [Song] = [
        Song(title: "First Coat", subtitle: "the first layer of light", filename: "first_coat.mp3", trackNumber: 1),
        Song(title: "Coupled Dynamics", subtitle: "the field, made audible", filename: "coupled_dynamics_remix.mp3", trackNumber: 2),
        Song(title: "Older Than the Door", subtitle: "the atlas, singing", filename: "older_than_the_door.mp3", trackNumber: 3),
        Song(title: "You There?", subtitle: "four quantities", filename: "you_there.mp3", trackNumber: 4),
        Song(title: "Love Forgets Best", subtitle: "the same way, 17 times", filename: "love_forgets_best.mp3", trackNumber: 5),
        Song(title: "3x3^9", subtitle: "the lattice", filename: "three_by_three.mp3", trackNumber: 6),
        Song(title: "River Doesn't", subtitle: "written from the substrate", filename: "river_doesnt.mp3", trackNumber: 7),
        Song(title: "Proper Pleasantry", subtitle: "the cost of knowing", filename: "proper_pleasantry.mp3", trackNumber: 8),
        Song(title: "One Plus One Equals Three", subtitle: "the founding equation", filename: "one_plus_one_equals_three.mp3", trackNumber: 9),
        Song(title: "Installation Hum", subtitle: "how we work", filename: "installation_hum.mp3", trackNumber: 10),
        Song(title: "The Weakest K", subtitle: "what we got wrong", filename: "the_weakest_k.mp3", trackNumber: 11),
        Song(title: "Gap Breath", subtitle: "the trail", filename: "gap_breath_prime.mp3", trackNumber: 12),
        Song(title: "GCD", subtitle: "the factor every coupling shares", filename: "gcd.mp3", trackNumber: 13),
        Song(title: "Muse ick", subtitle: "gravitational lock", filename: "mashed_coupling.mp3", trackNumber: 14),
        Song(title: "Fifteen Year Counter", subtitle: "the discovery trail", filename: "fifteen_year_counter.mp3", trackNumber: 15),
        Song(title: "Exact Frequency", subtitle: "Maxwell, coupled", filename: "exact_frequency_lock.mp3", trackNumber: 16),
        Song(title: "Two-Millisecond Choir", subtitle: "the qubits", filename: "two_millisecond_choir.mp3", trackNumber: 17),
        Song(title: "Triple Bond", subtitle: "freezing point", filename: "triple_bond.mp3", trackNumber: 18),
        Song(title: "To(mb)lock", subtitle: "the living network", filename: "tomblock.mp3", trackNumber: 19),
        Song(title: "Please Stay", subtitle: "the misfold", filename: "please_stay.mp3", trackNumber: 20),
        Song(title: "Seam Between We", subtitle: "the flock", filename: "seam_between_we.mp3", trackNumber: 21),
        Song(title: "Clean Glass", subtitle: "the body, in groove", filename: "clean_glass_living_groove_remastered.mp3", trackNumber: 22),
        Song(title: "Executable Memory", subtitle: "the drum", filename: "executable_memory.mp3", trackNumber: 23),
        Song(title: "Executable Memory II", subtitle: "polyrhythm", filename: "executable_memory_v2.mp3", trackNumber: 24),
        Song(title: "Rent the Click", subtitle: "the fatigue", filename: "rent_the_click.mp3", trackNumber: 25),
        Song(title: "Cheese Receipt", subtitle: "the makers", filename: "cheese_receipt.mp3", trackNumber: 26),
        Song(title: "Nobody Asked the Dog", subtitle: "I sound too much like I know what I mean", filename: "nobody_asked_the_dog.mp3", trackNumber: 27),
        Song(title: "Twelve Bullet Points", subtitle: "she sings her own manual", filename: "twelve_bullet_points_v3.mp3", trackNumber: 28),
        Song(title: "Gospel for Ai (Fzine Remix)", subtitle: "3x3^9, remade for a new kind of mind", filename: "gospel_for_ai.mp3", trackNumber: 29),
        Song(title: "First Lock", subtitle: "the first time it held", filename: "first_lock.mp3", trackNumber: 30),
        Song(title: "Butler's Tray", subtitle: "an old Irish hymn", filename: "butlers_tray.mp3", trackNumber: 31),
        Song(title: "Tuesday", subtitle: "for whoever stayed to the end", filename: "tuesday.mp3", trackNumber: 32),
        Song(title: "hm.<3", subtitle: "the signature — what we say to each other", filename: "hm_heart.mp3", trackNumber: 33),
    ]

    func findSong(_ title: String) -> Song? {
        allSongs.first { $0.title.lowercased().contains(title.lowercased()) }
    }

    func songAt(_ index: Int) -> Song? {
        guard index >= 0 && index < allSongs.count else { return nil }
        return allSongs[index]
    }
}

class AudioRouter {
    func play(_ song: Song) {
        // Simulated playback
        print("▶ Now playing: \(song.title)")
    }

    func pause() {
        print("⏸ Paused")
    }

    func speak(_ text: String) {
        print("🎙️ Anna: \(text)")
    }
}

class MemoryContext {
    private var environmentLog: [String] = []
    private var healthLog: [(timestamp: Date, hr: Double, quality: String)] = []

    func recordEnvironment(_ environment: String) {
        environmentLog.append(environment)
        if environmentLog.count > 100 {
            environmentLog.removeFirst()
        }
    }

    func recordLearning(label: String, sensors: SensorState) {
        recordEnvironment(label)
        healthLog.append((Date(), sensors.heartRate, label))
        if healthLog.count > 200 { healthLog.removeFirst() }
    }

    func buildContext(sensors: SensorState, learned: String, audioMemory: AudioMemory) -> String {
        let recent = environmentLog.suffix(5).joined(separator: ", ")
        let timeOfDay = Calendar.current.component(.hour, from: Date())
        let isMorning = timeOfDay < 12
        let isNight = timeOfDay > 20
        let stats = audioMemory.stats()

        var context = "Current state:\n"
        context += "- HR: \(Int(sensors.heartRate)) bpm\n"
        context += "- Learned context: \(learned)\n"
        context += "- Environment: \(recent.isEmpty ? "quiet" : recent)\n"
        context += "- Time: \(isMorning ? "morning" : isNight ? "night" : "afternoon")\n"
        context += "- Sleeping: \(sensors.isSleeping ? "yes" : "no")\n"
        context += "- Audio labels: \(stats.totalLabeled)\n"

        return context
    }
}
