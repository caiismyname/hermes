//
//  PlaybackMOdel.swift
//  Hermes
//
//  Created by David Cai on 10/4/22.
//

import Foundation
import AVKit

@MainActor
class PlaybackModel:ObservableObject {
    let project: Project
    @Published var currentVideoIdx: Int
    @Published var currentVideoCreatorName = ""
    @Published var currentVideoTimestamp = Date()
    @Published var currentVideoCanPlay = false
    var player = AVQueuePlayer()
    
    init(project: Project, currentVideoIdx: Int = 0) {
        self.project = project
        self.currentVideoIdx = currentVideoIdx
        
        // default to last clip
        if self.project.allClips.count > 0 {
            self.currentVideoIdx = project.allClips.count - 1
            setCurrentClipMetadata()
            playCurrentVideo(shouldPlay: false)
        }
    }
    
    private func setCurrentClipMetadata() {
        self.currentVideoCreatorName = project.creators[project.allClips[currentVideoIdx].creator] ?? ""
        self.currentVideoTimestamp = project.allClips[currentVideoIdx].timestamp
    }
    
    private func switchToClip(idx: Int) -> AVPlayerItem? {
        guard idx >= 0 && project.allClips.count > 0 else { return nil }
        let clip = self.project.allClips[idx]
        var videoCanPlay = false
        var playerItem: AVPlayerItem? = nil
        
        // Update current video info
        self.currentVideoIdx = idx
        setCurrentClipMetadata()

//        if clip.location != .remoteUndownloaded, let url = clip.finalURL {
        if clip.videoLocation != .remoteOnly, let url = clip.finalURL {
            playerItem = AVPlayerItem(url: url)
            player.actionAtItemEnd = .none // override this behavior with the Notification
            
            NotificationCenter.default.addObserver(
                self,
                selector:  #selector(nextVideo(notification:)),
                name: .AVPlayerItemDidPlayToEndTime,
                object: playerItem)
            
            // Note that this only returns a player if we have a video for it
            videoCanPlay = true
        } else {
            // It's fine if we return nil here. UI will pick it up and display the placeholder thumbnail instead
            videoCanPlay = false
        }
        
        self.currentVideoCanPlay = videoCanPlay
        return playerItem
    }
    
    func playCurrentVideo(shouldPlay: Bool = true) {
        if let item = switchToClip(idx: self.currentVideoIdx) {
            self.player.removeAllItems()
            self.player.insert(item, after: nil)
            if shouldPlay {
                self.player.play()
                self.project.allClips[currentVideoIdx].seen = true
                self.project.computeUnseenCount()
            }
        } else {
            // No video downloaded yet
            let clip = self.project.allClips[currentVideoIdx]
            print("    Video not downloaded. Location: \(clip.location)")
//            if clip.location == .remoteUndownloaded {
            if clip.videoLocation == .remoteOnly {
                Task {
                    project.prepareWorkProgress(label: "Downloading video", total: 0.0)
                    project.startWork()
                    
                    await clip.downloadVideo()
                    DispatchQueue.main.async {
                        self.currentVideoCanPlay = true
                    }
                    project.stopWork()
                    
                    // Once downloaded, try playing it again
                    guard(clip.location != .remoteUndownloaded) else {
                        print("Video still hasn't downloaded. Aborting attempt to play.")
                        return
                    }
                    playCurrentVideo(shouldPlay: shouldPlay)
                }
            }
        }
    }
    
    func playNVideo(n: Int) {
        self.currentVideoIdx = n
        playCurrentVideo()
    }
    
    @objc func nextVideo(notification: Notification) {
        // Already played last video
        if currentVideoIdx >= project.allClips.count - 1 {
            return
        } else {
            currentVideoIdx += 1
            setCurrentClipMetadata()
        }
        
        playCurrentVideo()
    }
    
    func deleteClip(id: UUID) async {
        let deletedClipIdx = project.allClips.firstIndex { c in
            c.id == id
        } ?? -1
        
        await project.deleteClip(id: id)
        
        // Ordering is important, make sure the clip is deleted before changing the currentVideoIdx, otherwise the scroll might try to access into an empty list because the list is slow to update
        if deletedClipIdx != -1 && deletedClipIdx <= self.currentVideoIdx {
            self.currentVideoIdx -= 1
            if let item = switchToClip(idx: self.currentVideoIdx) {
                self.player.removeAllItems()
                self.player.insert(item, after: nil)
            }
        }
    }
}
