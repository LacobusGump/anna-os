import SwiftUI

struct ContentView: View {
    @EnvironmentObject var anna: AnnaCore

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 12) {
                modeBadge

                if anna.interactionMode == .alerting {
                    alertPanel
                } else if anna.interactionMode == .conversing {
                    conversationPanel
                } else {
                    calibrationPanel
                }

                Spacer(minLength: 0)
                footer
            }
            .padding(12)
        }
    }

    private var calibrationPanel: some View {
        VStack(spacing: 14) {
            Text("\(anna.audioMemoryCount) learned")
                .font(.system(size: 10))
                .foregroundColor(.gray)

            if let prompt = anna.pendingPrompt {
                VStack(spacing: 10) {
                    Text(prompt.question)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)

                    Text(String(format: "%.0f%%", prompt.confidence * 100))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.orange)

                    HStack(spacing: 10) {
                        confirmButton("Yes", color: .green) {
                            anna.confirmContext(guess: prompt, confirmed: true)
                        }
                        confirmButton("No", color: .red) {
                            anna.confirmContext(guess: prompt, confirmed: false)
                        }
                    }
                }
                .padding(14)
                .background(Color.gray.opacity(0.08))
                .cornerRadius(10)
            } else {
                Text("Listening…")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }

            sensorStrip
        }
    }

    private var conversationPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hey Anna")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.orange)

            Text(anna.currentResponse.isEmpty ? "…" : anna.currentResponse)
                .font(.system(size: 13))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Done") { anna.dismissConversation() }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.orange)
        }
        .padding(12)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(10)
    }

    private var alertPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Anna")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.red.opacity(0.9))

            Text(anna.proactiveAlert)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Got it") { anna.dismissConversation() }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.orange)
        }
        .padding(12)
        .background(Color.red.opacity(0.12))
        .cornerRadius(10)
    }

    private var modeBadge: some View {
        HStack {
            Text("Anna")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.orange)
            Spacer()
            Circle()
                .fill(anna.phoneConnected ? Color.green : Color.red)
                .frame(width: 6, height: 6)
            Text(anna.interactionMode.rawValue)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.gray)
        }
    }

    private var sensorStrip: some View {
        HStack(spacing: 8) {
            sensorPill("HR", "\(Int(anna.sensorState.heartRate))")
            sensorPill("P", "\(Int(anna.sensorState.barometer / 100))")
            sensorPill("g", String(format: "%.1f", anna.sensorState.acceleration))
        }
    }

    private var footer: some View {
        Text("Tap to learn · Say Hey Anna to talk")
            .font(.system(size: 9))
            .foregroundColor(.gray.opacity(0.8))
            .multilineTextAlignment(.center)
    }

    private func sensorPill(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 8)).foregroundColor(.gray)
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.06))
        .cornerRadius(6)
    }

    private func confirmButton(_ title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(color.opacity(0.25))
                .foregroundColor(color)
                .cornerRadius(8)
        }
    }
}