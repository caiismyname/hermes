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
            player.replaceCurrentItem(with: AVPlayerItem(url: url))
            return player
        } else {
            return nil
        }
    }
    
    func nextVideo() -> URL? {
        // Already played last video
        if currentVideoIdx == allClips.count - 1 {
            return nil
        } else {
            currentVideoIdx += 1
            return allClips[currentVideoIdx].finalURL
        }
    }
    
    func firstVideo() -> URL? {
        currentVideoIdx = 0
        return allClips[currentVideoIdx].finalURL
    }
    
}
