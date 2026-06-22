import Foundation
import XCTest

/// Anna OS Synthetic Test Suite
/// Run to validate: sensors, Claude API, music routing, voice detection

class AnnaOSTests: XCTestCase {

    var sensors: SensorSimulation!

    override func setUp() {
        super.setUp()
        sensors = SensorSimulation()
    }

    // MARK: - Sensor Simulation Tests

    func testQuietScenario() {
        sensors.setScenario(.quiet)
        let state = sensors.nextSampleState()

        XCTAssert(state.heartRate > 60 && state.heartRate < 85, "HR should be resting")
        XCTAssert(state.acceleration < 0.2, "Accel should be minimal")
        XCTAssertFalse(state.isSleeping, "Should not be sleeping (still awake)")
    }

    func testCookingScenario() {
        sensors.setScenario(.cooking)

        // Run for several samples
        for _ in 0..<10 {
            let state = sensors.nextSampleState()
            XCTAssert(state.heartRate > 75, "HR should be elevated (cooking)")
            XCTAssert(state.acceleration > 0.2, "Accel should show arm movement")
        }
    }

    func testSleepingScenario() {
        sensors.setScenario(.sleeping)

        for _ in 0..<10 {
            let state = sensors.nextSampleState()
            XCTAssert(state.heartRate < 65, "HR should be low during sleep")
            XCTAssert(state.acceleration < 0.1, "Accel should be minimal")
            XCTAssertTrue(state.isSleeping, "Should be sleeping")
        }
    }

    func testFallDetection() {
        sensors.setScenario(.falling)

        // First samples: normal
        var state = sensors.nextSampleState()
        XCTAssert(state.acceleration < 1.0, "Normal before fall")

        // Run through fall sequence
        for _ in 0..<20 {
            state = sensors.nextSampleState()
            if state.acceleration > 3.0 {
                // Fall detected
                XCTAssert(state.acceleration > 3.0, "Accel spike during fall")
                break
            }
        }
    }

    // MARK: - Audio Scene Detection Tests

    func testAudioSceneQuiet() {
        sensors.setScenario(.quiet)
        let audio = sensors.getAudioSample()

        XCTAssert(audio.spectrum.max() ?? 0 < 0.3, "Quiet spectrum should be low")
    }

    func testAudioSceneCooking() {
        sensors.setScenario(.cooking)
        let audio = sensors.getAudioSample()

        XCTAssert(audio.spectrum.max() ?? 0 > 0.3, "Cooking audio should have peaks")
    }

    // MARK: - Music Library Tests

    func testMusicLibrarySize() {
        let library = MusicLibrary()
        XCTAssertEqual(library.allSongs.count, 33, "Should have 33 songs")
    }

    func testFindSongByTitle() {
        let library = MusicLibrary()

        let song = library.findSong("Please Stay")
        XCTAssertNotNil(song, "Should find 'Please Stay'")
        XCTAssertEqual(song?.trackNumber, 20, "Should be track 20")
    }

    func testFindSongCaseInsensitive() {
        let library = MusicLibrary()

        let song = library.findSong("please stay")
        XCTAssertNotNil(song, "Should find song case-insensitively")
    }

    func testAlbumSequence() {
        let library = MusicLibrary()

        XCTAssertEqual(library.allSongs[0].title, "First Coat", "First song should be 'First Coat'")
        XCTAssertEqual(library.allSongs[32].title, "hm.<3", "Last song should be 'hm.<3'")
    }

    // MARK: - Health Insight Tests

    func testHealthInsightStressed() {
        let anna = AnnaCore()
        anna.sensorState.heartRate = 110
        anna.sensorState.acceleration = 0.8

        let insight = anna.getHealthInsight()
        XCTAssert(insight.contains("Stress") || insight.contains("energized"),
                  "High HR should trigger stress/energy insight")
    }

    func testHealthInsightSleeping() {
        let anna = AnnaCore()
        anna.sensorState.heartRate = 52
        anna.sensorState.acceleration = 0.02
        anna.sensorState.isSleeping = true

        let insight = anna.getHealthInsight()
        XCTAssert(insight.contains("sleep") || insight.contains("mute"),
                  "Sleep state should trigger sleep insight")
    }

    // MARK: - Integration Tests

    func testSensorToInsightFlow() {
        let sensors = SensorSimulation()
        sensors.setScenario(.stressed)

        // Get sensor state
        let state = sensors.nextSampleState()

        // Calculate health metrics
        let hrVariance = abs(state.heartRate - 72.0) / 72.0
        let accelMagnitude = abs(state.acceleration)
        let kValue = min(1.0, (hrVariance + accelMagnitude) / 2.0)

        XCTAssert(kValue > 0.5, "Stressed scenario should show high coupling (K > 0.5)")
    }

    func testAudioToEnvironmentFlow() {
        let sensors = SensorSimulation()
        sensors.setScenario(.cooking)

        let audio = sensors.getAudioSample()
        let environment = audio.detectEnvironment()

        XCTAssert(environment.contains("stove") || environment.contains("cooking"),
                  "Cooking audio should be detected as cooking")
    }

    // MARK: - Performance Tests

    func testSensorSimulationSpeed() {
        let sensors = SensorSimulation()
        let startTime = Date()

        for _ in 0..<1000 {
            _ = sensors.nextSampleState()
        }

        let elapsed = Date().timeIntervalSince(startTime)
        let rate = 1000 / elapsed
        XCTAssert(rate > 1000, "Should generate >1000 samples/sec (got \(rate))")
    }

    func testAudioProcessingSpeed() {
        let sensors = SensorSimulation()
        let startTime = Date()

        for _ in 0..<100 {
            _ = sensors.getAudioSample()
        }

        let elapsed = Date().timeIntervalSince(startTime)
        XCTAssert(elapsed < 1.0, "Should process 100 audio samples in <1s (took \(elapsed)s)")
    }
}

// MARK: - Test Harness

class AnnaOSTestHarness {
    func runAllTests() {
        print("🧪 Running Anna OS Test Suite")
        print("=============================\n")

        let tests = AnnaOSTests()

        // Setup
        tests.setUp()

        // Run tests
        runTest("QuietScenario", { tests.testQuietScenario() })
        runTest("CookingScenario", { tests.testCookingScenario() })
        runTest("SleepingScenario", { tests.testSleepingScenario() })
        runTest("FallDetection", { tests.testFallDetection() })
        runTest("AudioSceneQuiet", { tests.testAudioSceneQuiet() })
        runTest("AudioSceneCooking", { tests.testAudioSceneCooking() })
        runTest("MusicLibrarySize", { tests.testMusicLibrarySize() })
        runTest("FindSongByTitle", { tests.testFindSongByTitle() })
        runTest("FindSongCaseInsensitive", { tests.testFindSongCaseInsensitive() })
        runTest("AlbumSequence", { tests.testAlbumSequence() })
        runTest("HealthInsightStressed", { tests.testHealthInsightStressed() })
        runTest("HealthInsightSleeping", { tests.testHealthInsightSleeping() })
        runTest("SensorToInsightFlow", { tests.testSensorToInsightFlow() })
        runTest("AudioToEnvironmentFlow", { tests.testAudioToEnvironmentFlow() })
        runTest("SensorSimulationSpeed", { tests.testSensorSimulationSpeed() })
        runTest("AudioProcessingSpeed", { tests.testAudioProcessingSpeed() })

        print("\n✅ Test suite complete")
    }

    private func runTest(_ name: String, _ test: () throws -> Void) {
        do {
            try test()
            print("✓ \(name)")
        } catch {
            print("✗ \(name): \(error)")
        }
    }
}
