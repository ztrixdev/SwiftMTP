import SwiftUI

struct SettingsView: View {
    @AppStorage("fileListFontSize") private var fileListFontSize: Int = 12
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        TabView {
            Form {
                Picker(String(localized: "Font Size"), selection: $fileListFontSize) {
                    ForEach(10...16, id: \.self) { size in
                        Text("\(size)").tag(size)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 300)
            }
            .padding(20)
            .tabItem {
                Label(String(localized: "Display", comment: "Tab showing display settings"), systemImage: "display")
            }
            
            Form {
                VStack(alignment: .leading, spacing: 12) {
                    Image(colorScheme == .dark ? "favicon-32x32-dark" : "favicon-32x32")
                    Text("SwiftMTP")
                        .font(.system(size: 20, weight: .semibold))
                    Text(String(localized: "A modern MTP device management tool for macOS.", comment: "Settings App Description"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    HStack(spacing: 16) {
                        Button {
                            if let url = URL(string: "https://neighbor-z.github.io/swiftmtp-website") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Image(systemName: "globe")
                        }
                        .help(String(localized: "Website", comment: "Website link tooltip"))
                        .onHover { isHovering in
                            if isHovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                        
                        Button {
                            if let url = URL(string: "https://github.com/Neighbor-Z/SwiftMTP") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                        }
                        .help("GitHub")
                        .onHover { isHovering in
                            if isHovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                        
                        Button {
                            if let url = URL(string: "https://buymeacoffee.com/neighbor_z") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Image(systemName: "cup.and.saucer.fill")
                        }
                        .help(String(localized: "Buy Me a Coffee", comment: "Donation link tooltip"))
                        .onHover { isHovering in
                            if isHovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
                    
                    Divider()
                        .padding(.vertical, 4)
                        
                    HStack {
                        Text("v\(UpdateChecker.composedAppVersion())")
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        UpdateButtonRow()
                    }
                }
            }
            .padding(20)
            .tabItem {
                Label(String(localized: "Info & Update", comment: "Tab showing info and update"), systemImage: "info.circle")
            }
        }
        .frame(width: 400, height: 220)
        .navigationTitle(String(localized: "Settings"))
    }
}

// MARK: - Update Button Row

private struct UpdateButtonRow: View {
    @StateObject private var checker = UpdateChecker.shared

    var body: some View {
        HStack(spacing: 6) {
            // Left-side status indicator
            Group {
                switch checker.state {
                case .checking:
                    ProgressView()
                        .controlSize(.small)
                case .updateAvailable:
                    Text(String(localized: "Update available", comment: "Update available status"))
                        .foregroundStyle(.green)
                        .font(.callout)
                case .upToDate:
                    Text(String(localized: "App is up to date.", comment: "App is up to date status"))
                        .foregroundStyle(.secondary)
                        .font(.callout)
                case .failed:
                    Text(String(localized: "Check failed", comment: "Update check failed status"))
                        .foregroundStyle(.red)
                        .font(.callout)
                case .idle:
                    EmptyView()
                }
            }

            // Action button
            switch checker.state {
            case .updateAvailable(let version, let url):
                Button(String(format: String(localized: "Download %@", comment: "Download update button"), version)) {
                    NSWorkspace.shared.open(url)
                }
                .id("download-update-button")

            case .checking:
                Button(String(localized: "Check for Updates...", comment: "Settings Update Button")) {}
                    .disabled(true)
                    .id("check-updates-button-checking")

            default:
                Button(String(localized: "Check for Updates...", comment: "Settings Update Button")) {
                    Task { await checker.checkForUpdates() }
                }
                .id("check-updates-button")
            }
        }
    }
}
