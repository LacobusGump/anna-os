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

                Section("Life Memory — THE KEY") {
                    HStack {
                        Text("Stored")
                        Spacer()
                        Text("\(brain.lifeMemoryCount)")
                            .foregroundColor(.secondary)
                    }
                    Text("Profile is seed. Memories are your life — eggs in the fridge, omelet ingredients, Shan music on Route 22. Anna learns from conversation and quick-add.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("kitchen.eggs_count=5", text: $brain.quickMemoryLine)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("Add Memory") { brain.addQuickMemory() }

                    if !brain.memoryMessage.isEmpty {
                        Text(brain.memoryMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Jim — health substrate") {
                    HStack {
                        Text("Phenotype")
                        Spacer()
                        Text("Red hair · blue eyes · MC1R")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("Paste labs, meds, variant calls — Anna learns you, not a generic user. Granularity speeds synch.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("MC1R / genotype notes (rs1805007, etc.)", text: $brain.mc1rNotes, axis: .vertical)
                        .lineLimit(2...4)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextEditor(text: $brain.healthRecords)
                        .frame(minHeight: 120)
                        .font(.caption)
                        .overlay(alignment: .topLeading) {
                            if brain.healthRecords.isEmpty {
                                Text("Paste health records here…")
                                    .font(.caption)
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                                    .allowsHitTesting(false)
                            }
                        }

                    Button("Save Health Profile") { brain.saveHealthProfile() }
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