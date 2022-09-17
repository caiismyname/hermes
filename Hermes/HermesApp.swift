//
//  HermesApp.swift
//  Hermes
//
//  Created by David Cai on 9/17/22.
//

import SwiftUI

@main
struct HermesApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
