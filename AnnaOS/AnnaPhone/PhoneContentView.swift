import SwiftUI

struct PhoneContentView: View {
    @EnvironmentObject var brain: PhoneBrain
    @EnvironmentObject var security: AnnaSecurity
    @EnvironmentObject var coupling: CouplingLicense
    @State private var showKey = false
    @State private var showLicenseKey = false

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

                Section("Coupling License — security from begump") {
                    Text("Phone runs fully local. Recouple weekly pulls security policy (model, egress rules) — not your memories. Port of gump.coupling_license.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Text("K")
                        Spacer()
                        Text(String(format: "%.3f", brain.couplingK))
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Phase")
                        Spacer()
                        Text(brain.couplingPhase)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Policy")
                        Spacer()
                        Text("v\(brain.policyVersion)")
                            .foregroundColor(.secondary)
                    }
                    if showLicenseKey {
                        TextField("GUMP-XXXX-XXXX-XXXX", text: $brain.licenseKeyInput)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    } else {
                        HStack {
                            Text(brain.licenseKeyInput.isEmpty ? "Not set" : "••••-••••-••••")
                            Spacer()
                            Button("Edit") { showLicenseKey = true }
                        }
                    }
                    Button("Activate & Recouple") { brain.activateLicense() }
                    Button("Refresh Policy") { brain.refreshSecurityPolicy() }
                    if !brain.couplingMessage.isEmpty {
                        Text(brain.couplingMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Security — Sentinel local-only") {
                    Text("No mousetrap. Nothing leaves device unless you toggle it. Memories encrypted at rest. Mac: run security/anna-audit.sh")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(security.localOnlySummary)
                        .font(.caption)
                    Toggle("Cloud Brain (Claude)", isOn: $security.cloudBrainEnabled)
                    Toggle("Mac LAN tools", isOn: $security.macToolsEnabled)
                    Toggle("Music CDN (jsDelivr)", isOn: $security.musicStreamEnabled)
                    Toggle("begump relay", isOn: $security.begumpRelayEnabled)
                    HStack {
                        Text("Egress log (local)")
                        Spacer()
                        Text("\(brain.egressCount)")
                            .foregroundColor(.secondary)
                    }
                    Button("Save Security") { brain.saveSecurity() }
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
                    HStack {
                        Text("Current site")
                        Spacer()
                        Text(brain.currentSite)
                            .foregroundColor(.secondary)
                    }
                    Text("Air-gapped: Anna only stores what you say to remember. Geo + last call disambiguate work deck vs home deck.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Picker("Override site", selection: $brain.manualSite) {
                        Text("Auto (GPS)").tag("")
                        Text("home").tag("home")
                        Text("farm").tag("farm")
                        Text("work").tag("work")
                    }
                    Button("Set Site") { brain.saveManualSite() }

                    TextField("build@work.deck_materials_list=12x 2x6…", text: $brain.quickMemoryLine)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("Add Memory") { brain.addQuickMemory() }

                    if !brain.memoryMessage.isEmpty {
                        Text(brain.memoryMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Symbio — Jim · Watch · Phone · M4") {
                    Text("Held together anywhere by begump.com. LAN → M4 :8765. Away → begump relay.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ForEach(SymbioStack.topology, id: \.0.rawValue) { node, role in
                        HStack(alignment: .top) {
                            Text(node.rawValue)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .frame(width: 44, alignment: .leading)
                            Text(role)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Text("Throw-away layers: \(BridgeLayer.syncLayers.joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Section("Life Notes — verbatim trust") {
                    HStack {
                        Text("Captured")
                        Spacer()
                        Text("\(brain.lifeNotesCount)")
                            .foregroundColor(.secondary)
                    }
                    Text("Jim opted in: Anna records what was actually said — Jim vs other, build/call/do/need. Ask on watch: \"what did they actually say when they told me to build\" then throw.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Last call (disambiguate lists)") {
                    Text("Paste who called and what about — e.g. Johnson deck, 2x6 order. Future: Anna on her own number.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $brain.lastCallNotes)
                        .frame(minHeight: 64)
                        .font(.caption)
                    Button("Save Call Context") { brain.saveCallContext() }
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

                Section("Mac Mini (LAN only)") {
                    TextField("http://192.168.1.100:8765", text: $brain.macHost)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("127.0.0.1 or 192.168.x only — NetworkGuard blocks non-LAN. begump relay is in Security (off by default).")
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