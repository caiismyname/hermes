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
    @ObservedObject var model: ContentViewModel
    var playbackModel: PlaybackModel
    private let sizes = Sizes()
    
    init(model: ContentViewModel) {
        self.model = model
        self.playbackModel = PlaybackModel(project: model.project)
    }
    
    var body: some View {
        VStack {
            Spacer()
            Text("\(model.project.name)")
                .font(.system(.headline))
                .padding([.leading, .trailing])
            Spacer()
            HStack {
                Button(action: {
                    model.project.saveMetadataToRTDB()
                    model.project.pullNewClipMetadata()
                    model.project.pullNewClipVideos()
                }) {
                    Text("Sync")
                        .frame(maxWidth: .infinity, maxHeight: sizes.projectButtonHeight)
                }
                .foregroundColor(Color.white)
                .background(Color.green)
                .cornerRadius(sizes.buttonCornerRadius)
                
                if #available(iOS 16.0, *) {
                    Button(action: {}) {
                        ShareLink("Share", item: model.project.generateURL())
                            .frame(maxWidth: .infinity, maxHeight: sizes.projectButtonHeight)
                    }
                    .foregroundColor(Color.white)
                    .background(Color.orange)
                    .cornerRadius(sizes.buttonCornerRadius)
                } else {
                    // Fallback on earlier versions
                }
            }
            .padding([.leading, .trailing])
            ThumbnailReel(project: model.project, playbackModel: playbackModel)
            VideoPlayer(player: playbackModel.player)
        }
    }
}

struct ThumbnailReel: View {
    @ObservedObject var project: Project
//    var playbackCallback: (Int) -> ()
    @ObservedObject var playbackModel: PlaybackModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ScrollViewReader { reader in
                HStack {
                    ForEach(project.allClips.indices, id: \.self) { idx in
                        Thumbnail(clip: project.allClips[idx])
                            .onTapGesture {
                                playbackModel.currentVideoIdx = idx
                                playbackModel.playCurrentVideo()
                            }
                    }
                }
            }
        }
    }
}

struct Thumbnail: View {
    @ObservedObject var clip: Clip
    
    var body: some View {
        ZStack {
            Rectangle()
                .background(Color.red)
            if clip.thumbnail != nil {
                Image(uiImage: UIImage(data: clip.thumbnail!)!)
                    .resizable(resizingMode: .stretch)
                    .frame(width: 100, height: 100)
            }
        }
        .frame(width: 100, height: 100)
    }
}


//struct PlaybackView_Preview: PreviewProvider {
//    static var previews: some View {
//        PlaybackView()
//    }
//}
