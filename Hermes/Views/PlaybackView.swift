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
    @State var projectSwitcherModalShowing = false
    
    init(model: ContentViewModel) {
        self.model = model
        self.playbackModel = PlaybackModel(project: model.project)
    }
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Button("Sync") {
                    model.project.saveMetadataToRTDB()
                    model.project.pullNewClipMetadata()
                    model.project.pullNewClipVideos()
                }
                Button("Switch") {
                    projectSwitcherModalShowing = true
                }
            }
            ThumbnailReel(project: model.project, playbackModel: playbackModel)
            VideoPlayer(player: playbackModel.player)
        }
        .popover(isPresented: $projectSwitcherModalShowing) {
            SwitchProjectsModal(model: model)
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


struct SwitchProjectsModal: View {
    @ObservedObject var model: ContentViewModel
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    model.createProject()
                }) {
                    Text("Create new")
                }
                
                if #available(iOS 16.0, *) {
                    ShareLink("Share", item: model.project.generateURL())
                } else {
                    // Fallback on earlier versions
                }
            }
       
            List(model.allProjects.indices, id: \.self) { index in
                Group {
                    Text(model.allProjects[index].name)
                }
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, alignment: .leading)
                .onTapGesture {
                    model.switchProjects(newProject: model.allProjects[index])
                }
            }
        }
    }
}


//struct PlaybackView_Preview: PreviewProvider {
//    static var previews: some View {
//        PlaybackView()
//    }
//}
