import SwiftUI

struct SidebarView: View {
    @ObservedObject var manager: KalamMTPManager
    @Binding var selectedStorage: MTPStorage?
    @Binding var selectedFavoriteID: UUID?
    @ObservedObject var favoritesManager: FavoritesManager
    var onFavoriteSelected: (FavoriteItem) -> Void

    @State private var showFolderNotFoundAlert = false
    @State private var draggingItem: FavoriteItem?

    var body: some View {
        List {
            if case .connected(let device) = manager.connectionState {
                Section(String(localized: "Favorites")) {
                    ForEach(favoritesManager.favorites) { item in
                        favoriteRow(item)
                            .onDrag {
                                draggingItem = item
                                return NSItemProvider(object: item.id.uuidString as NSString)
                            }
                            .onDrop(of: [.text], delegate: FavoriteDropDelegate(
                                item: item,
                                draggingItem: $draggingItem,
                                favoritesManager: favoritesManager
                            ))
                    }
                }
                
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
        .alert(String(localized: "Folder Not Found"), isPresented: $showFolderNotFoundAlert) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text("The folder does not exist on this device.")
        }
    }

    private func favoriteRow(_ item: FavoriteItem) -> some View {
        let currentPath = manager.currentPath
        let isActiveLocation = (item.path == currentPath)
        let isSelected = selectedFavoriteID == item.id && isActiveLocation
        
        return HStack(spacing: 8) {
            Image(systemName: item.icon)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 20, alignment: .center)
                .foregroundStyle(isSelected ? .primary : .secondary)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(item.displayName)
                    .font(.system(size: 13))
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text(item.path)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedFavoriteID = item.id
            handleFavoriteTap(item)
        }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                .padding(.horizontal, 4)
        )
        .contextMenu {
            if !item.isBuiltIn {
                Button(role: .destructive) {
                    favoritesManager.removeFavorite(id: item.id)
                } label: {
                    Label(String(localized: "Remove from Favorites"), systemImage: "star.slash")
                }
            }
        }
    }

    private func handleFavoriteTap(_ item: FavoriteItem) {
        guard manager.connectionState.isConnected else { return }
        guard manager.selectedStorage != nil else { return }
        onFavoriteSelected(item)
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

// MARK: – Drag & Drop Delegate for Favorites Reordering

private struct FavoriteDropDelegate: DropDelegate {
    let item: FavoriteItem
    @Binding var draggingItem: FavoriteItem?
    let favoritesManager: FavoritesManager

    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let dragging = draggingItem,
              dragging.id != item.id,
              let fromIndex = favoritesManager.favorites.firstIndex(where: { $0.id == dragging.id }),
              let toIndex = favoritesManager.favorites.firstIndex(where: { $0.id == item.id })
        else { return }

        if fromIndex != toIndex {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                favoritesManager.favorites.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func validateDrop(info: DropInfo) -> Bool {
        draggingItem != nil
    }
}
