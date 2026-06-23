import SwiftUI

struct PhoneContentView: View {
    @EnvironmentObject var brain: PhoneBrain
    @State private var showKey = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Watch") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Label(
                            brain.watchConnected ? "Connected" : "Waiting",
                            systemImage: brain.watchConnected ? "applewatch" : "applewatch.slash"
                        )
                        .foregroundColor(brain.watchConnected ? .green : .orange)
                    }
                    if brain.isProcessing {
                        ProgressView("Anna is thinking…")
                    }
                }

                Section("Claude API Key") {
                    if showKey {
                        TextField("sk-ant-…", text: $brain.apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        HStack {
                            Text(brain.apiKey.isEmpty ? "Not set" : "••••••••")
                            Spacer()
                            Button("Edit") { showKey = true }
                        }
                    }
                }

                Section("Mac Mini Tools (optional)") {
                    TextField("http://192.168.1.100:8765", text: $brain.macHost)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Prime count, protein fold, etc. run here when reachable.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button("Save") { brain.saveSettings() }
                    Button("Ping Watch") { brain.testConnection() }
                }

                if !brain.lastResponse.isEmpty {
                    Section("Last Response") {
                        Text(brain.lastResponse)
                            .font(.caption)
                    }
                }

                Section("How it works") {
                    Text("Watch listens silently and calibrates on your wrist. Say Hey Anna — phone runs Claude and sends the answer back. Music streams from begump.com CDN.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Anna")
        }
    }
}