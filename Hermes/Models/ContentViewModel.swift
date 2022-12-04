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
    
    @Published var ready = false
    @Published var shouldShowProjects = false
    @Published var isOnboarding: Bool
    
    let cameraManager: CameraManager
    @Published var recordingManager: RecordingManager
    @Published var project: Project
    @Published var allProjects: [Project]
    @Published var me = Me(id: "", name: "Chameleon")
    @Published var isWorking = 0 // Multiple tasks might need the working spinner, so we ref count how many are using it and hide when it hits 0. Only interface with this variable using start/stopWork() funcs.

    // Global variables to manage whether or not to up/download files
    private var hasNetwork = false
    private var networkIsExpensive = true
    private var useNetworkEvenIfExpensive = true
    private var hasFirebaseAuth = false
    
    private let saveFileName = "projects"
//    private let maxThumbnailDownloadSize = Int64(2000 * 2000 * 10)
    private let maxVideoDownloadSize = Int64(1920 * 1080 * 30 * 300)
    
    let notificationManager = NotificationsManager()
    
    init(isOnboarding: Bool = false) {
        // Temporary placeholders
        let tempProject = Project()
        print("TEMP PROJECT ID: \(tempProject.id.uuidString)")
        self.recordingManager = RecordingManager(project: tempProject)
        self.cameraManager = CameraManager(noop: isOnboarding)
        self.project = tempProject
        self.allProjects = [tempProject]
        self.isOnboarding = isOnboarding
        
        setupNetworkMonitor()
        if !isOnboarding { // Delay camera setup if onboarding so we delay asking for permissions. Otherwise, set it up as normal.
            setupCamera()
        }
        
        // Load name
        if let meId = UserDefaults.standard.string(forKey: "meId") {
            // Overwrite temp UUID with the stored UUID
            me.id = meId
        } else {
            // If no UUID exists yet, just keep the temp ID for now. It'll be overwritten with the Firebase ID in from the callback in Firebase config
            UserDefaults.standard.setValue(me.id, forKey: "meId")
        }
        
        if let myName = UserDefaults.standard.string(forKey: "myName") {
            me.name = myName
        } else {
            UserDefaults.standard.setValue(me.name, forKey: "myName")
        }
        self.project.me = me
    }
    
    func updateMeId(meFirebaseID: String) {
        DispatchQueue.main.async {
            self.me.id = meFirebaseID
            UserDefaults.standard.setValue(self.me.id, forKey: "meId")
            self.project.me = self.me // Unsure if we need this, but just to be safe.
            
            print("Updated meId to \(self.me.id)")
        }
    }
    
    func setupCamera() {
        cameraManager.configure()
        cameraManager.$error
            .receive(on: RunLoop.main)
            .map { $0 }
            .assign(to: &$error)
        
        recordingManager.configureCaptureSession(session: cameraManager.session)
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
    
    @MainActor
    func startWork() {
        isWorking += 1
    }
    
    @MainActor
    func stopWork() {
        isWorking -= 1
    }
    
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
        let newProject = Project(name: name)
        switchProjects(newProject: newProject) // This needs to go immediately so we set the Me object
        self.allProjects.append(newProject)
        saveProjects()
        newProject.createRTDBEntry()
        
        return newProject
    }
    
    func updateName(newName: String) {
        me.name = newName
        UserDefaults.standard.setValue(newName, forKey: "myName")
        print("Set name to \(me.name)")
    }
    
    // Saving projects locally
    
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
    
    func loadProjects(completion: @escaping (Result<[String: [Project]], Error>) -> Void) {
        DispatchQueue.main.async {
            do {
                guard let file = try? FileHandle(forReadingFrom: self.contentViewModelURL()) else {
                    // If loading fails
//                    completion(.success(["allProjects": [self.project]]))
                    completion(.failure(NSError()))
                    return
                }
                
                // Successfully loaded projects
                let results = try JSONDecoder().decode([String: [Project]].self, from: file.availableData)
                print("Loaded \(results["allProjects"]!.count) projects: \(results["allProjects"]!.map({p in return p.name + " " + p.id.uuidString}))")
                completion(.success(results))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func loadCurrentProject() {
        DispatchQueue.main.async {
            let currentProjectIdString = UserDefaults.standard.string(forKey: "currentProjectId") ?? ""
            if currentProjectIdString != "" {
                print("Current project is \(currentProjectIdString)")
                let currentProjectUUID = UUID(uuidString: currentProjectIdString)
                let filteredProjects = self.allProjects.filter({p in p.id == currentProjectUUID})
                if filteredProjects.count == 1 {
                    self.switchProjects(newProject: filteredProjects[0])
                } else {
                    print("ERROR current project not in loaded project list. Didn't find \(currentProjectIdString)")
                }
            } else {
                // If the UUID is not found, will just carry through the temp project
                print("No current project saved. Carrying through initial temp project")
                
                self.project.me = self.me
                self.recordingManager.project = self.project
                
                // Since the temp project is promoted to the "real" project, it needs to be pushed to the RTDB
                self.project.createRTDBEntry()
            }
        }
    }
    
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
    
    // Firebase Handling
    
    private func firebaseAuth() async {
        if !hasFirebaseAuth {
            do {
                let authResult = try await Auth.auth().signInAnonymously()
                let uid = authResult.user.uid
                
                self.updateMeId(meFirebaseID: uid)
                self.hasFirebaseAuth = true
            } catch {
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
    
    private func downloadCurrentProject() async {
        guard hasNetwork else { return }
        await firebaseAuth()
        guard hasFirebaseAuth else { return }
        
        if !networkIsExpensive || (networkIsExpensive && useNetworkEvenIfExpensive) {
            await self.project.networkAwareProjectDownload(shouldDownloadVideo: true)
        } else {
            await self.project.networkAwareProjectDownload(shouldDownloadVideo: false)
        }
    }
    
    @MainActor
    func networkSync(shouldDownload: Bool = true) async {
        self.startWork()
        if shouldDownload {
            await downloadCurrentProject()
        }
        await uploadCurrentProject()
        print("Network sync complete (did download? --> \(shouldDownload))")
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
            
            // Verified project doesn't not already exist. Look to DB
            let dbRef = Database.database().reference()
            
            let metadataSnapshot = try await dbRef.child(id).getData()
            let info = metadataSnapshot.value as! [String: Any]
            // Inflate a project
            let projectName = info["name"] as! String
            var projectAllClips: [Clip] = []
            
            // Save project
            let remoteProject = Project(
                uuid: projectId,
                name: projectName,
                allClips: projectAllClips
            )
            
            await remoteProject.pullNewClipMetadata()
            // Intentionally do not download clips for videos when loading, to speed up loading time
//            await remoteProject.pullVideosForNewClips()
            projectAllClips = projectAllClips.filter { c in c.status != .invalid }
            // Add project to local projects
            self.allProjects.append(remoteProject)
            self.saveProjects()
            
            // Add self to creators list
            try await dbRef.child(id).child("creators").child(self.me.id).setValue(self.me.name)
            
            // Switch, if told
            if (switchToProject) {
                self.switchProjects(newProject: remoteProject)
            }
            
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
