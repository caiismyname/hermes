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
    var player = AVQueuePlayer()
    
    init(model: ContentViewModel, currentVideoIdx: Int = 0) {
        self.model = model
        self.currentVideoIdx = currentVideoIdx
        
        if self.model.project.allClips.count > 0 {
            player.removeAllItems()
            player.insert(generatePlayerItem(idx: 0)!, after: nil)
        }
    }
    
    private func generatePlayerItem(idx: Int) -> AVPlayerItem? {
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
        if let item = generatePlayerItem(idx: self.currentVideoIdx) {
            self.player.removeAllItems()
            self.player.insert(item, after: nil)
            self.player.play()
            self.model.project.allClips[currentVideoIdx].seen = true
        }
    }
    
    @objc func nextVideo(notification: Notification) {
        // Already played last video
        if currentVideoIdx == model.project.allClips.count - 1 {
            return
        } else {
            currentVideoIdx += 1
        }
        
        if let item = generatePlayerItem(idx: currentVideoIdx) {
            self.player.removeAllItems()
            self.player.insert(item, after: nil)
            player.play()
            self.model.project.allClips[currentVideoIdx].seen = true
        }
    }
}
