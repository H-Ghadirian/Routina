//  Created by ghadirianh on 07.03.25.
//

import SwiftUI
import CoreData

@main
struct RoutinaApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
