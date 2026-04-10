import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum QuickLookOverlayState: Equatable {
    case folder(MTPFile)
    case prompt(MTPFile)
    case loading
    
    static func == (lhs: QuickLookOverlayState, rhs: QuickLookOverlayState) -> Bool {
        switch (lhs, rhs) {
        case (.folder(let a), .folder(let b)), (.prompt(let a), .prompt(let b)):
            return a.id == b.id
        case (.loading, .loading):
            return true
        default:
            return false
        }
    }
}

struct QuickLookOverlayView: View {
    let state: QuickLookOverlayState
    let onLoadPreview: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            switch state {
            case .folder(let file):
                fileInfoView(for: file)
            case .prompt(let file):
                fileInfoView(for: file)
                Button(String(localized: "Load Preview")) {
                    onLoadPreview?()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 10)
            case .loading:
                ProgressView()
                    .controlSize(.large)
                    .padding(.bottom, 8)
                Text(String(localized: "Preparing preview..."))
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // A NOT translucent background mimicking Quick Look standard background
        .background(Color(NSColor.windowBackgroundColor).opacity(1))
    }
    
    @ViewBuilder
    private func fileInfoView(for file: MTPFile) -> some View {
        VStack(spacing: 16) {
            Image(nsImage: getThumbnailIcon(for: file))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 160, height: 160)
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
            
            VStack(spacing: 8) {
                Text(file.name)
                    .font(.system(size: 24, weight: .regular))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                VStack(spacing: 4) {
                    if file.isDirectory {
                        Text(file.kind)
                    } else {
                        Text("\(file.displaySize) - \(file.kind)")
                    }
                    
                    let df = DateFormatter()
                    let _ = df.dateStyle = .medium
                    let _ = df.timeStyle = .short
                    Text(df.string(from: file.dateModified))
                }
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }
        }
    }
    
    private func getThumbnailIcon(for file: MTPFile) -> NSImage {
        let iconSize = NSSize(width: 256, height: 256)
        if file.isDirectory {
            let icon = NSWorkspace.shared.icon(for: .folder)
            icon.size = iconSize
            return icon
        }
        let ext = file.extension_.lowercased()
        if !ext.isEmpty {
            if let utType = UTType(filenameExtension: ext),
               let icon = NSWorkspace.shared.icon(for: utType) as NSImage? {
                icon.size = iconSize
                return icon
            }
        }
        let genericIcon = NSWorkspace.shared.icon(for: .data)
        genericIcon.size = iconSize
        return genericIcon
    }
}
