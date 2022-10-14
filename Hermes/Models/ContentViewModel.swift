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

    // Global variables to manage whether or not to up/download files
    private var hasNetwork = false
    private var networkIsExpensive = true
    private var useNetworkEvenIfExpensive = true
    private var hasFirebaseAuth = false
    
    private let saveFileName = "projects"
    
    init() {
        // Temporary placeholders
        let tempProject = Project()
        self.recordingManager = RecordingManager(project: tempProject)
        self.project = tempProject
        self.allProjects = [tempProject]
        
        setupSubscriptions()
        setupNetworkMonitor()
        
        // Load name
        if let myId = UserDefaults.standard.string(forKey: "myId") {
            // Overwrite temp UUID with the store UUID
            me.id = myId
        } else {
            // If no UUID exists yet, just keep the temp ID for now. It'll be overwritten with the Firebase ID in from the callback in Firebase config
            UserDefaults.standard.setValue(me.id, forKey: "myId")
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
        UserDefaults.standard.setValue(me.id, forKey: "myId")
        self.project.me = me // Unsure if we need this, but just to be safe.
        
        print("receive id \(me.id)")
    }
    
    func setupSubscriptions() {
        cameraManager.$error
            .receive(on: RunLoop.main)
            .map { $0 }
            .assign(to: &$error)
        
        recordingManager.configureCaptureSession(session: cameraManager.session)
    }
    
    func setupNetworkMonitor() {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "Network Monitor")
        
        monitor.pathUpdateHandler = { path in
            print("Network: \(path.isExpensive)")
            if path.status == .satisfied {
                self.hasNetwork = true
            } else {
                self.hasNetwork = false
            }
            
            self.networkIsExpensive = path.isExpensive
        }
        
        monitor.start(queue: queue)
    }
    
    func switchProjects(newProject: Project) {
        // Switch currently active project
        self.project = newProject
        self.recordingManager.project = self.project
        
        // Set name, since it has to be passed in from here
        self.project.me = self.me
        
        // Save before we quit
        // Is this necessary since we save on background anyways?
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
                    completion(.success(["allProjects": [self.project]]))
                    return
                }
                
                // Successfully loaded projects
                let results = try JSONDecoder().decode([String: [Project]].self, from: file.availableData)
                completion(.success(results))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func loadCurrentProject() {
        DispatchQueue.main.async {
            let currentProjectIdString = UserDefaults.standard.string(forKey: "currentProjectId") ?? ""
            print("Loading project \(currentProjectIdString)")
            if currentProjectIdString != "" {
                let currentProjectUUID = UUID(uuidString: currentProjectIdString)
                let filteredProjects = self.allProjects.filter({p in p.id == currentProjectUUID})
                if filteredProjects.count == 1 {
                    self.switchProjects(newProject: filteredProjects[0])
                }
            } else {
                // If the UUID is not found, will just carry through the temp project
                self.project.me = self.me
                self.recordingManager.project = self.project
                
                // Since the temp project is promoted to the "real" project, it needs to be pushed to the RTDB
                self.project.createRTDBEntry()
            }
        }
    }
    
    // Firebase Handling
    
    func firebaseAuth() async {
        if !hasFirebaseAuth {
            Auth.auth().signInAnonymously { authResult, error in
                guard let user = authResult?.user else { return }
                let isAnonymous = user.isAnonymous  // true
                let uid = user.uid // ignore this id for now
                
                self.hasFirebaseAuth = true
            }
        }
    }
    
    func uploadCurrentProject() {
        guard hasNetwork else { return }
        Task { await firebaseAuth() }
        guard hasFirebaseAuth else { return }
        
        if !networkIsExpensive || (networkIsExpensive && useNetworkEvenIfExpensive) {
            self.project.networkAwareProjectUpload(shouldUploadVideo: true)
        } else {
            self.project.networkAwareProjectUpload(shouldUploadVideo: false)
        }
    }
    
    func downloadCurrentProject() {
        guard hasNetwork else { return }
        Task { await firebaseAuth() }
        guard hasFirebaseAuth else { return }
        
        if !networkIsExpensive || (networkIsExpensive && useNetworkEvenIfExpensive) {
            self.project.networkAwareProjectDownload(shouldDownloadVideo: true)
        } else {
            self.project.networkAwareProjectDownload(shouldDownloadVideo: false)
        }
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
                
                var newClip = Clip(
                    id: UUID.init(uuidString: clipIdString)!,
                    timestamp: dateFormatter.date(from: clipTimestampString)!,
                    projectId: projectId,
                    location: .remoteUndownloaded
                )
                
                // Pull thumbnail for clip TODO make this a bulk call that matches thumbnails to clips
                storageRef.child("thumbnails").child(newClip.id.uuidString).getData(maxSize: 1 * 1920 * 1080) { data, error in
                    if let error = error {
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
                        print("Error downloading video for \(clip.id.uuidString)")
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
            self.allProjects.append(remoteProject)
            
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
