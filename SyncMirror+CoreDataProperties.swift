//
//  SyncMirror+CoreDataProperties.swift
//  SwiftMTP
//
//  Created by Owlexander on 1.7.2026.
//
//

public import Foundation
public import CoreData


public typealias SyncMirrorCoreDataPropertiesSet = NSSet

extension SyncMirror {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SyncMirror> {
        return NSFetchRequest<SyncMirror>(entityName: "SyncMirror")
    }

    @NSManaged nonisolated public var device_id: String?
    @NSManaged nonisolated public var id: UUID?
    @NSManaged nonisolated public var device_path: String?
    @NSManaged nonisolated public var mac_path: String?
    @NSManaged nonisolated public var truth_source: Bool

}

extension SyncMirror : Identifiable {

}
