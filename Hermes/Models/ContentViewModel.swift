//
//  ContentViewModel.swift
//  Hermes
//
//  Created by David Cai on 9/17/22.
//
import CoreImage
import SwiftUI
import FirebaseCore
import FirebaseDatabase
import FirebaseStorage
import FirebaseAuth
import Network

class ContentViewModel: ObservableObject {
    @Published var error: Error?
    @Published var frame: CGImage?
    
    @Published var shouldShowProjects = false
    @Published var isOnboarding: Bool
    
    let cameraManager: CameraManager
    let notificationManager = NotificationsManager()
    @Published var recordingManager: RecordingManager
    @Published var project: Project
    @Published var allProjects: [Project]
    @Published var me: Me
    @Published var isWorking = 0 // Multiple tasks might need the working spinner, so we ref count how many are using it and hide when it hits 0. Only interface with this variable using start/stopWork() funcs.

    // Global variables to manage whether or not to up/download files
    private var hasNetwork = false
    private var networkIsExpensive = true
    private var useNetworkEvenIfExpensive = true
    private var hasFirebaseAuth = false
    
    private let saveFileName = "projects"
//    private let maxThumbnailDownloadSize = Int64(2000 * 2000 * 10)
    private let maxVideoDownloadSize = Int64(1920 * 1080 * 30 * 300)
    
    // MARK: - Setup
    
    init(isOnboarding: Bool = false) {
        var loadingFailed = false
        
        // Start with placeholders so the initialize is failsafe
        let newProject = Project(name: "New Project", owner: "")
        self.allProjects = [newProject]
        self.project = newProject
        self.recordingManager = RecordingManager(project: newProject)
        
        self.isOnboarding = isOnboarding
        self.cameraManager = CameraManager(noop: isOnboarding)
        
        // Load Me name
        self.me = Me(id: "", name: "")
        if let meId = UserDefaults.standard.string(forKey: "meId") {
            // Overwrite temp UUID with the stored UUID
            me.id = meId
        }
        if let myName = UserDefaults.standard.string(forKey: "myName") {
            me.name = myName
        }
        self.project.me = me
        Task { await self.firebaseAuth() }
        
        // Read saved projects from the save file
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        let saveFileURL = documentsDirectory.appendingPathComponent(saveFileName)
        let file = try? FileHandle(forReadingFrom: saveFileURL)
        if file == nil {
            loadingFailed = true
            print("Saved projects file could not be loaded")
        }
        
        // Load all projects
        if !loadingFailed {
            let results = try? JSONDecoder().decode([String: [Project]].self, from: file!.availableData)
            print("Loaded \(results?["allProjects"]?.count ?? -1) projects: \(results?["allProjects"]?.map({p in return p.name + " " + p.id.uuidString}))")
            
            if let projects = results?["allProjects"] {
                if projects.count != 0 {
                    self.allProjects = projects
                } else {
                    // If loaded set is empty, noop and carry through the temp projects
                    print("Empty loaded projects set")
                    loadingFailed = true
                }
            } else {
                print("Loading projects Nil check failed")
                loadingFailed = true
            }
        }
        
        // Load current project
        if !loadingFailed {
            let currentProjectIdString = UserDefaults.standard.string(forKey: "currentProjectId") ?? ""
            if currentProjectIdString != "" {
                print("Current project is \(currentProjectIdString)")
                let filteredProjects = allProjects.filter({p in p.id == UUID(uuidString: currentProjectIdString)})
                if filteredProjects.count == 1 {
                    self.project = filteredProjects[0]
                    self.project.me = me
                    self.recordingManager = RecordingManager(project: filteredProjects[0])
                    print("Set current project to \(self.project.id.uuidString)")
                } else {
                    print("ERROR current project not in loaded project list. Didn't find \(currentProjectIdString)")
                    loadingFailed = true
                }
            } else {
                // If the UUID is not found, will just carry through the temp project
                print("No current project saved. Carrying through initial temp project")
                loadingFailed = true
            }
        }
        
        setupNetworkMonitor()
        if !isOnboarding { // Delay camera and notifications setup if onboarding so we delay asking for permissions. Otherwise, set it up as normal.
            setupCamera()
            notificationManager.setup()
        }
    }
    
    // This function should only be run once, during initial run, after receiving the me ID from Firebase
    func updateMeId(meFirebaseID: String) {
        DispatchQueue.main.async {
            if meFirebaseID != self.me.id { // Only update if value is different
                self.me.id = meFirebaseID
                UserDefaults.standard.setValue(self.me.id, forKey: "meId")
                self.project.me = self.me // Unsure if we need this, but just to be safe.
                self.project.creators[self.me.id] = self.me.name
                
                // Heuristic to set the owner on the temp project, if we're still using it.
                if self.project.owner == "" {
                    self.project.owner = self.me.id
                }
                
                print("Updated meId to \(self.me.id)")
            }
        }
    }
    
