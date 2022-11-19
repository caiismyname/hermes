//
//  PlaybackMOdel.swift
//  Hermes
//
//  Created by David Cai on 10/4/22.
//

import Foundation
import AVKit

class PlaybackModel:ObservableObject {
    var model: ContentViewModel
    @Published var currentVideoIdx: Int
    @Published var currentVideoCreatorName = ""
    var player = AVQueuePlayer()
    
    init(model: ContentViewModel, currentVideoIdx: Int = 0) {
        self.model = model
        self.currentVideoIdx = currentVideoIdx
        
        // default to last clip
        if self.model.project.allClips.count > 0 {
            self.currentVideoIdx = model.project.allClips.count - 1
            self.currentVideoCreatorName = model.project.creators[model.project.allClips[currentVideoIdx].creator] ?? ""
            player.removeAllItems()
            player.insert(switchToClip(idx: self.currentVideoIdx)!, after: nil)
        }
    }
    
    private func switchToClip(idx: Int) -> AVPlayerItem? {
        let clip = self.model.project.allClips[idx]
        if clip.location == .remoteUndownloaded {
            Task {
                model.startWork()
                await clip.downloadVideo()
                model.stopWork()
            }
        }
        
        if let url = clip.finalURL {
            let playerItem = AVPlayerItem(url: url)
            player.actionAtItemEnd = .none // override this behavior with the Notification
            
            // Update current video info
            self.currentVideoIdx = idx
            self.currentVideoCreatorName = model.project.creators[model.project.allClips[currentVideoIdx].creator] ?? ""
            
            NotificationCenter.default.addObserver(
                self,
                selector:  #selector(nextVideo(notification:)),
                name: .AVPlayerItemDidPlayToEndTime,
                object: playerItem)
            
            return playerItem
        } else {
            return nil
        }
    }
    
    func playCurrentVideo() {
        if let item = switchToClip(idx: self.currentVideoIdx) {
            self.player.removeAllItems()
            self.player.insert(item, after: nil)
            self.player.play()
            self.model.project.allClips[currentVideoIdx].seen = true
            self.model.project.computeUnseenCount()
        }
    }
    
    @objc func nextVideo(notification: Notification) {
        // Already played last video
        if currentVideoIdx == model.project.allClips.count - 1 {
            return
        } else {
            currentVideoIdx += 1
            self.currentVideoCreatorName = model.project.creators[model.project.allClips[currentVideoIdx].creator] ?? ""
        }
        
        if let item = switchToClip(idx: currentVideoIdx) {
            self.player.removeAllItems()
            self.player.insert(item, after: nil)
            player.play()
            self.model.project.allClips[currentVideoIdx].seen = true
            self.model.project.computeUnseenCount()
        }
    }
    
    func deleteClip(id: UUID) {
        let deletedClipIdx = model.project.allClips.firstIndex { c in
            c.id == id
        } ?? -1
        
        if deletedClipIdx != -1 && deletedClipIdx <= self.currentVideoIdx {
            self.currentVideoIdx -= 1
        }
        
        Task {
            await model.project.deleteClip(id: id)
        }
    }
}
