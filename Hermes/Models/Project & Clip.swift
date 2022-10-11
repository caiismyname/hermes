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
    @Published var name: String
    var me: Me?
    private var creators: [String: String] = [String: String]()
    @Published var allClips: [Clip]
    private var currentlyRecording = false
    private var currentClip: Clip? = nil
    
    init(uuid: UUID = UUID(), name: String = "Project \(Int.random(in: 0..<100))", allClips: [Clip] = []) {
        self.id = uuid
        self.name = name
        self.allClips = allClips
    }

    func startClip() -> Clip? {
        guard !currentlyRecording else {
            return nil
        }
        
        self.currentClip = Clip(projectId: id)
        self.currentlyRecording = true
        
        print("Allocated a new clip \(self.currentClip!.id.uuidString) with temp URL \(self.currentClip!.temporaryURL)")
        
        return self.currentClip
    }
    
    func endClip() {
        do {
            guard currentClip != nil else {
                print("Error saving clip")
                return
            }

            guard currentClip!.temporaryURL != nil && currentClip!.finalURL != nil else {
                print("Error saving clip — missing temporary or final URL")
                return
            }
            
            try FileManager.default.moveItem(at: currentClip!.temporaryURL!, to: currentClip!.finalURL!)
//            try FileManager.default.removeItem(at: currentClip.temporaryURL)
            
            self.currentClip!.status = .final
            self.currentClip!.generateThumbnail()
            self.allClips.append(self.currentClip!)
            self.currentlyRecording = false
            
            print("Saved clip \(currentClip!.id.uuidString) to \(currentClip!.finalURL!)")
            self.currentClip = nil
            
            // Run a sync to upload new clip
            DispatchQueue.main.async {
                self.networkAwareProjectUpload(shouldUploadVideo: false) // Just upload metadata for now
            }
        } catch {
            print ("Error moving clip from temp to user home directory")
        }
    }
    
    private func sortClips() {
        self.allClips.sort { a, b in
            a.timestamp < b.timestamp
        }
    }
    
    func generateURL() -> URL {
        return URL(string: "\(URLSchema.baseURL)\(self.id.uuidString)")!
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
                "creators": [me!.id.uuidString: me!.name]
            ]
        )
    }
    
    func saveMetadataToRTDB() {
        print("Uploading metadata for project \(self.id.uuidString) to RTDB")
        let dbRef = Database.database().reference()
        let storageRef = Storage.storage().reference().child(self.id.uuidString)
        
        let localClips = allClips.filter({ $0.location == .local })

        localClips.forEach({c in
            guard c.finalURL != nil else {
                print("Error uploading clip \(c.id.uuidString) — missing finalURL")
                return
            }
            
            // Upload clip metadata
            dbRef.child(self.id.uuidString).child("clips").childByAutoId().setValue(
                [
                    "id": c.id.uuidString,
                    "timestamp": c.timestamp.ISO8601Format(),
                    "creator": me!.id.uuidString
                ]
            )
            
            // Upload thumbnails
            if c.thumbnail != nil {
                let thumbnailRef = storageRef.child("thumbnails").child(c.id.uuidString)
                _ = thumbnailRef.putData(c.thumbnail!) { (metadata, error) in
                    guard let metadata = metadata else {
                        return
                    }
                    
                    print("Uploaded thumbnail for \(c.id.uuidString). [\(metadata.size)]")
                }
            }
            c.location = .remoteUnuploaded
        })
        
        // Upload project metadata
        dbRef.child(self.id.uuidString).child("name").setValue(self.name)
        dbRef.child(self.id.uuidString).child("creators").child(self.me!.id.uuidString).setValue(self.me!.name) // only update your own name, not the whole list
    }
    
    func saveVideosToRTDB() {
        print("Uploading videos for project \(self.id.uuidString) to DB")
        let dbRef = Database.database().reference()
        let storageRef = Storage.storage().reference().child(self.id.uuidString)
        
        let remoteUnuploadedClips = allClips.filter({ $0.location == .remoteUnuploaded })

        remoteUnuploadedClips.forEach({c in
            let videoRef = storageRef.child("videos").child(c.id.uuidString)
            _ = videoRef.putFile(from: c.finalURL!) { (metadata, error) in
                guard let metadata = metadata else {
                    print(error?.localizedDescription ?? "Error uploading video for \(c.id.uuidString)")
                    return
                }
                
                print("Uploaded video for \(c.id.uuidString). [\(metadata.size)]")
                c.location = .uploaded
            }
        })
    }
    
    func networkAwareProjectUpload(shouldUploadVideo: Bool = false) {
        saveMetadataToRTDB()
        
        if shouldUploadVideo {
            saveVideosToRTDB()
        }
    }
    
    func pullNewClipMetadata() {
        print("Pulling new clip metadata")
        let dbRef = Database.database().reference().child(id.uuidString).child("clips")
        let storageRef = Storage.storage().reference().child(self.id.uuidString).child("videos")
        
        dbRef.getData(completion: {error, snapshot in
            guard error == nil && snapshot != nil else {
                print(error!.localizedDescription)
                return
            }
            
            guard !(snapshot!.value! is NSNull) else {
                // No clips in RTDB, nothing to sync
                return
            }
            
            let allClipsFromDB = snapshot!.value as! [String:[String:String]]
            let allLocalClipIds = self.allClips.map { c in
                c.id
            }
            let dateFormatter = ISO8601DateFormatter()
            
            for (_, d) in allClipsFromDB {
                let clipId = UUID(uuidString: d["id"]!)!
                if allLocalClipIds.contains(clipId) {
                    continue
                }
                
                print("Found new clip \(clipId.uuidString)")
                
                // Clip has not been seen locally, create stub
                let newClip = Clip(
                    id: clipId,
                    timestamp: dateFormatter.date(from: d["timestamp"]!)!,
                    projectId: self.id,
                    location: .remoteUndownloaded
                )
                
                // Pull clip thumbnail
                storageRef.child(newClip.id.uuidString).getData(maxSize: 1 * 1920 * 1080) { data, error in
                    if let error = error {
                        print(error)
                    } else {
                        if let image = UIImage(data: data!) {
                            newClip.thumbnail = image.pngData()
                        }
                    }
                }
                
                self.allClips.append(newClip)
            }
        })
        
        self.sortClips()
        
        // Pull project metadata
        let dbRefCreators = Database.database().reference().child(id.uuidString).child("creators")
        dbRefCreators.getData(completion: { error, snapshot in
            guard error == nil && snapshot != nil else {
                print(error!.localizedDescription)
                return
            }
            
            guard !(snapshot!.value! is NSNull) else {
                // No clips in RTDB, nothing to sync
                return
            }
            
            self.creators = snapshot!.value! as! [String: String]
        })
        
        let dbRefName = Database.database().reference().child(id.uuidString).child("name")
        dbRefName.getData(completion: {error, snapshot in
            guard error == nil && snapshot != nil else {
                print(error!.localizedDescription)
                return
            }
            
            guard !(snapshot!.value! is NSNull) else {
                // No clips in RTDB, nothing to sync
                return
            }
            self.name = snapshot!.value! as! String
        })
    }
    
    
    func pullNewClipVideos() {
        let storageRef = Storage.storage().reference().child(self.id.uuidString).child("videos")
        
        for (clip) in self.allClips.filter({ c in c.location == .remoteUndownloaded }) {
            print("Downloading video for \(clip.id.uuidString) from \(storageRef.child(clip.id.uuidString))")
            storageRef.child(clip.id.uuidString).write(toFile: clip.finalURL!) { url, error in
                if error != nil {
                    print("Error downloading video for \(clip.id.uuidString)")
                    return
                }
                
                clip.generateThumbnail()
                clip.location = .downloaded
                clip.status = .final
            }
        }
    }
    
    func networkAwareProjectDownload(shouldDownloadVideo: Bool = false) {
        pullNewClipMetadata()
        
        if shouldDownloadVideo {
            pullNewClipVideos()
        }
    }
    
    func appStartSync() {
        networkAwareProjectDownload() // Download remote changes before pushing up yours.
        networkAwareProjectUpload()
    }
    
    // MARK: — Codable
    private enum CoderKeys: String, CodingKey {
        case id
        case allClips
        case name
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CoderKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(allClips, forKey: .allClips)
        try container.encode(name, forKey: .name)
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CoderKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        allClips = try values.decode([Clip].self, forKey: .allClips)
        name = try values.decode(String.self, forKey: .name)
    }
}


