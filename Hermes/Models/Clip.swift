//
//  Clip.swift
//  Hermes
//
//  Created by David Cai on 12/16/22.
//

import Foundation
import AVFoundation
import UIKit
import FirebaseCore
import FirebaseDatabase
import FirebaseStorage

// A Clip is one recording within a project
class Clip: Identifiable, Codable, ObservableObject {
    let id: UUID
    var timestamp: Date
    var creator: String
    let projectId: UUID
    @Published var status: ClipStatus
    @Published var thumbnail: Data?
    var location: ClipLocation
    @Published var videoLocation: VideoLocation
    @Published var metadataLocation: MetadataLocation
    @Published var seen: Bool
    
    enum ClipStatus: Codable {
        case temporary
        case final
        case invalid
    }
    
    enum VideoLocation: Codable {
        case deviceOnly
        case remoteOnly
        case deviceAndRemote
    }
    
    enum MetadataLocation: Codable {
        case deviceOnly
        case remoteOnly
        case deviceAndRemote
    }
    
    enum ClipLocation: Codable {
        case local // Only exists on the device
        case remoteUnuploaded // Metadata in RTDB, video is not (implies that it still remains on device)
        case uploaded // Metadata and video both uploaded (implies that it still remains on device)
        case remoteUndownloaded // Local has metadata of the clip, but no video file yet
        case downloaded // Metadta and video both downloaded from the DB (no upload responsibility)
    }
    
    init(id: UUID = UUID(), timestamp: Date = Date(), creator: String = "Unknown", projectId: UUID, location: ClipLocation = .local, seen: Bool = false, metadataLocation: MetadataLocation = .deviceOnly, videoLocation: VideoLocation = .deviceOnly) {
        self.id = id
        self.timestamp = timestamp
        self.creator = creator
        self.projectId = projectId
        self.status = .temporary
        self.location = location
        self.seen = seen
        self.metadataLocation = metadataLocation
        self.videoLocation = videoLocation
    }
    
    func downloadVideo() async {
        do {
            let storageRef = Storage.storage().reference().child(projectId.uuidString).child("videos")
            print("    Downloading video for \(id.uuidString) from \(storageRef.child(id.uuidString))")
            
            try await storageRef.child(id.uuidString).writeAsync(toFile: finalURL!)
            if self.thumbnail == nil {
                generateThumbnail()
            }
            
            DispatchQueue.main.async {
                self.location = .downloaded
                self.videoLocation = .deviceAndRemote
                self.status = .final
            }
            
        } catch {
            print("    Error downloading video for clip \(id.uuidString): \(error)")
            status = .invalid
        }
    }
    
    func downloadThumbnail() async {
        do {
            let storageRef = Storage.storage().reference().child(projectId.uuidString).child("thumbnails")
            print("    Downloading thumbnail for \(id.uuidString) from \(storageRef.child(id.uuidString))")
            
            await withCheckedContinuation { continuation in
                storageRef.child(id.uuidString).getData(maxSize: (1024 * 1024) / 2 /*500kb*/, completion: { data, error in
                    if error != nil {
                        print("    Error downloading thumbnail for clip \(self.id.uuidString): \(error)")
                    } else {
                        self.thumbnail = data
                    }
                    continuation.resume()
                })
            }
        }
    }
    
    func generateThumbnail() {
        Task {
            do {
                guard self.finalURL != nil else {
                    print("    Error generating thumbnail for \(self.id) — missing finalURL")
                    return
                }
                let asset = AVURLAsset(url: self.finalURL!)
                let timescale = try await asset.load(.duration).timescale
                let imgGenerator = AVAssetImageGenerator(asset: asset)
                imgGenerator.appliesPreferredTrackTransform = true
                
                if #available(iOS 16, *) {
                    let cgImage = try await imgGenerator.image(at: CMTime(value: 0, timescale: timescale)).image
                    self.thumbnail = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.6)
                } else {
                    // Fallback on earlier versions?
                    let cgImage = try imgGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: timescale), actualTime: nil)
                    self.thumbnail = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.6)
                }
            } catch {
                print("    Error generating thumbnail for \(self.id)")
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
        case seen
        case videoLocation
        case metadataLocation
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
        try container.encode(seen, forKey: .seen)
        try container.encode(videoLocation, forKey: .videoLocation)
        try container.encode(metadataLocation, forKey: .metadataLocation)
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
        seen = try values.decode(Bool.self, forKey: .seen)
        videoLocation = try values.decode(VideoLocation.self, forKey: .videoLocation)
        metadataLocation = try values.decode(MetadataLocation.self, forKey: .metadataLocation)
    }
}

