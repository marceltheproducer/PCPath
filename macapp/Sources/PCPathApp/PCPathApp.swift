// PCPathApp.swift — container app for the PCPath Finder Sync extension.
//
// The app's only jobs: (1) carry the extension in Contents/PlugIns so installing
// the app registers it, (2) help the user enable it, and (3) let them edit the
// drive-letter mappings used by conversions.

import SwiftUI
import AppKit

@main
struct PCPathApp: App {
    var body: some Scene {
        Window("PCPath", id: "main") {
            ContentView()
                .frame(width: 520, height: 460)
        }
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @State private var mappingsText: String = ""
    @State private var saveNote: String = ""

    private var configURL: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".pcpath_mappings")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.left.arrow.right.square.fill")
                    .resizable().frame(width: 34, height: 34)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading) {
                    Text("PCPath").font(.title2).bold()
                    Text("Right-click a file → Quick Actions → Copy as PC Path")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }

            GroupBox("Enable the Finder extension") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Turn on “PCPath” under Login Items & Extensions → Finder, then right-click a file on a network volume.")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open Extension Settings…") {
                        NSWorkspace.shared.open(URL(string:
                            "x-apple.systempreferences:com.apple.ExtensionsPreferences")!)
                    }
                }.padding(6)
            }

            GroupBox("Drive mappings  (~/.pcpath_mappings)") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("One per line: VOLUME=LETTER (e.g. EDIT=E). STRIP=_LA trims a folder suffix.")
                        .font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: $mappingsText)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 150)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                    HStack {
                        Button("Save") { save() }
                        Button("Reload") { load() }
                        Text(saveNote).font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(6)
            }

            Spacer()
            Text("Changes take effect immediately — no reinstall needed.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(18)
        .onAppear(perform: load)
    }

    private func load() {
        if let text = try? String(contentsOf: configURL, encoding: .utf8) {
            mappingsText = text
        } else {
            mappingsText = PCPathConfig.builtinDefaultsText + "\n"
        }
        saveNote = ""
    }

    private func save() {
        do {
            try mappingsText.write(to: configURL, atomically: true, encoding: .utf8)
            saveNote = "Saved."
        } catch {
            saveNote = "Save failed: \(error.localizedDescription)"
        }
    }
}
