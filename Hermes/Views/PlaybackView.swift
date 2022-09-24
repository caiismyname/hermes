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

struct Thumbnails: View {
    @ObservedObject var project: Project
    
    var body: some View {
        ZStack {
            ScrollView {
                HStack {
                    ForEach(project.allClips) { c in
                        Image(uiImage: UIImage(cgImage: c.generateThumbnail()!))
                            .frame(width: 40, height: 40)
//                        Circle().background(Color.green)
                    }
                }
            }
        }
    }
}
