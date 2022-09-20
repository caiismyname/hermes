//
//  PlaybackView.swift
//  Hermes
//
//  Created by David Cai on 9/20/22.
//

import Foundation
import SwiftUI
import AVKit

struct PlaybackView: View {
    var videoURL: URL?
    
    var body: some View {
        VideoPlayer(player: AVPlayer(url: videoURL!))
    }
}

struct PlaybackView_Preview: PreviewProvider {
    static var previews: some View {
        PlaybackView()
    }
}
