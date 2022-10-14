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
    var contentViewModel = ContentViewModel()
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
                        contentViewModel.uploadCurrentProject() // This call is network aware
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
//                                    
//                                    DispatchQueue.main.async {
//                                        self.contentViewModel.uploadCurrentProject() // This call is network aware
//                                        self.contentViewModel.downloadCurrentProject() // This call is network aware
//                                    }
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
                .onOpenURL() {url in
                    print(url)
                    if let projectToOpenId = DeeplinkHandler.getProjectIdFromDeeplink(url: url) {
                        contentViewModel.downloadRemoteProject(id: projectToOpenId.uuidString, switchToProject: true)
                        print(projectToOpenId.uuidString)
                    } else {
                        print("Invalid UUID from deeplink")
                    }
                    
                }
//                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
