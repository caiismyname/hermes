//
//  PlaybackMOdel.swift
//  Hermes
//
//  Created by David Cai on 10/4/22.
//

import Foundation
import AVKit

class PlaybackModel:ObservableObject {
    var project: Project
    @Published var currentVideoIdx: Int
    var player = AVPlayer()
    
    init(project: Project, currentVideoIdx: Int = 0) {
        self.project = project
        self.currentVideoIdx = currentVideoIdx
        
        if self.project.allClips.count > 0 {
            player.replaceCurrentItem(with: generatePlayerItem(idx: 0))
        }
    }
    
    private func generatePlayerItem(idx: Int) -> AVPlayerItem? {
        let clip = self.project.allClips[idx]
        if let url = clip.finalURL {
            let playerItem = AVPlayerItem(url: url)
            player.actionAtItemEnd = .none // override this behavior with the Notification
            
            NotificationCenter.default.addObserver(
                self,
                selector:  #selector(nextVideo(notification:)),
                name: .AVPlayerItemDidPlayToEndTime,
                object: playerItem)
            
            self.project.markClipAsSeen(id: clip.id)
            
            return playerItem
        } else {
            return nil
        }
    }
    
    func playCurrentVideo() {
        if let item = generatePlayerItem(idx: self.currentVideoIdx) {
            self.player.replaceCurrentItem(with: item)
            self.player.play()
        }
    }
    
    @objc func nextVideo(notification: Notification) {
        // Already played last video
        if currentVideoIdx == project.allClips.count - 1 {
            return
        } else {
            currentVideoIdx += 1
        }
        
        if let item = generatePlayerItem(idx: currentVideoIdx) {
            player.replaceCurrentItem(with: item)
            player.play()
        }
    }
}