    func setupCamera(callback: () -> () = {}) {
        cameraManager.configure()
        cameraManager.$error
            .receive(on: RunLoop.main)
            .map { $0 }
            .assign(to: &$error)
        
        recordingManager.configureCaptureSession(session: cameraManager.session)
        callback()
    }
    
    func setupNotifications() {
        notificationManager.setup()
    }
    
    private func setupNetworkMonitor() {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "Network Monitor")
        
        monitor.pathUpdateHandler = { path in
            print("Network is expensive? --> \(path.isExpensive)")
            if path.status == .satisfied {
                self.hasNetwork = true
            } else {
                self.hasNetwork = false
            }
            
            self.networkIsExpensive = path.isExpensive
        }
        
        monitor.start(queue: queue)
    }
    
    // MARK: - Waiting spinner
    
    @MainActor
    func startWork() {
        self.isWorking += 1
    }
    
    @MainActor
    func stopWork() {
        self.isWorking -= 1
    }
    
    // MARK: - Project management
    
    func switchProjects(newProject: Project) {
        print("Switching to \(newProject.name) \(newProject.id)")
        // Switch currently active project
        self.project = newProject
        self.recordingManager.project = self.project
        
        // Set name, since it has to be passed in from here
        self.project.me = self.me
        
        // Save before app might quit
        saveCurrentProject()
    }
    
    func switchToNextProject() -> Bool {
        guard let currentProjectIdx = self.allProjects.firstIndex(where: { p in p.id == self.project.id }) else { return false }
            
        if currentProjectIdx < self.allProjects.count - 1 {
            let nextProject = self.allProjects[currentProjectIdx + 1]
            switchProjects(newProject: nextProject)
            return true
        }
        
        return false
    }
    
    func switchToPreviousProject() -> Bool {
        guard let currentProjectIdx = self.allProjects.firstIndex(where: { p in p.id == self.project.id }) else { return false }
            
        if currentProjectIdx > 0 && self.allProjects.count > 1 {
            let nextProject = self.allProjects[currentProjectIdx - 1]
            switchProjects(newProject: nextProject)
            return true
        }
        
        return false
    }
    
    func createProject(name: String = "New Project") -> Project {
        let newProject = Project(name: name, owner: me.id, me: self.me)
        print("Creating new project \(newProject.id.uuidString)")
        switchProjects(newProject: newProject) // This needs to go immediately so we set the Me object
        self.allProjects.append(newProject)
        saveProjects()
        
        /*
         This function does not create the FB entry for the project. That will happen when the first sync occurs.
         */
        
        return newProject
    }
    
    func updateName(newName: String) {
        me.name = newName
        UserDefaults.standard.setValue(newName, forKey: "myName")
        
        // Reflect the update in the current project
        project.me = me
        project.creators[me.id] = me.name
        
        print("Set name to \(me.name)")
    }
    
    // MARK: - Saving projects locally
    
    private func documentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
    
    private func contentViewModelURL() -> URL {
        let docURL = documentsDirectory()
        return docURL.appendingPathComponent(saveFileName)
    }
    
    func saveProjects() {
        for p in allProjects {
            print("Saving \(p.name) \(p.id)")
        }
        if let encoded = try? JSONEncoder().encode(["allProjects": allProjects]) {
            do {
                try encoded.write(to: contentViewModelURL())
                print(encoded.description)
            } catch {
                print("Failed to save projects")
            }
        } else {
            print("Failed to encode projects for saving")
        }
        
        saveCurrentProject()
    }
    
    func saveCurrentProject() {
        UserDefaults.standard.setValue(project.id.uuidString, forKey: "currentProjectId")
        print("Saved current project ID \(project.id.uuidString)")
    }
    
//    func loadProjects(completion: @escaping (Result<[String: [Project]], Error>) -> Void) {
//        DispatchQueue.main.async {
//            do {
//                guard let file = try? FileHandle(forReadingFrom: self.contentViewModelURL()) else {
//                    // If loading fails
////                    completion(.success(["allProjects": [self.project]]))
//                    completion(.failure(NSError()))
//                    return
//                }
//
//                // Successfully loaded projects
//                let results = try JSONDecoder().decode([String: [Project]].self, from: file.availableData)
//                print("Loaded \(results["allProjects"]!.count) projects: \(results["allProjects"]!.map({p in return p.name + " " + p.id.uuidString}))")
//                completion(.success(results))
//            } catch {
//                completion(.failure(error))
//            }
//        }
//    }
    
