//
//  ContentViewModel.swift
//  Hermes
//
//  Created by David Cai on 9/17/22.
//
import CoreImage
import SwiftUI

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
}
