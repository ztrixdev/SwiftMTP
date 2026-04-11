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
                        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
                            Text("v\(version) (\(build))")
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(String(localized: "Check for Updates...", comment: "Settings Update Button")) {
                            // Update action placeholder
                        }
                        .disabled(true)
                        .help(String(localized: "Check for Updates is NOT available yet."))
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
