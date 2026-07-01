import CoreData


// service class to put coredata to work
class CoreDataManager {
    static let shared = CoreDataManager()
    let container: NSPersistentContainer
    
    var context: NSManagedObjectContext {
        return container.viewContext
    }
    
    private init() {
        container = NSPersistentContainer(name: "SwiftMTP")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("failed to load CoreData! Error: \(error.localizedDescription)")
            }
        }
    }
    
    func save() {
        if context.hasChanges {
            try? context.save()
        }
    }
}

