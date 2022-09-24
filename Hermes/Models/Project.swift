//
//  ProjectManager.swift
//  Hermes
//
//  Created by David Cai on 9/18/22.
//

import Foundation
import AVFoundation

class Project: ObservableObject, Codable {

    var id: UUID
    @Published var allClips: [Clip] = []
    private var currentlyRecording = false
    private var currentClip: Clip? = nil
    
    init(uuid: UUID = UUID()) {
        self.id = uuid
    }
    
    func startClip() -> Clip? {
        guard !currentlyRecording else {
            return nil
        }
        
        let clipUUID = UUID()

        do {
            let temporaryURL = URL(fileURLWithPath: (NSTemporaryDirectory() as NSString).appendingPathComponent((clipUUID.uuidString as NSString).appendingPathExtension("mov")!))
            
            let localStorageURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let localStorageFileName = clipUUID.uuidString
            let localStorageFilePath = localStorageURL.appendingPathComponent(localStorageFileName).appendingPathExtension("mov")
            
            self.currentClip = Clip(id: clipUUID, timestamp: Date(), projectId: id, temporaryURL: temporaryURL, finalURL: localStorageFilePath)
            self.currentlyRecording = true
            
            print("Allocated a new clip \(self.currentClip!.id.uuidString) with temp URL \(self.currentClip!.temporaryURL)")
            
            return self.currentClip
        } catch {
            print("Could not create temporary file for movie output")
            return nil
        }
    }
    
    func endClip() {
        do {
            try FileManager.default.moveItem(at: currentClip!.temporaryURL, to: currentClip!.finalURL)
//                try FileManager.default.removeItem(at: currentClip.temporaryURL)
            
            self.currentClip!.status = .final
            self.allClips.append(self.currentClip!)
            self.currentlyRecording = false
            
            print("Saved clip \(currentClip!.id.uuidString) to \(currentClip!.finalURL)")
            self.currentClip = nil
        } catch {
            print ("Error moving clip from temp to user home directory")
        }
    }
    
    // MARK: — Codable
    private enum CoderKeys: String, CodingKey {
        case id
        case allClips
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CoderKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(allClips, forKey: .allClips)
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CoderKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        allClips = try values.decode([Clip].self, forKey: .allClips)
    }


// A Clip is one recording within a project
class Clip: Identifiable, Codable {
    let id: UUID
    var timestamp: Date
    let projectId: UUID
    var finalURL: URL
    var temporaryURL: URL
    var status: ClipStatus
    
    enum ClipStatus: Codable {
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
    
    func generateThumbnail() -> CGImage? {
        do {
            let asset = AVURLAsset(url: self.finalURL)
            let imgGenerator = AVAssetImageGenerator(asset: asset)
            let cgImage = try imgGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil)
            
            return cgImage
        } catch {
            print("Error generating thumbnail for \(self.id)")
            return (nil)
        }
    }
    
    // MARK: — Codable
    private enum CoderKeys: String, CodingKey {
        case id
        case timestamp
        case projectId
        case temporaryURL
        case finalURL
        case status
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CoderKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(temporaryURL, forKey: .temporaryURL)
        try container.encode(finalURL, forKey: .finalURL)
        try container.encode(status, forKey: .status)
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CoderKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        timestamp = try values.decode(Date.self, forKey: .timestamp)
        projectId = try values.decode(UUID.self, forKey: .projectId)
        temporaryURL = try values.decode(URL.self, forKey: .temporaryURL)
        finalURL = try values.decode(URL.self, forKey: .finalURL)
        status = try values.decode(ClipStatus.self, forKey: .status)
    }
}
