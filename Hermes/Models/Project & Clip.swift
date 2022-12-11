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
    var creators: [String: String] = [String: String]()
    @Published var allClips: [Clip]
    private var currentlyRecording = false
    private var currentClip: Clip? = nil
    @Published var unseenCount = 0
    @Published var lastClip: Clip?
    
    // For WaitingSpinner
    @Published var workProgress = 0.0
    @Published var workTotal = 0.0
    @Published var spinnerLabel = ""
    
    init(uuid: UUID = UUID(), name: String = "New Project", allClips: [Clip] = []) {
        self.id = uuid
        self.name = name
        self.allClips = allClips
        self.sortClips()
        self.lastClip = allClips.last
        
        computeUnseenCount()
    }

    func startClip() -> Clip? {
        guard !currentlyRecording else {
            return nil
        }
        
        self.currentClip = Clip(creator: me?.id ?? "", projectId: id, seen: true) // Mark as seen because we created it
        self.currentlyRecording = true
        
        print("Allocated a new clip \(self.currentClip!.id.uuidString) with temp URL \(String(describing: self.currentClip!.temporaryURL))")
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
            self.sortClips()
            
        } catch {
            print ("Error moving clip from temp to user home directory: \(error)")
        }
    }
    
    private func sortClips() {
        DispatchQueue.main.async {
            self.allClips.sort { a, b in
                return (a.timestamp < b.timestamp)
            }
            
            self.lastClip = self.allClips.last
        }
    }
    
    func computeUnseenCount() {
        DispatchQueue.main.async {
            self.unseenCount = self.allClips.filter { c in (!c.seen && c.status == .final) }.count
        }
    }
    
    func generateURL() -> URL {
        return URL(string: "\(URLSchema.baseURL)\(self.id.uuidString)")!
    }
    
    func deleteClip(id: UUID) async {
        print("    Deleting clip locally \(id.uuidString)")
        await deleteClipFromFB(id: id)
        let clip = self.allClips.first(where: { c in c.id == id })
        if !(clip?.seen ?? true) {
            self.unseenCount -= 1
        }
        self.allClips.removeAll { c in c.id == id }
        self.sortClips()
    }
    
    // MARK: Firebase
    func createRTDBEntry() {
        let ref = Database.database().reference()
        
        // Create DB
        ref.child(self.id.uuidString).setValue(
            [
                "name": self.name,
                "clips": [], // should be empty right now
                "creators": [me!.id: me!.name]
            ]
        )
    }
    
    func saveMetadataToRTDB() async {
        print("Uploading metadata for project \(self.id.uuidString) to RTDB")
        do {
            let dbRef = Database.database().reference()
            let thumbnailRef = Storage.storage().reference().child(self.id.uuidString).child("thumbnails")
            let localClips = allClips.filter({ $0.location == .local })
            
            prepareWorkProgress(label: "Uploading \"\(self.name)\"", total: Double(localClips.count) * 2.0 /*Double because thumbnails and meta are uploaded separately*/)
            
            for c in localClips {
                guard c.finalURL != nil else {
                    print("Error uploading clip \(c.id.uuidString) — missing finalURL")
                    return
                }
                
                // Upload clip metadata
                await withCheckedContinuation { continuation in
                    dbRef.child(self.id.uuidString).child("clips").childByAutoId().setValue(
                        [
                            "id": c.id.uuidString,
                            "timestamp": c.timestamp.ISO8601Format(),
                            "creator": me!.id
                        ]
                    ) { error, _ in
                        guard error == nil else {
                            print(error!)
                            continuation.resume()
                            return
                        }
                        
                        // Then upload the clip's id to clipIdIndex
                        dbRef.child(self.id.uuidString).child("clipIdIndex").child(c.id.uuidString).setValue(true)
                        DispatchQueue.main.async {
                            self.workProgress += 1.0
                        }
                        continuation.resume()
                    }
                }
                
                // Upload thumbnails
                if c.thumbnail != nil {
                    await withCheckedContinuation { continuation in
                        let thumbnailMetadata = StorageMetadata()
                        thumbnailMetadata.contentType = "image/jpeg"
                        
                        thumbnailRef.child(c.id.uuidString).putData(c.thumbnail ?? Data(), metadata: thumbnailMetadata) { metadata, error in
                            guard let metadata = metadata else {
                                print(error?.localizedDescription ?? "Error uploading thumbnail for \(c.id.uuidString)")
                                continuation.resume()
                                return
                            }
                            
                            print("    Uploaded thumbnail for \(c.id.uuidString). [\(metadata.size)]")
                            DispatchQueue.main.async {
                                self.workProgress += 1.0
                            }
                            continuation.resume()
                        }
                    }
                }

                c.location = .remoteUnuploaded
            }
            
            // Upload project metadata
            try await dbRef.child(self.id.uuidString).child("name").setValue(self.name)
            if let meId = self.me?.id { // Idk I keep getting a crash here
                try await dbRef.child(self.id.uuidString).child("creators").child(meId).setValue(self.me!.name) // only update your own name, not the whole list
            }
        } catch {
            print(error)
        }
        
        resetWorkProgress()
    }
    
    func saveVideosToRTDB() async {
        print("Uploading videos for project \(self.id.uuidString) to DB")
        
        let storageRef = Storage.storage().reference().child(self.id.uuidString)
        let remoteUnuploadedClips = allClips.filter({ $0.location == .remoteUnuploaded }) // Metadata has to be uploaded first, hence .remoteUnuploaded
        
        prepareWorkProgress(label: "Uploading videos", total: Double(remoteUnuploadedClips.count))
        
        for c in remoteUnuploadedClips {
            let videoRef = storageRef.child("videos").child(c.id.uuidString)
            await withCheckedContinuation { continuation in
                videoRef.putFile(from: c.finalURL!) { (metadata, error) in
                    guard let metadata = metadata else {
                        print(error?.localizedDescription ?? "Error uploading video for \(c.id.uuidString)")
                        continuation.resume()
                        return
                    }
                    
                    print("    Uploaded video for \(c.id.uuidString). [\(metadata.size) bytes]")
                    c.location = .uploaded
                    DispatchQueue.main.async {
                        self.workProgress += 1.0
                    }
                    continuation.resume()
                }
            }
        }
        
        resetWorkProgress()
    }
    
    func networkAwareProjectUpload(shouldUploadVideo: Bool = false) async {
        await saveMetadataToRTDB()
        
        if shouldUploadVideo {
            await saveVideosToRTDB()
        }
    }
    
    private func reconcileDeletionsWithLocalClips(allFBClips: [UUID]) async {
//        let allLocalClips = self.allClips.map { c in c.id }
        var toDelete = [UUID]()
        for c in self.allClips {
            if !allFBClips.contains(c.id) && c.location != .local {
                toDelete.append(c.id)
            }
        }
        
        if toDelete.isEmpty {
            print("    Found no deletions needing reconciliation with FB")
        } else {
            print("    The following clips were deleted in FB and will be deleted from the device: \(toDelete.map {c in c.uuidString })")
        }
        
        await withThrowingTaskGroup(of: Void.self) { group in
            for c in toDelete {
                group.addTask {
                    await self.deleteClip(id: c)
                }
            }
        }
    }
    
    func prepareWorkProgress(label: String = "", total: Double = 0.0) {
        DispatchQueue.main.async {
            self.workProgress = 0.0
            self.workTotal = total * 1.10 // Temp, so we show an empty bar
            self.spinnerLabel = label
        }
    }
    
    func resetWorkProgress() {
        DispatchQueue.main.async {
            // Reset spinner for next use
            self.workTotal = 0.0
            self.workProgress = 0.0
            self.spinnerLabel = ""
        }
    }
    
    func pullNewClipMetadata() async {
        do {
            print("Pulling new clip metadata for project \(id.uuidString)")
            
            prepareWorkProgress(label: "Syncing \"\(self.name)\"")
            
            let dbRef = Database.database().reference().child(id.uuidString).child("clips")
            
            let snapshot = try await dbRef.getData()
            guard !(snapshot.value! is NSNull) else {
                print("    No clips found in RTDB")
                return
            } // No clips in RTDB, nothing to sync
            
            let allClipsFromFB = snapshot.value as! [String:[String:String]]
            var allClipsFromFBIds = [UUID]()
            let allLocalClipIds = self.allClips.map { c in c.id }
            var seenNewClipIds = [UUID]()
            let dateFormatter = ISO8601DateFormatter()
            
            DispatchQueue.main.async {
                self.workTotal = Double(allClipsFromFB.count) * 1.10 // Set real total once we know it, with a buffer for misc. tasks after network activity
            }
            
            
            await withTaskGroup(of: Void.self) { group in
                for (_, d) in allClipsFromFB {
                    let clipId = UUID(uuidString: d["id"]!)!
                    allClipsFromFBIds.append(clipId)
                    
                    if allLocalClipIds.contains(clipId) {
                        continue
                    }
                    
                    print("    Found new clip \(clipId.uuidString)")
                    
                    // Clip has not been seen locally, create stub
                    let newClip = Clip(
                        id: clipId,
                        timestamp: dateFormatter.date(from: d["timestamp"]!)!,
                        creator: d["creator"] ?? "",
                        projectId: self.id,
                        location: .remoteUndownloaded
                    )
                    
                    if !seenNewClipIds.contains(clipId) { // Doublecheck against dupes
                        self.allClips.append(newClip)
                        seenNewClipIds.append(clipId)
                        
                        // If we pass the dupe check, download the thumbnail in parallel
                        group.addTask {
                            await newClip.downloadThumbnail()
                        }
                    }
                }
                
                for await _ in group {
                    DispatchQueue.main.async {
                        self.workProgress += 1.0
                    }
                }
            }
            
            if !seenNewClipIds.isEmpty { // Prevent unncessary re-sorting as every sort causes a flash on the playback button thumbnail
                self.sortClips()
            }
            
            await reconcileDeletionsWithLocalClips(allFBClips: allClipsFromFBIds)
            
            // Pull project metadata
            let dbRefCreators = Database.database().reference().child(id.uuidString).child("creators")
            let creatorsSnapshot = try await dbRefCreators.getData()
            if !(creatorsSnapshot.value! is NSNull) {
                self.creators = creatorsSnapshot.value! as! [String: String]
            } else {
                print("    No project creators found")
            }
            
            let dbRefName = Database.database().reference().child(id.uuidString).child("name")
            let projectNameSnapshot = try await dbRefName.getData()
            if !(projectNameSnapshot.value! is NSNull) {
                DispatchQueue.main.async {
                    self.name = projectNameSnapshot.value! as! String
                }
            } else {
                print("    No project name found")
            }
        } catch {
            print(error)
        }
        
        resetWorkProgress()
    }
    
    
    func pullVideosForNewClips() async {
        await withTaskGroup(of: Void.self) { group in
            prepareWorkProgress(label: "Downloading videos")
            
            let clipsToDownload = self.allClips.filter({ c in c.location == .remoteUndownloaded })
            
            DispatchQueue.main.async {
                self.workTotal = Double(clipsToDownload.count) * 1.10
            }
            
            
            for clip in clipsToDownload {
                group.addTask {
                    await clip.downloadVideo()
                }
            }
            
            for await _ in group {
                DispatchQueue.main.async {
                    self.workProgress += 1.0
                }
            }
        }
        
        DispatchQueue.main.async {
            self.allClips = self.allClips.filter({ c in c.status != .invalid })
            self.sortClips()
        }
        
        resetWorkProgress()
    }
    
    func networkAwareProjectDownload(shouldDownloadVideo: Bool = false) async {
        await pullNewClipMetadata()
        
        if shouldDownloadVideo {
            await pullVideosForNewClips()
        }
        
        computeUnseenCount()
    }
    
    func appStartSync() async {
        await networkAwareProjectDownload() // Download remote changes before pushing up yours.
        await networkAwareProjectUpload()
    }
    
    private func getFirebaseIdForClip(id: UUID) async -> String? {
        let dbRef = Database.database().reference().child(self.id.uuidString).child("clips")
        let (snapshot, _) = await dbRef.queryOrdered(byChild: "id").queryEqual(toValue: id.uuidString).observeSingleEventAndPreviousSiblingKey(of: .value)
        if let value = snapshot.value! as? [String:[String: String]] {
            let fbId = value.keys.first
            return fbId
        } else {
            return nil
        }
    }
    
    private func deleteClipFromFB(id: UUID) async {
        do {
            print("    Deleting clip from DB \(id.uuidString)")
            let clipKey = await getFirebaseIdForClip(id: id)
            if clipKey != nil {
                print("    Firebase ID: \(clipKey)")
                let storageRef = Storage.storage().reference().child(self.id.uuidString).child("videos").child(id.uuidString)
                let clipRef = Database.database().reference().child(self.id.uuidString).child("clips").child(clipKey!)
                try await clipRef.removeValue()
                try await storageRef.delete()
                // NOTE: We are intentionally NOT removing the clip ID from the clipIDIndex to serve as a backup against the clip being re-added by another client after deletion
            }
        } catch {
            print("    Could not delete clip from DB \(error)")
        }
    }
    
    // MARK: — Codable
    enum CoderKeys: String, CodingKey {
        case id
        case allClips
        case name
        case creators
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CoderKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(allClips, forKey: .allClips)
        try container.encode(name, forKey: .name)
        try container.encode(creators, forKey: .creators)
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CoderKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        allClips = try values.decode([Clip].self, forKey: .allClips)
        name = try values.decode(String.self, forKey: .name)
        creators = try values.decode([String: String].self, forKey: .creators)
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
    @Published var seen: Bool
    
    enum ClipStatus: Codable {
        case temporary
        case final
        case invalid
    }
    
    enum ClipLocation: Codable {
        case local // Only exists on the device
        case remoteUnuploaded // Metadata in RTDB, video is not (implies that it still remains on device)
        case uploaded // Metadata and video both uploaded (implies that it still remains on device)
        case remoteUndownloaded // Local has metadata of the clip, but no video file yet
        case downloaded // Metadta and video both downloaded from the DB (no upload responsibility)
    }
    
    init(id: UUID = UUID(), timestamp: Date = Date(), creator: String = "Unknown", projectId: UUID, location: ClipLocation = .local, seen: Bool = false) {
        self.id = id
        self.timestamp = timestamp
        self.creator = creator
        self.projectId = projectId
        self.status = .temporary
        self.location = location
        self.seen = seen
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
    }
}

