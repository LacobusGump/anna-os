import Foundation

class SensorSimulation {
    private var time: TimeInterval = 0
    private var scenario: TestScenario = .quiet
    private var audioBuffer: [Double] = []

    enum TestScenario {
        case quiet
        case cooking  // stove clicking
        case sleeping  // low HR, minimal accel
        case stressed  // high HR, variable
        case exercising  // high HR, high accel
        case falling  // spike in accel
    }

    func nextSampleState() -> SensorState {
        time += 0.1  // 100ms updates

        let hr = generateHeartRate()
        let baro = generateBarometer()
        let accel = generateAcceleration()
        let gyro = generateGyroscope()
        let isSleeping = hr < 60 && accel < 0.1

        return SensorState(
            heartRate: hr,
            barometer: baro,
            acceleration: accel,
            gyroscope: gyro,
            audioLevel: generateAudioLevel(),
            isSleeping: isSleeping,
            timestamp: Date()
        )
    }

    func getAudioSample() -> AudioSample {
        let waveform = generateAudioWaveform()
        let spectrum = computeSpectrum(waveform)

        // Detect wake word (simplified)
        let hasWakeWord = detectWakeWord(spectrum: spectrum)

        return AudioSample(
            waveform: waveform,
            spectrum: spectrum,
            containsWakeWord: hasWakeWord
        )
    }

    func setScenario(_ scenario: TestScenario) {
        self.scenario = scenario
        self.time = 0
    }

    // MARK: - Synthetic Data Generators

    private func generateHeartRate() -> Double {
        switch scenario {
        case .quiet:
            return 72 + sin(time / 10) * 5  // resting, slight variation

        case .cooking:
            return 78 + sin(time / 8) * 3  // slightly elevated

        case .sleeping:
            return 55 + sin(time / 20) * 2  // low and stable

        case .stressed:
            return 95 + sin(time / 3) * 15  // high and variable

        case .exercising:
            return 140 + sin(time / 2) * 10  // very high

        case .falling:
            if time < 2 {
                return 72
            } else {
                return 120 + sin(time / 0.5) * 20  // spike
            }
        }
    }

    private func generateBarometer() -> Double {
        switch scenario {
        case .quiet:
            return 101325 + sin(time / 30) * 10  // stable indoors

        case .cooking:
            return 101320 + sin(time / 20) * 5  // slight pressure from heat

        case .sleeping:
            return 101325  // very stable

        case .stressed:
            return 101315 + sin(time / 5) * 20  // variable (breathing changes)

        case .exercising:
            return 101310  // slightly lower (movement, heat)

        case .falling:
            if time < 1 {
                return 101325
            } else {
                return 101325 - 50 * sin(time / 0.2)  // pressure change on impact
            }
        }
    }

    private func generateAcceleration() -> Double {
        switch scenario {
        case .quiet:
            return abs(sin(time / 20)) * 0.1  // barely moving

        case .cooking:
            return abs(sin(time / 2) * cos(time / 3)) * 0.3  // arm movement

        case .sleeping:
            return 0.02  // almost no movement

        case .stressed:
            return abs(sin(time / 1.5)) * 0.5  // fidgeting

        case .exercising:
            return abs(sin(time / 1)) * 2.0  // large movements

        case .falling:
            if time < 0.5 {
                return 0.1
            } else if time < 1 {
                return 5.0 + abs(sin(time / 0.1)) * 2  // impact
            } else {
                return 0.2 + abs(sin(time / 3)) * 0.1  // lying down, slight movement
            }
        }
    }

    private func generateGyroscope() -> Double {
        switch scenario {
        case .quiet:
            return abs(sin(time / 10)) * 0.05  // head still

        case .cooking:
            return abs(sin(time / 2)) * 0.2  // looking around

        case .sleeping:
            return 0.01  // very still

        case .stressed:
            return abs(sin(time / 1)) * 0.3  // fidgeting, head moving

        case .exercising:
            return abs(sin(time / 1)) * 0.8  // large rotations

        case .falling:
            if time < 1 {
                return 5.0 + abs(sin(time / 0.1)) * 2  // tumbling
            } else {
                return 0.05  // still after impact
            }
        }
    }

    private func generateAudioLevel() -> Double {
        switch scenario {
        case .quiet:
            return 0.1  // background noise only

        case .cooking:
            return 0.4 + abs(sin(time / 0.5)) * 0.2  // stove clicks

        case .sleeping:
            return 0.05  // very quiet

        case .stressed:
            return 0.3  // normal conversation level

        case .exercising:
            return 0.2  // breathing, movement

        case .falling:
            if time < 1 {
                return 0.8 + abs(sin(time / 0.1)) * 0.2  // loud impact
            } else {
                return 0.1  // quiet after
            }
        }
    }

    private func generateAudioWaveform() -> [Double] {
        var waveform: [Double] = []

        // Generate 1024 samples
        for i in 0..<1024 {
            let phase = Double(i) / 1024.0 * Double.pi * 2

            switch scenario {
            case .cooking:
                // Stove clicking pattern
                let click = sin(phase * 8) * 0.5
                let noise = Double.random(in: -0.3...0.3)
                waveform.append(click + noise)

            case .sleeping:
                // Quiet breathing pattern
                let breath = sin(phase * 0.5) * 0.1
                waveform.append(breath)

            case .quiet:
                // White noise
                waveform.append(Double.random(in: -0.2...0.2))

            default:
                // Generic signal
                waveform.append(sin(phase) * 0.5)
            }
        }

        return waveform
    }

    private func computeSpectrum(waveform: [Double]) -> [Double] {
        // Simplified spectrum (just frequency buckets)
        var spectrum = Array(repeating: 0.0, count: 64)

        for (i, sample) in waveform.enumerated() {
            let bucket = (i / waveform.count) * 64
            spectrum[min(bucket, 63)] += abs(sample) / Double(waveform.count)
        }

        return spectrum
    }

    private func detectWakeWord(spectrum: [Double]) -> Bool {
        // Simplified: detect if audio has energy in speech range (200-3000 Hz)
        // Spectrum bucket 10-40 represents that range
        let speechEnergy = spectrum[10..<40].reduce(0, +)
        return speechEnergy > 0.3
    }
}
