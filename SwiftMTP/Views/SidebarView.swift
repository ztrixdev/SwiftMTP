import SwiftUI

struct SidebarView: View {
    @ObservedObject var manager: KalamMTPManager
    @Binding var selectedStorage: MTPStorage?

    var body: some View {
        List {
            if case .connected(let device) = manager.connectionState {
                Section(device.name) {
                    ForEach(device.storages) { storage in
                        storageRow(storage)
                    }
                }
            } else {
                noDeviceView
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }

    // MARK: – Storage Row
    private func storageRow(_ storage: MTPStorage) -> some View {
        Button {
            selectedStorage = storage
            manager.selectedStorage = storage
            manager.navigationStack = ["/"]
            manager.loadFiles(at: "/")
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "internaldrive")
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(storage.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    ProgressView(value: Double(storage.usedSpace), total: Double(storage.totalSpace))
                        .progressViewStyle(.linear)
                        .tint(storageColor(storage))
                    Text("\(storage.displayFreeSpace) free of \(storage.displayTotalSpace)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .listRowBackground(selectedStorage?.id == storage.id ? Color.accentColor.opacity(0.15) : Color.clear)
    }

    private func storageColor(_ s: MTPStorage) -> Color {
        let ratio = Double(s.usedSpace) / Double(s.totalSpace)
        if ratio > 0.9 { return .red }
        if ratio > 0.75 { return .orange }
        return .accentColor
    }

    // MARK: – No Device
    private var noDeviceView: some View {
        VStack(spacing: 12) {
            Image(systemName: "cable.connector")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text("No Device Connected")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Connect an MTP device\nvia USB cable.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            if case .connecting = manager.connectionState {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Connect Device") {
                    manager.connectDevice()
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .listRowBackground(Color.clear)
        //.listRowSeparator(.hidden)
    }
}
