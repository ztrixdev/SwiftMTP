//
//  MirrorManager.swift
//  SwiftMTP
//
//  Created by Owlexander on 1.7.2026.
//

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
    
    func switchTruthSource(by ID: UUID)
    {
        for mirror in mirrors
        {
            if mirror.id != ID { continue }
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