// A Clip is one recording within a project
class Clip: Identifiable, Codable, ObservableObject {
    let id: UUID
    var timestamp: Date
    var creator: String
    let projectId: UUID
    @Published var status: ClipStatus
    @Published var thumbnail: Data?
    var location: ClipLocation
    
    enum ClipStatus: Codable {
        case temporary
        case final
    }
    
    enum ClipLocation: Codable {
        case local // Only exists on the device
        case remoteUnuploaded // Metadata in RTDB, video is not
        case uploaded // Metadata and video both uploaded (implies that it still remains on device)
        case remoteUndownloaded // Local has metadata of the clip, but no video file yet
        case downloaded // Metadta and video both downloaded from the DB (no upload responsibility)
    }
    
    init(id: UUID = UUID(), timestamp: Date = Date(), creator: String = "Unknown", projectId: UUID, location: ClipLocation = .local) {
        self.id = id
        self.timestamp = timestamp
        self.creator = creator
        self.projectId = projectId
        self.status = .temporary
        self.location = location
    }
    
    func generateThumbnail() {
        Task {
            do {
                guard self.finalURL != nil else {
                    print("Error generating thumbnail for \(self.id) — missing finalURL")
                    return
                }
                let asset = AVURLAsset(url: self.finalURL!)
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
    
    var temporaryURL: URL? {
        return URL(
            fileURLWithPath:
                (NSTemporaryDirectory() as NSString).appendingPathComponent(
                    (self.id.uuidString as NSString).appendingPathExtension("mov")!
                )
        )
    }
    
    var finalURL: URL? {
        do {
            let localStorageURL = try FileManager.default.url(
                for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            
            return localStorageURL.appendingPathComponent(id.uuidString).appendingPathExtension("mov")
        } catch {
            print("Could not generate finalURL")
            return nil
        }
    }
    
    // MARK: — Codable
    private enum CoderKeys: String, CodingKey {
        case id
        case timestamp
        case creator
        case projectId
        case status
        case thumbnail
        case location
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CoderKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(creator, forKey: .creator)
        try container.encode(projectId, forKey: .projectId)
        try container.encode(status, forKey: .status)
        try container.encode(thumbnail, forKey: .thumbnail)
        try container.encode(location, forKey: .location)
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CoderKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        timestamp = try values.decode(Date.self, forKey: .timestamp)
        creator = try values.decode(String.self, forKey: .creator)
        projectId = try values.decode(UUID.self, forKey: .projectId)
        status = try values.decode(ClipStatus.self, forKey: .status)
        thumbnail = try values.decode(Data.self, forKey: .thumbnail)
        location = try values.decode(ClipLocation.self, forKey: .location)
    }
}

