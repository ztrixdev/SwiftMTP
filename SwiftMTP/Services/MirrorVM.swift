import Foundation
import Combine


class MirrorVM: ObservableObject
{
    var mirrors: [SyncMirror] = []
    
    private let db = CoreDataManager.shared
    
    init()
    {
        fetchMirrors()
    }
    
    func fetchMirrors()
    {
        let request = SyncMirror.fetchRequest()
        do {
            self.mirrors = try db.context.fetch(request)
        } catch {
            print("Failed to fetch mirrors: \(error)")
        }
    }

    
    // for debugging purposes may add new like:
    /*
     * mockMirrorVM.addMirror(deviceID: "VID|PID|S/N", devicePath: "/path/to/folder", macPath: "/Users/userhome/Documents/MirrorTest")
     */
     
    func addMirror(deviceId: String, devicePath: String, macPath: String)
    {
        let newMirror = SyncMirror(context: db.context)
        newMirror.id = UUID()
        newMirror.device_id = deviceId
        newMirror.device_path = devicePath
        newMirror.mac_path = macPath
        newMirror.truth_source = true
        
        db.save()
        fetchMirrors()
    }
    
    func getMirrors(for device: String) -> [SyncMirror]
    {
        var deviceRelatedMirrors: [SyncMirror] = []
        for mirror in mirrors
        {
            if (mirror.device_id == device)
            {
                deviceRelatedMirrors.append(mirror)
            }
        }
        
        return deviceRelatedMirrors
    }
    
    func switchTruthSource(by id: UUID)
    {
        for mirror in mirrors
        {
            if mirror.id != id { continue }
            mirror.truth_source.toggle()
        }
        
        db.save()
        fetchMirrors()
    }
    
    
    func deleteMirror(by ID: UUID)
    {
        for mirror in mirrors
        {
            if mirror.id != ID { continue }
            db.context.delete(mirror)
        }
        
        db.save()
        fetchMirrors()
    }
}

