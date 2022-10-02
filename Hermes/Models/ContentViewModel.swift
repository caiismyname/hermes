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

class ContentViewModel: ObservableObject {
    @Published var error: Error?
    @Published var frame: CGImage?
    
    private let context = CIContext()
    
    let cameraManager = CameraManager()
    @Published var recordingManager: RecordingManager
    @Published var project: Project
    @Published var allProjects: [Project]
    
    private let saveFileName = "projects"
    
    init() {
        // Temporary placeholders
        let tempProject = Project()
        self.recordingManager = RecordingManager(project: tempProject)
        self.project = tempProject
        self.allProjects = [tempProject]
        
        setupSubscriptions()
    }
    
    func setupSubscriptions() {
        cameraManager.$error
            .receive(on: RunLoop.main)
            .map { $0 }
            .assign(to: &$error)
        
        recordingManager.configureCaptureSession(session: cameraManager.session)
    }
    
    func switchProjects(newProject: Project) {
        // Switch currently active project
        self.project = newProject
        self.recordingManager.project = self.project
        
        // Save before we quit
        // Is this necessary since we save on background anyways?
        saveCurrentProject()
    }
    
    func createProject() -> Project {
        let newProject = Project()
        self.allProjects.append(newProject)
        saveProjects()
        
        switchProjects(newProject: newProject)
        
        return newProject
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
            print(currentProjectIdString)
            if currentProjectIdString != "" {
                let currentProjectUUID = UUID(uuidString: currentProjectIdString)
                let filteredProjects = self.allProjects.filter({p in p.id == currentProjectUUID})
                if filteredProjects.count == 1 {
                    self.project = filteredProjects[0]
                }
                
                // Does nothing if the UUID is not found, will just carry through the temp project
            }
            
            self.recordingManager.project = self.project
        }
    }
    
    func findRemoteProject(id: String) {
        let dbRef = Database.database().reference()
        
        dbRef.child(id).getData(completion: {error, snapshot in
            guard error == nil && snapshot != nil else {
                print(error!.localizedDescription)
                return
            }
            
            print(snapshot!.value)
            
            let info = snapshot!.value as! [String: Any]
            
            // Inflate a project
            let projectName = info["name"] as! String
            let projectId = UUID(uuidString: id)!
            let formatter = ISO8601DateFormatter()
            let projectClips = info["clips"] as! [String: Any]
            var projectAllClips: [Clip] = []
                
            for(_, d) in projectClips {
                let data = d as! [String: String]
                let clipIdString = data["id"]!
                let clipTimestampString = data["timestamp"]!
                projectAllClips.append(
                    Clip(
                        id: UUID.init(uuidString: clipIdString)!,
                        timestamp: formatter.date(from: clipTimestampString)!,
                        projectId: projectId,
                        location: .remoteUndownloaded
                    )
                )
            }
            
            print(projectAllClips)
            
            
            // Download videos
            let storageRef = Storage.storage().reference().child(projectId.uuidString).child("videos")
            for (clip) in projectAllClips {
                print("Downloading video for \(clip.id.uuidString) from \(storageRef.child(clip.id.uuidString))")
                storageRef.child(clip.id.uuidString).write(toFile: clip.finalURL!) { url, error in
                    if error != nil {
                        print("Error downloading video for \(clip.id.uuidString)")
                        return
                    }
                    
                    clip.generateThumbnail()
                }
            }

            
            // Save project
            let remoteProject = Project(
                uuid: projectId,
                name: projectName,
                allClips: projectAllClips
            )
            
            self.allProjects.append(remoteProject)
        })
    }
    
}
