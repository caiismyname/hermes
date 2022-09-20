//
//  ProjectManager.swift
//  Hermes
//
//  Created by David Cai on 9/18/22.
//

import Foundation

class ProjectManager {

    var projectId = UUID()
    var allClips: [Clip] = []
    private var currentlyRecording = false
    
    init() {
    }
    
    func startClip() -> Clip? {
        guard !currentlyRecording else {
            return nil
        }
        
        let clipUUID = UUID()
//        let outputFileName = clipUUID.uuidString
//        let outputFilePath =
//            (NSTemporaryDirectory() as NSString)
//            .appendingPathComponent(
//                (outputFileName as NSString).appendingPathExtension("mov")!
//            )

        do {
            let temporaryURL = URL(fileURLWithPath: (NSTemporaryDirectory() as NSString).appendingPathComponent((clipUUID.uuidString as NSString).appendingPathExtension("mov")!))
            
            let localStorageURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let localStorageFileName = clipUUID.uuidString
            let localStorageFilePath = localStorageURL.appendingPathComponent(localStorageFileName).appendingPathExtension("mov")
            
            let currentClip = Clip(id: clipUUID, timestamp: Date(), projectId: projectId, temporaryURL: temporaryURL, finalURL: localStorageFilePath)
            
            allClips.append(currentClip)
            currentlyRecording = true
            
            print("Allocated a new clip \(currentClip.id.uuidString) with temp URL \(currentClip.temporaryURL)")
            
            return currentClip
        } catch {
            print("Could not create temporary file for movie output")
            return nil
        }
    }
    
    func endClip() {
        if let currentClip = allClips.last {
            do {
                try FileManager.default.moveItem(at: currentClip.temporaryURL, to: currentClip.finalURL)
//                try FileManager.default.removeItem(at: currentClip.temporaryURL)
                
                currentClip.status = .final
                currentlyRecording = false
                
                print("Saved clip \(currentClip.id.uuidString) to \(currentClip.finalURL)")
            } catch {
                print ("Error moving clip from temp to user home directory")
            }
        }
    }
}

// A Clip is one recording within a project
class Clip {
    let id: UUID
    var timestamp: Date
    let projectId: UUID
    var finalURL: URL
    var temporaryURL: URL
    var status: ClipStatus
    
    enum ClipStatus {
        case temporary
        case final
    }
    
    init(id: UUID, timestamp: Date, projectId: UUID, temporaryURL: URL, finalURL: URL) {
        self.id = id
        self.timestamp = timestamp
        self.projectId = projectId
        self.temporaryURL = temporaryURL
        self.finalURL = finalURL
        self.status = .temporary
    }
}
