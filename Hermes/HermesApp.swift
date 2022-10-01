//
//  HermesApp.swift
//  Hermes
//
//  Created by David Cai on 9/17/22.
//

import SwiftUI
import FirebaseCore

@main
struct HermesApp: App {
//    let persistenceController = PersistenceController.shared
    let contentViewModel = ContentViewModel()
    @Environment(\.scenePhase) private var scenePhase // Used for detecting when this scene is backgrounded and isn't currently visible.
    
    // AppDelegate equivalent
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(model: contentViewModel)
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .background {
                        contentViewModel.saveProjects()
                        contentViewModel.saveCurrentProject()
                    }
                }
                .onAppear {
                    contentViewModel.loadProjects { result in
                        switch result {
                        case .success (let values):
                            if let loaded = values["allProjects"] {
                                if loaded.count != 0 {
                                    self.contentViewModel.allProjects = loaded
                                    self.contentViewModel.loadCurrentProject()
                                } else {
                                    // If loaded set is empty, noop and carry through the temp projects
                                    print("Empty loaded projects set")
                                }
                            } else {
                                print("nil check failed")
                            }
                        case .failure (let error):
                            // No need to set anything since initializer already created everything
                            print(error.localizedDescription)
                            break
                        }
                    }
                }
//                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
