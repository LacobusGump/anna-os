import SwiftUI

struct ContentView: View {
    @EnvironmentObject var anna: AnnaCore
    @State private var selectedScenario: Int = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                // Header
                Text("Anna OS")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.orange)

                // Sensor Display
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("HR")
                            .frame(width: 40)
                        Text("\(Int(anna.sensorState.heartRate)) bpm")
                            .font(.monospaced(.system(size: 12, weight: .regular)))
                    }

                    HStack {
                        Text("Pressure")
                            .frame(width: 40)
                        Text("\(Int(anna.sensorState.barometer)) Pa")
                            .font(.monospaced(.system(size: 12, weight: .regular)))
                    }

                    HStack {
                        Text("Accel")
                            .frame(width: 40)
                        Text(String(format: "%.2f g", anna.sensorState.acceleration))
                            .font(.monospaced(.system(size: 12, weight: .regular)))
                    }

                    HStack {
                        Text("Sleep")
                            .frame(width: 40)
                        Text(anna.sensorState.isSleeping ? "Yes" : "No")
                            .font(.monospaced(.system(size: 12, weight: .regular)))
                    }
                }
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)

                Divider()

                // Context Guessing (NEW: Audio Calibration)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("What's happening?")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(anna.audioMemoryCount) learned")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }

                    if anna.contextGuesses.isEmpty {
                        Text("Listening...")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .padding(8)
                    } else {
                        ForEach(anna.contextGuesses.indices, id: \.self) { index in
                            let guess = anna.contextGuesses[index]
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(guess.question)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text(String(format: "%.0f%%", guess.confidence * 100))
                                        .font(.system(size: 10))
                                        .foregroundColor(.orange)
                                }

                                HStack(spacing: 6) {
                                    Button(action: {
                                        anna.confirmContext(guess: guess, confirmed: true)
                                    }) {
                                        Text("Yes")
                                            .font(.system(size: 11, weight: .semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(6)
                                            .background(Color.green.opacity(0.3))
                                            .foregroundColor(.green)
                                            .cornerRadius(3)
                                    }

                                    Button(action: {
                                        anna.confirmContext(guess: guess, confirmed: false)
                                    }) {
                                        Text("No")
                                            .font(.system(size: 11, weight: .semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(6)
                                            .background(Color.red.opacity(0.3))
                                            .foregroundColor(.red)
                                            .cornerRadius(3)
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(4)
                        }
                    }
                }

                Divider()

                // Scenario Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Test Scenarios")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)

                    ForEach(TestScenarios.all.indices, id: \.self) { index in
                        Button(action: {
                            selectedScenario = index
                            activateScenario(TestScenarios.all[index])
                        }) {
                            HStack {
                                Text(TestScenarios.all[index].name)
                                    .foregroundColor(selectedScenario == index ? .orange : .gray)
                                Spacer()
                                if selectedScenario == index {
                                    Text("●")
                                        .foregroundColor(.orange)
                                }
                            }
                            .font(.system(size: 12))
                            .padding(8)
                            .background(selectedScenario == index ? Color.orange.opacity(0.1) : Color.clear)
                            .cornerRadius(4)
                        }
                    }
                }

                Divider()

                // Music Control
                VStack(alignment: .leading, spacing: 8) {
                    Text("Music")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)

                    if let song = anna.nowPlaying {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            Text(song.subtitle)
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(4)
                    }

                    HStack(spacing: 8) {
                        Button(action: { anna.playAlbum() }) {
                            Text("Album")
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }

                        Button(action: { anna.skip() }) {
                            Text("Skip")
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }

                        Button(action: { anna.pause() }) {
                            Text(anna.isPlaying ? "Pause" : "Play")
                                .frame(maxWidth: .infinity)
                                .padding(8)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                    }
                }

                Divider()

                // Voice Control
                VStack(alignment: .leading, spacing: 8) {
                    Text("Voice")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)

                    Button(action: { anna.startListening() }) {
                        HStack {
                            Text(anna.isListening ? "🎙️ Listening..." : "🎙️ Listen")
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(anna.isListening ? Color.red.opacity(0.3) : Color.orange.opacity(0.2))
                        .cornerRadius(6)
                    }

                    if !anna.currentResponse.isEmpty {
                        Text(anna.currentResponse)
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                }

                Spacer()

                // Footer
                Text("Ready to build")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            .padding(16)
        }
    }

    private func activateScenario(_ scenario: TestScenario) {
        // Will wire into SensorSimulation when ready
        print("Activated: \(scenario.name)")
    }
}

struct TestScenario {
    let name: String
    let id: String
}

struct TestScenarios {
    static let all = [
        TestScenario(name: "Quiet", id: "quiet"),
        TestScenario(name: "Cooking", id: "cooking"),
        TestScenario(name: "Sleeping", id: "sleeping"),
        TestScenario(name: "Stressed", id: "stressed"),
        TestScenario(name: "Exercising", id: "exercising"),
        TestScenario(name: "Falling", id: "falling"),
    ]
}

#Preview {
    ContentView()
        .environmentObject(AnnaCore())
}
