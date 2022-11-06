//
//  HermesApp.swift
//  Hermes
//
//  Created by David Cai on 9/17/22.
//

import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct HermesApp: App {
//    let persistenceController = PersistenceController.shared
    let contentViewModel = ContentViewModel()
    @Environment(\.scenePhase) private var scenePhase // Used for detecting when this scene is backgrounded and isn't currently visible.
    
    // AppDelegate equivalent
    init() {
        FirebaseApp.configure()
        
        // Leaving this here in case it's useful later
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore") as Bool
        if !hasLaunchedBefore {
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
        
        // Auth with Firebase to set the proper UUID for the Me object. This won't happen in time for the contentViewModel init, but we'll callback into it
        Task {
            do {
                let authResult = try await Auth.auth().signInAnonymously()
                let uid = authResult.user.uid
                UserDefaults.standard.setValue(uid, forKey: "meId")
                print("Set meId from Firebase as \(uid)")
            } catch {
                print("Error authing with Firebase")
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(model: contentViewModel)
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .background {
                        contentViewModel.saveProjects() // saveCurrentProject is called in saveProjects()
//                        contentViewModel.uploadCurrentProject() // This call is network aware
                        Task { await contentViewModel.networkSync(shouldDownload: false) }
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

                                        DispatchQueue.main.async {
//                                            self.contentViewModel.uploadCurrentProject() // This call is network aware
//                                            self.contentViewModel.downloadCurrentProject() // This call is network aware
                                            
                                            Task { await self.contentViewModel.networkSync() }
                                        }
                                    } else {
                                        // If loaded set is empty, noop and carry through the temp projects
                                        print("Empty loaded projects set")
                                    }
                                } else {
                                    print("nil check failed")
                                }
                            case .failure (let error):
                                // No need to set anything since initializer already created everything
                                print("Error loading projects, will carry through inital temp project")
//                                print(error.localizedDescription)
                                break
                        }
                    }
                }
                .onOpenURL() {url in
                    print(url)
                    if let projectToOpenId = DeeplinkHandler.getProjectIdFromDeeplink(url: url) {
                        Task {
                            print(projectToOpenId.uuidString)
                            await contentViewModel.downloadRemoteProject(id: projectToOpenId.uuidString, switchToProject: true)
                        }
                    } else {
                        print("Invalid UUID from deeplink")
                    }
                    
                }
//                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
