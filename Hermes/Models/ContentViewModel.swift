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
    
    private let context = CIContext()
    
    let cameraManager = CameraManager()
    @Published var recordingManager: RecordingManager
    @Published var project: Project
    @Published var allProjects: [Project]
    @Published var me = Me(id: "", name: "Chameleon")
    @Published var isWorking = false

    // Global variables to manage whether or not to up/download files
    private var hasNetwork = false
    private var networkIsExpensive = true
    private var useNetworkEvenIfExpensive = true
    private var hasFirebaseAuth = false
    
    private let saveFileName = "projects"
    private let maxThumbnailDownloadSize = Int64(2000 * 2000 * 10)
    private let maxVideoDownloadSize = Int64(1920 * 1080 * 30 * 30)
    
    init() {
        // Temporary placeholders
        let tempProject = Project()
        print("TEMP PROJECT ID: \(tempProject.id.uuidString)")
        self.recordingManager = RecordingManager(project: tempProject)
        self.project = tempProject
        self.allProjects = [tempProject]
        
        setupSubscriptions()
        setupNetworkMonitor()
        
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
        me.id = meFirebaseID
        UserDefaults.standard.setValue(me.id, forKey: "meId")
        self.project.me = me // Unsure if we need this, but just to be safe.
        
        print("Updated meId to \(me.id)")
    }
    
    private func setupSubscriptions() {
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
    
    func startWork() {
        self.isWorking = true
    }
    
    func stopWork() {
        self.isWorking = false
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
    
    func createProject(name: String = "") -> Project {
        let newProject = Project(name: name)
        switchProjects(newProject: newProject) // This needs to go immediately so we set the Me object
        self.allProjects.append(newProject)
        saveProjects()
        newProject.createRTDBEntry()
        
        return newProject
    }
    
    func updateName(newName: String) {
        me.name = newName
        UserDefaults.setValue(newName, forKey: "myName")
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
    
    func downloadRemoteProject(id: String, switchToProject: Bool = false) {
        Task { await firebaseAuth() }
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
        
        // Verified project doesn't not already exist. Look to DB
        let dbRef = Database.database().reference()
        let storageRef = Storage.storage().reference().child(id)
        
        dbRef.child(id).getData(completion: {error, snapshot in
            guard error == nil && snapshot != nil && !(snapshot!.value! is NSNull) else {
                print(error!.localizedDescription)
                return
            }
            
            let info = snapshot!.value as! [String: Any]
            
            // Inflate a project
            let projectName = info["name"] as! String
            let dateFormatter = ISO8601DateFormatter()
            let projectClips = info["clips"] as! [String: Any]
            var projectAllClips: [Clip] = []
                
            for(_, d) in projectClips {
                let data = d as! [String: String]
                let clipIdString = data["id"]!
                let clipTimestampString = data["timestamp"]!
                
                let newClip = Clip(
                    id: UUID.init(uuidString: clipIdString)!,
                    timestamp: dateFormatter.date(from: clipTimestampString)!,
                    projectId: projectId,
                    location: .remoteUndownloaded
                )
                
                // Pull thumbnail for clip TODO make this a bulk call that matches thumbnails to clips
                storageRef.child("thumbnails").child(newClip.id.uuidString).getData(maxSize: self.maxThumbnailDownloadSize) { data, error in
                    if let error = error {
                        print("ERROR could not download thumbnail for clip \(newClip.id.uuidString)")
                        print(error)
                    } else {
                        if let image = UIImage(data: data!) {
                            newClip.thumbnail = image.pngData()
                        }
                    }
                }
                projectAllClips.append(newClip)
            }
            
            
            // Download videos
            for (clip) in projectAllClips {
                print("Downloading video for \(clip.id.uuidString) from \(storageRef.child("videos").child(clip.id.uuidString))")
                storageRef.child("videos").child(clip.id.uuidString).write(toFile: clip.finalURL!) { url, error in
                    if error != nil {
                        print("ERROR could not download video for \(clip.id.uuidString)")
                        return
                    }
                    
//                    clip.generateThumbnail()
                    clip.location = .downloaded
                    clip.status = .final
                }
            }

            
            // Save project
            let remoteProject = Project(
                uuid: projectId,
                name: projectName,
                allClips: projectAllClips
            )
            
            // Set all clips in the project as unseen
            remoteProject.unseenClips = remoteProject.allClips.map({ c in c.id })

            // Add project to local projects
            self.allProjects.append(remoteProject)
            self.saveProjects()
            
            // Add self to creators list
            dbRef.child(id).child("creators").child(self.me.id).setValue(self.me.name)
            
            // Switch, if told
            if (switchToProject) {
                self.switchProjects(newProject: remoteProject)
            }
        })
    }
    
}

struct Me {
    var id: String
    var name: String
}