//    func loadCurrentProject() {
//        DispatchQueue.main.async {
//            let currentProjectIdString = UserDefaults.standard.string(forKey: "currentProjectId") ?? ""
//            if currentProjectIdString != "" {
//                print("Current project is \(currentProjectIdString)")
//                let currentProjectUUID = UUID(uuidString: currentProjectIdString)
//                let filteredProjects = self.allProjects.filter({p in p.id == currentProjectUUID})
//                if filteredProjects.count == 1 {
//                    self.switchProjects(newProject: filteredProjects[0])
//                } else {
//                    print("ERROR current project not in loaded project list. Didn't find \(currentProjectIdString)")
//                }
//            } else {
//                // If the UUID is not found, will just carry through the temp project
//                print("No current project saved. Carrying through initial temp project")
//
//                self.project.me = self.me
//                self.recordingManager.project = self.project
//
//                // Since the temp project is promoted to the "real" project, it needs to be pushed to the RTDB
////                self.project.createRTDBProject()
//            }
//        }
//    }
    
    func deleteProject(toDelete: UUID) {
        guard self.allProjects.contains(where: { p in p.id == toDelete }) else { return }
        Task {
            await self.startWork()
            
            self.allProjects = self.allProjects.filter({ p in p.id != toDelete })
            
            if self.project.id == toDelete {
                if self.allProjects.count > 0 {
                    self.project = allProjects[0]
                } else {
                    createProject()
                }
            }
            
            saveProjects()
            await self.stopWork()
        }
    }
    
    // MARK: - Firebase Handling
    
    func firebaseAuth() async {
        if !hasFirebaseAuth {
            do {
                let authResult = try await Auth.auth().signInAnonymously()
                self.hasFirebaseAuth = true
                print("Authenticated with Firebase")
                if isOnboarding {
                    let uid = authResult.user.uid
                    self.updateMeId(meFirebaseID: uid)
                    print("Set meId from Firebase as \(uid)")
                }
            } catch {
                print("Error authing with Firebase")
                return
            }
        }
    }
    
    private func uploadCurrentProject() async {
        guard hasNetwork else { return }
        await firebaseAuth()
        guard hasFirebaseAuth else { return }
        
        if !networkIsExpensive || (networkIsExpensive && useNetworkEvenIfExpensive) {
            await self.project.networkAwareProjectUpload(shouldUploadVideo: true)
        } else {
            await self.project.networkAwareProjectUpload(shouldUploadVideo: false)
        }
    }
    
    private func downloadCurrentProject(shouldDownloadVideo: Bool = true) async {
        guard hasNetwork else { return }
        await firebaseAuth()
        guard hasFirebaseAuth else { return }
        
        
        if !networkIsExpensive || (networkIsExpensive && useNetworkEvenIfExpensive) {
            await self.project.networkAwareProjectDownload(shouldDownloadVideo: shouldDownloadVideo)
        } else {
            await self.project.networkAwareProjectDownload(shouldDownloadVideo: false)
        }
    }
    
    @MainActor
    func networkSync(performDownloadSync: Bool = true, shouldDownloadVideos: Bool = true) async {
        self.startWork()
        if performDownloadSync {
            await downloadCurrentProject(shouldDownloadVideo: shouldDownloadVideos)
        }
        await uploadCurrentProject()
        print("Network sync complete (performedDownload: \(performDownloadSync), downloadedVideos: \(shouldDownloadVideos))")
        self.stopWork()
    }
    
    @MainActor
    func downloadRemoteProject(id: String, switchToProject: Bool = false) async {
        await firebaseAuth()
        guard hasFirebaseAuth else { return }
        
        // First check the project doesn't exist locally
        let projectId = UUID(uuidString: id)!
        guard !self.allProjects.map({ p in p.id }).contains(projectId) else {
            print("Project \(id) already exists on this device")
            if switchToProject {
                switchProjects(newProject: self.allProjects.filter({ p in p.id == projectId})[0])
            }
            return
        }
        
        do {
            print("Downloading project \(projectId) from firebase")
            self.startWork()
            self.shouldShowProjects = true
            
            // Verified project doesn't already exist. Grab owner from DB
            var projectOwner = ""
            let ownerSnapshot = try await Database.database().reference().child(projectId.uuidString).child("owner").getData()
            if !(ownerSnapshot.value! is NSNull) {
                projectOwner = ownerSnapshot.value! as! String
            } else {
                print("    No project owner found")
                return
            }
            
            // Create project locally, with minimal project metadata (rest will come in the projectMetadata sync
            let remoteProject = Project(
                uuid: projectId,
                allClips: [Clip](),
                owner: projectOwner,
                me: me
            )
            
            // Switch, if told
            // Important, switch before doing anything network heavy so we have the right project in place for the WaitingSpinner
            if (switchToProject) {
                self.switchProjects(newProject: remoteProject)
            }
            
            await remoteProject.pullProjectMetadata()
            await remoteProject.pullNewClipMetadata()
            // Intentionally do not download clips for videos when loading, to speed up loading time
//            await remoteProject.pullVideosForNewClips()
            // Not sure what this is protecting against, removing for now (12/19)
//            projectAllClips = projectAllClips.filter { c in c.status != .invalid }
            
            // Add project to local projects
            self.allProjects.append(remoteProject)
            self.saveProjects()
            
            // Add self to creators list. It's technically redundant here, but good to set it on DB when the initial pull happens so it's visible to others
            try await Database.database().reference().child(projectId.uuidString).child("creators").child(self.me.id).setValue(self.me.name)
            
            self.shouldShowProjects = false
            self.stopWork()
        } catch {
            print(error)
            self.stopWork()
        }
    }
}

struct Me {
    var id: String
    var name: String
}
