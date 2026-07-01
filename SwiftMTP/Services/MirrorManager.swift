import Foundation

class MirrorManager
{
    static let shared = MirrorManager()
    private let db = CoreDataManager.shared
    
    init() {}
    
    enum InvalidMirrorCauses {
        case Folder_Doesnt_Exist_On_Device
        case Folder_Doesnt_Exist_On_Mac
        case Mirror_Doesnt_Belong_To_Device
    }
    
    func isMirrorValid(for mirror: SyncMirror, with manager: MTPManager) -> [InvalidMirrorCauses]
    {
        var causes: [InvalidMirrorCauses] = []
        
        // check if mirror is tied to this device
        if (manager.deviceId != mirror.device_id)
        {
            causes.append(InvalidMirrorCauses.Mirror_Doesnt_Belong_To_Device)
        }
        
        var existsOnDevice = false
        var existsOnMac = false
        if let devicePath = mirror.device_path {
            manager.loadFiles(at: devicePath)
            
            var attempts = 0
            let maxAttempts = 5
            
            while manager.files.isEmpty && attempts < maxAttempts {
                sleep(2)
                attempts += 1
            }
        
            if manager.files.isEmpty {
                causes.append(.Folder_Doesnt_Exist_On_Device)
            }
        }
        
        if (mirror.mac_path != nil)
        {
            let fileManager = FileManager.default
                
            var isDirectory: ObjCBool = false
            existsOnMac =
                fileManager.fileExists(atPath: mirror.mac_path!, isDirectory: &isDirectory)
                && isDirectory.boolValue
            
            if (!existsOnMac)
            {
                causes.append(InvalidMirrorCauses.Folder_Doesnt_Exist_On_Mac)
            }
        }
        
        return causes
    }
 
    // only ran after isMirrorValid returns an empty list
    func compareFolders(for mirror: SyncMirror, with manager: MTPManager) -> MirrorDiff
    {
        var diff = MirrorDiff(
            strays: Dictionary<String, Bool>(), conflict: Dictionary<String, Bool>()
        )
        
        manager.navigateToPath(mirror.device_path!)
        let macFiles = loadFileMetadata(in: mirror.mac_path!)
        
        let macFilesDictionary = Dictionary(uniqueKeysWithValues: macFiles.map { ($0.name, $0) })
        let devFilesDictionary = Dictionary(uniqueKeysWithValues: manager.files.map { ($0.name, $0) })
        
        // truth source is the device
        if (mirror.truth_source)
        {
            for devFile in manager.files
            {
                if let matchingMacFile = macFilesDictionary[devFile.name]
                {
                    if devFile.dateModified != matchingMacFile.modificationDate
                    {
                        diff.conflict[devFile.name] = true
                    }
                }
                else
                {
                    diff.strays[devFile.name] = true
                }
            }
        }
        // Mac is the truth source
        else {
            for macFile in macFiles
            {
                if let matchingDevFile = devFilesDictionary[macFile.name]
                {
                    if (macFile.modificationDate != matchingDevFile.dateModified)
                    {
                        diff.conflict[macFile.name] = true
                    }
                }
                else
                {
                    diff.strays[macFile.name] =  true
                }
            }
        }

        return diff
    }
    
    private struct FileMetadata: Identifiable {
        let id = UUID()
        let url: URL
        let name: String
        let size: Int64
        let modificationDate: Date
        let creationDate: Date
    }
    
    func sync(for mirror: SyncMirror, with manager: MTPManager, with diff: MirrorDiff)
    {
        manager.navigateToPath(mirror.device_path!)
        
        if (mirror.truth_source == true)
        {
            var toDL: [MTPFile] = []
            for file in manager.files
            {
                if let bool = diff.strays[file.name] { toDL.append(file) }
                if let bool = diff.conflict[file.name] { toDL.append(file) }
            }
  
            let dest = URL(fileURLWithPath: mirror.mac_path!)
            manager.download(files: toDL, destinationURL: dest)
        }
        else
        {
            var toUpload: [URL] = []
            
            let macFiles = loadFileMetadata(in: mirror.mac_path!)
            for macFile in macFiles
            {
                // doing the same for now, separated for possible future use cases (resolving conflicts manually with UI)
                if let bool = diff.strays[macFile.name] { toUpload.append(macFile.url) }
                if let bool = diff.conflict[macFile.name] { toUpload.append(macFile.url) }
            }
          
            manager.upload(sourceURLs: toUpload)
        }
    }
    
    private func loadFileMetadata(in dir: String) -> [FileMetadata] {
        let fileManager = FileManager.default
        
        let metadataKeys: Set<URLResourceKey> = [
            .nameKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .isDirectoryKey
        ]
        
        let dest = URL(fileURLWithPath: dir, isDirectory: true)
        dest.startAccessingSecurityScopedResource()
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: dest,
                includingPropertiesForKeys: Array(metadataKeys),
                options: .skipsHiddenFiles
            )
            
            var filesList: [FileMetadata] = []
            
            for url in fileURLs {
                let resourceValues = try url.resourceValues(forKeys: metadataKeys)
    
                if resourceValues.isDirectory == true { continue }
                
                let metadata = FileMetadata(
                    url: url,
                    name: resourceValues.name ?? url.lastPathComponent,
                    size: Int64(resourceValues.fileSize ?? 0),
                    modificationDate: resourceValues.contentModificationDate ?? Date.distantPast,
                    creationDate: resourceValues.creationDate ?? Date.distantPast
                )
                
                filesList.append(metadata)
            }
            
            return filesList
            
        } catch {
            print("failed to read directory metadata! Error: \(error.localizedDescription)")
            return []
        }
    }
}




