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
    // Project and video metadata
    var id: UUID
    var me: Me?
    var creators: [String: String] = [String: String]() // [uuid: display name]
    @Published var name: String
    @Published var allClips: [Clip]
    
    // UI handling
    private var currentlyRecording = false
    private var currentClip: Clip? = nil
    @Published var unseenCount = 0
    @Published var lastClip: Clip?
    
    // Upgrade handling
    @Published var projectLevel: ProjectLevel
    var owner: String
    @Published var inviteEnabled = false  // Either you've created the project (and therefore are the owner), in which case this defaults to false, or you were invited, in which case it doesn't matter what this value is
    
    // WaitingSpinner status
    @Published var workProgress = 0.0
    @Published var workTotal = 0.0
    @Published var spinnerLabel = ""
    @Published var isWorking = 0
    
    init(uuid: UUID = UUID(), name: String = "New Project", allClips: [Clip] = [], owner: String, me: Me = Me(id: "", name: "")) {
        self.id = uuid
        self.name = name
        self.allClips = allClips
        self.projectLevel = .free
        self.owner = owner
        self.me = me
        if me.id != "" {
            self.creators[me.id] = me.name
        }
        
        self.sortClips()
        self.lastClip = allClips.last
        computeUnseenCount()
    }

    // MARK: - Clip Management
    func startClip() -> Clip? {
        guard !currentlyRecording else {
            return nil
        }
        
        self.currentClip = Clip(creator: me?.id ?? "", projectId: id, seen: true, metadataLocation: .deviceOnly, videoLocation: .deviceOnly) // Mark as seen because we created it
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
    
    // MARK: - Progress View
    func prepareWorkProgress(label: String = "", total: Double = 0.0) {
        DispatchQueue.main.async {
            self.workProgress = 0.0
            self.workTotal = total * 1.10 // Temp, so we show an empty bar
            self.spinnerLabel = label
        }
    }
    
    func startWork() {
        DispatchQueue.main.async {
            self.isWorking += 1
        }
    }
    
    func stopWork() {
        DispatchQueue.main.async {
            self.isWorking -= 1
        }
        
        resetWorkProgress()
    }
    
    private func resetWorkProgress() {
        DispatchQueue.main.async {
            // Reset spinner for next use
            self.workTotal = 0.0
            self.workProgress = 0.0
            self.spinnerLabel = ""
        }
    }
    
    // MARK: - Upgrades
    
    func canInviteMembers() -> Bool {
        if projectLevel == .free {
            return creators.count < ProjectLevels.free.memberLimit
        } else if projectLevel == .upgrade1 {
            return creators.count < ProjectLevels.upgrade1.memberLimit
        } else {
            // This is some error
            return false
        }
    }
    
    func canAddClip() -> Bool {
        if projectLevel == .free {
            return allClips.count < ProjectLevels.free.clipLimit
        } else if projectLevel == .upgrade1 {
            return allClips.count < ProjectLevels.upgrade1.clipLimit
        } else {
            // This is some error
            return false
        }
    }
    
    func isOwner() -> Bool {
        return self.me?.id == self.owner
    }
    
    func upgradeProject(upgradeLevel: ProjectLevel) async -> Bool {
        print("Upgrading project to \(upgradeLevel.rawValue)")
        await checkAndCreateRTDBEntry()
        let success = await upgradeProjectInFB(upgradeLevel: upgradeLevel)
        if success {
            DispatchQueue.main.async {
                self.projectLevel = upgradeLevel
            }
        }
        
        return success
    }
    
    func setInviteSetting(isEnabled: Bool) async -> Bool  {
        print("Setting invite setting to \(isEnabled)")
        await checkAndCreateRTDBEntry()
        let success = await setInviteSettingInFB(isEnabled: isEnabled)
        if success {
            DispatchQueue.main.async {
                self.inviteEnabled = isEnabled
            }
        }
        
        return success
    }
    
    // MARK: - Firebase
    
    func checkAndCreateRTDBEntry() async {
        do {
            let (snapshot, _) = await Database.database().reference().child(id.uuidString).child("name").observeSingleEventAndPreviousSiblingKey(of: .value)
            if snapshot.exists() {
                print("    Project exists in FB")
                return
            } else {
                print("    Project has not been created in FB yet. Creating entry for  \(id.uuidString)")
                try await Database.database().reference().child(self.id.uuidString).setValue([
                    "owner": me!.id,
                    "creators": self.creators
                ])
                
                try await Database.database().reference().child(self.id.uuidString).setValue(
                    [
                        "clips": [], // Should be empty when project is created, to be filled when the clips are individually uploaded
                        "name": self.name,
                        "projectLevel": ProjectLevel.free.rawValue,
                        "inviteEnabled": inviteEnabled
                    ]
                )
            }
        } catch {
            print("    Error creating initial FB entry for project \(id.uuidString)")
            print(error)
        }
    }
    
    func pushUnuploadedClipMetadata() async {
        print("Uploading clip metadata for project \(self.id.uuidString) to RTDB")
        let dbRef = Database.database().reference()
        let thumbnailRef = Storage.storage().reference().child(self.id.uuidString).child("thumbnails")
        let clipsToUpload = allClips.filter({ $0.metadataLocation == .deviceOnly })
        
        
        prepareWorkProgress(label: "Uploading \"\(self.name)\"", total: Double(clipsToUpload.count) * 2.0 /*Double because thumbnails and meta are uploaded separately*/)
        
        for c in clipsToUpload {
            guard c.finalURL != nil else {
                print("Error uploading clip \(c.id.uuidString) — missing finalURL")
                return
            }
            
            // Upload metadata
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
            
            // Upload thumbnail
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

            DispatchQueue.main.async {
                c.location = .remoteUnuploaded
                c.metadataLocation = .deviceAndRemote
            }
        }
        
        resetWorkProgress()
    }
    
    func pushUnuploadedClipVideos() async {
        print("Uploading clip videos for project \(self.id.uuidString) to DB")
        
        let storageRef = Storage.storage().reference().child(self.id.uuidString)
        let clipsToUpload = allClips.filter({ $0.videoLocation == .deviceOnly })
        
        prepareWorkProgress(label: "Uploading videos", total: Double(clipsToUpload.count))
        
        for c in clipsToUpload {
            let videoRef = storageRef.child("videos").child(c.id.uuidString)
            await withCheckedContinuation { continuation in
                videoRef.putFile(from: c.finalURL!) { (metadata, error) in
                    guard let metadata = metadata else {
                        print(error?.localizedDescription ?? "Error uploading video for \(c.id.uuidString)")
                        continuation.resume()
                        return
                    }
                    
                    print("    Uploaded video for \(c.id.uuidString). [\(metadata.size) bytes]")
                    DispatchQueue.main.async {
                        self.workProgress += 1.0
                        c.location = .uploaded
                        c.videoLocation = .deviceAndRemote
                    }
                    continuation.resume()
                }
            }
        }
        
        resetWorkProgress()
    }
    
    func pushProjectMetadata() async {
        do {
            await checkAndCreateRTDBEntry()
            
            print("Pushing project metadata for \(id.uuidString)")
            let dbRef = Database.database().reference().child(self.id.uuidString)
            
            // Project name
            try await dbRef.child("name").setValue(self.name)
            
            // Rewrite Me name in creators list, in case display name changed
            if let meId = self.me?.id { // Idk I keep getting a crash here
                try await dbRef.child("creators").child(meId).setValue(self.me!.name) // Only update your own name, not the whole list
            }
            
            /*
             This function does not handle setting of upgrade info (projectLevel, inviteEnabled).
             Those values are synced as they are changed in UI, not batched with the rest of the content.
             */
        } catch {
            print ("    Error uploading project metadata")
            print(error)
        }
    }
    
    func pullProjectMetadata() async {
        do {
            print("Pulling project metadata for project \(id.uuidString)")
            
            // Creators
            let dbRefCreators = Database.database().reference().child(id.uuidString).child("creators")
            let creatorsSnapshot = try await dbRefCreators.getData()
            if !(creatorsSnapshot.value! is NSNull) {
                for (creatorId, creatorName) in creatorsSnapshot.value! as! [String: String] {
                    self.creators[creatorId] = creatorName
                    // This is currently an append-only operation, no deletes
                }
            } else {
                print("    No project creators found")
            }
            
            // Project name
            let dbRefName = Database.database().reference().child(id.uuidString).child("name")
            let projectNameSnapshot = try await dbRefName.getData()
            if !(projectNameSnapshot.value! is NSNull) {
                DispatchQueue.main.async {
                    self.name = projectNameSnapshot.value! as! String
                }
            } else {
                print("    No project name found")
            }
            
            // Project level
            let dbRefLevel = Database.database().reference().child(id.uuidString).child("projectLevel")
            let projectLevelSnapshot = try await dbRefLevel.getData()
            if !(projectLevelSnapshot.value! is NSNull) {
                DispatchQueue.main.async {
                    self.projectLevel = ProjectLevel(rawValue: projectLevelSnapshot.value! as! String) ?? ProjectLevel.free
                }
            } else {
                print("    No project level found")
            }
            
            // Invite Enabled
            let dbRefInvite = Database.database().reference().child(id.uuidString).child("inviteEnabled")
            let projectInviteSnapshot = try await dbRefInvite.getData()
            if !(projectInviteSnapshot.value! is NSNull) {
                DispatchQueue.main.async {
                    self.inviteEnabled = projectInviteSnapshot.value! as! Bool
                }
            } else {
                print("    No invite setting status found")
            }
            
        } catch {
            print("    Error pulling project metadata")
            print(error)
        }
    }
    
    func pullNewClipMetadata() async -> [Clip] {
        do {
            print("Pulling new clip metadata for project \(id.uuidString)")
            prepareWorkProgress(label: "Syncing \"\(self.name)\"")
            
            let dbRef = Database.database().reference().child(id.uuidString).child("clips")
            let snapshot = try await dbRef.getData()
            guard !(snapshot.value! is NSNull) else {
                print("    No clips found in RTDB")
                return [Clip]()
            } // No clips in RTDB, nothing to sync
            
            let allClipsFromFB = snapshot.value as! [String:[String:String]]
            var allClipsFromFBIds = [UUID]()
            let allLocalClipIds = self.allClips.map { c in c.id }
            var seenNewClipIds = [UUID]()
            var createdClips = [Clip]()
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
                        location: .remoteUndownloaded,
                        metadataLocation: .deviceAndRemote,
                        videoLocation: .remoteOnly
                    )
                    
                    if !seenNewClipIds.contains(clipId) { // Doublecheck against dupes
                        self.allClips.append(newClip)
                        seenNewClipIds.append(clipId)
                        createdClips.append(newClip)
                        
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
            
            resetWorkProgress()
            return createdClips
            
        } catch {
            print(error)
            resetWorkProgress()
            return [Clip]()
        }
    }
    
    func pullNewClipVideos(newClips: [Clip]) async {
        await withTaskGroup(of: Void.self) { group in
            prepareWorkProgress(label: "Downloading videos")
            
            DispatchQueue.main.async {
                self.workTotal = Double(newClips.count) * 1.10
            }
            
            
            for clip in newClips {
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
    
    func networkAwareProjectUpload(shouldUploadVideo: Bool = false) async {
        await pushProjectMetadata()
        await pushUnuploadedClipMetadata()
        
        if shouldUploadVideo {
            await pushUnuploadedClipVideos()
        }
    }
    
    func networkAwareProjectDownload(shouldDownloadVideo: Bool = false) async {
        await pullProjectMetadata()
        let newClips = await pullNewClipMetadata()
        
        if shouldDownloadVideo {
            await pullNewClipVideos(newClips: newClips)
        }
        
        computeUnseenCount()
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
    
    private func upgradeProjectInFB(upgradeLevel: ProjectLevel) async -> Bool {
        do {
            let dbRef = Database.database().reference().child(self.id.uuidString)
            try await dbRef.child("projectLevel").setValue(upgradeLevel.rawValue)
            return true
        } catch {
            print("    Could not set projectLevel in FB")
            print(error)
            return false
        }
    }
    
    private func setInviteSettingInFB(isEnabled: Bool) async -> Bool  {
        do {
            let dbRef = Database.database().reference().child(self.id.uuidString)
            try await dbRef.child("invite").setValue(isEnabled)
            return true
        } catch {
            print("    Could not set Invite Setting in FB")
            print(error)
            return false
        }
    }
    
    func setProjectNameInFB(newName : String) async -> Bool {
        do {
            let dbRef = Database.database().reference().child(self.id.uuidString)
            try await dbRef.child("name").setValue(newName)
            return true
        } catch {
            print("    Could not set Project Name in FB")
            print(error)
            return false
        }
    }

    // MARK: - Codable
    enum CoderKeys: String, CodingKey {
        case id
        case allClips
        case name
        case creators
        case projectLevel
        case owner
        case inviteEnabled
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CoderKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(allClips, forKey: .allClips)
        try container.encode(name, forKey: .name)
        try container.encode(creators, forKey: .creators)
        try container.encode(projectLevel, forKey: .projectLevel)
        try container.encode(owner, forKey: .owner)
        try container.encode(inviteEnabled, forKey: .inviteEnabled)
        
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CoderKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        allClips = try values.decode([Clip].self, forKey: .allClips)
        name = try values.decode(String.self, forKey: .name)
        creators = try values.decode([String: String].self, forKey: .creators)
        projectLevel = try values.decode(ProjectLevel.self, forKey: .projectLevel)
        owner = try values.decode(String.self, forKey: .owner)
        inviteEnabled = try values.decode(Bool.self, forKey: .inviteEnabled)
    }
}
