//
//  PlaybackMOdel.swift
//  Hermes
//
//  Created by David Cai on 10/4/22.
//

import Foundation
import AVKit

class PlaybackModel:ObservableObject {
    @Published var allClips: [Clip]
    @Published var currentVideoIdx: Int
    var player = AVPlayer()
    
    init(allClips: [Clip], currentVideoIdx: Int = 0) {
        self.allClips = allClips
        self.currentVideoIdx = currentVideoIdx
    }
    
    func currentVideo() -> AVPlayer? {
        let clip = self.allClips[self.currentVideoIdx]
        if let url = clip.finalURL {
            let playerItem = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: playerItem)
            player.actionAtItemEnd = .none // override this behavior with the Notification
            
            NotificationCenter.default.addObserver(
                self,
                selector:  #selector(nextVideo(notification:)),
                name: .AVPlayerItemDidPlayToEndTime,
                object: playerItem)
            
            return player
        } else {
            return nil
        }
    }
    
    @objc func nextVideo(notification: Notification) {
        // Already played last video
        if currentVideoIdx == allClips.count - 1 {
            return
        } else {
            currentVideoIdx += 1
        }
        
        if let url = self.allClips[currentVideoIdx].finalURL {
            let playerItem = AVPlayerItem(url: url)
            NotificationCenter.default.addObserver(
                self,
                selector:  #selector(nextVideo(notification:)),
                name: .AVPlayerItemDidPlayToEndTime,
                object: playerItem
            )
            
            player.replaceCurrentItem(with: AVPlayerItem(url: url))
            player.play()
        }
    }
    
    
    func firstVideo() -> URL? {
        currentVideoIdx = 0
        return allClips[currentVideoIdx].finalURL
    }
    
}
