//
//  ProjectManager.swift
//  Hermes
//
//  Created by David Cai on 9/18/22.
//

import Foundation
import AVFoundation
import UIKit
import FirebaseCore
import FirebaseDatabase
import FirebaseStorage

class Project: ObservableObject, Codable {
    
    var id: UUID
    var name = "Temporary project name"
    var me = Me(id: UUID(), name: "David")
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
//            try FileManager.default.removeItem(at: currentClip.temporaryURL)
            
            self.currentClip!.status = .final
            self.currentClip!.generateThumbnail()
            self.allClips.append(self.currentClip!)
            self.currentlyRecording = false
            
            print("Saved clip \(currentClip!.id.uuidString) to \(currentClip!.finalURL)")
            self.currentClip = nil
        } catch {
            print ("Error moving clip from temp to user home directory")
        }
    }
    
    // MARK: Firebase
    func createRTDBEntry() {
        let ref = Database.database().reference()
        print(ref.url)
        
        // Create DB
        ref.child(self.id.uuidString).setValue(
            [
                "name": self.name,
                "clips": [], // should be empty right now
                "members": [me.id.uuidString: me.name]
            ]
        )
    }
    
    func saveToRTDB() {
        let dbRef = Database.database().reference()
        let storageRef = Storage.storage().reference().child(self.id.uuidString)
        
        let localClips = allClips.filter({ $0.location == .local })

        localClips.forEach({c in
            // Upload clip metadata
            dbRef.child(self.id.uuidString).child("clips").childByAutoId().setValue(
                [
                    "id": c.id.uuidString,
                    "timestamp": c.timestamp.ISO8601Format(),
                    "creator": me.id.uuidString
                ]
            )
            
            // Upload thumbnails
            if c.thumbnail != nil {
                let thumbnailRef = storageRef.child("thumbnails").child(c.id.uuidString)
                let uploadTask = thumbnailRef.putData(c.thumbnail!) { (metadata, error) in
                    guard let metadata = metadata else {
                        return
                    }
                    
                    print("Uploading thumbnail for \(c.id.uuidString). [\(metadata.size)]")
                }
            }
            
            // Upload videos
            let videoRef = storageRef.child("videos").child(c.id.uuidString)
            let uploadTask = videoRef.putFile(from: c.finalURL) { (metadata, error) in
                guard let metadata = metadata else {
                    print(error?.localizedDescription)
                    return
                }
                
                print("Uploading video for \(c.id.uuidString). [\(metadata.size)]")
            }
        })
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
}


// A Clip is one recording within a project
class Clip: Identifiable, Codable, ObservableObject {
    let id: UUID
    var timestamp: Date
    let projectId: UUID
    var finalURL: URL
    var temporaryURL: URL
    @Published var status: ClipStatus
    @Published var thumbnail: Data?
    var location: ClipLocation
    
    enum ClipStatus: Codable {
        case temporary
        case final
    }
    
    enum ClipLocation: Codable {
        case local // Only exists on the device
        case uploaded // Uploaded to DB (implies that it still remains on device)
        case downloaded // Downloaded from the DB (no upload responsibility)
    }
    
    init(id: UUID, timestamp: Date, projectId: UUID, temporaryURL: URL, finalURL: URL) {
        self.id = id
        self.timestamp = timestamp
        self.projectId = projectId
        self.temporaryURL = temporaryURL
        self.finalURL = finalURL
        self.status = .temporary
        self.location = .local
    }
    
    func generateThumbnail() {
        Task {
            do {
                let asset = AVURLAsset(url: self.finalURL)
                let imgGenerator = AVAssetImageGenerator(asset: asset)
                imgGenerator.appliesPreferredTrackTransform = true
                if #available(iOS 16, *) {
                    let cgImage = try await imgGenerator.image(at: CMTime(value: 0, timescale: 1)).image
                    let png = UIImage(cgImage: cgImage).pngData()
                    self.thumbnail = png
                } else {
                    // Fallback on earlier versions
                    let cgImage = try imgGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil)
                    let png = UIImage(cgImage: cgImage).pngData()
                    self.thumbnail = png
                }
            } catch {
                print("Error generating thumbnail for \(self.id)")
            }
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
        case thumbnail
        case location
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CoderKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(temporaryURL, forKey: .temporaryURL)
        try container.encode(finalURL, forKey: .finalURL)
        try container.encode(status, forKey: .status)
        try container.encode(thumbnail, forKey: .thumbnail)
        try container.encode(location, forKey: .location)
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CoderKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        timestamp = try values.decode(Date.self, forKey: .timestamp)
        projectId = try values.decode(UUID.self, forKey: .projectId)
        temporaryURL = try values.decode(URL.self, forKey: .temporaryURL)
        finalURL = try values.decode(URL.self, forKey: .finalURL)
        status = try values.decode(ClipStatus.self, forKey: .status)
        thumbnail = try values.decode(Data.self, forKey: .thumbnail)
        location = try values.decode(ClipLocation.self, forKey: .location)
    }
}

struct Me {
    var id: UUID
    var name: String
}
