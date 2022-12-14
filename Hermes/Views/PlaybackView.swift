//
//  PlaybackView.swift
//  Hermes
//
//  Created by David Cai on 9/20/22.
//

import Foundation
import SwiftUI
import AVKit
import Photos

struct PlaybackView: View {
    @ObservedObject var model: ContentViewModel
    @ObservedObject var playbackModel: PlaybackModel
    
    @State var showingRenameAlert = false
    @State var showingShareAlert = false
    @State var showingProjectSettings = false
    
    init(model: ContentViewModel, playbackModel: PlaybackModel) {
        self.model = model
        self.playbackModel = playbackModel
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                if (model.project.allClips.count != 0) {
                    VideoPlayback(playbackModel: playbackModel, project: model.project, showingProjectSettingsCallback: {self.showingProjectSettings = true})
                    ThumbnailReel(project: model.project, playbackModel: playbackModel)
                } else {
                    Spacer()
                    Text("No clips yet.")
                    Spacer()
                }
            }
            
            if model.isWorking > 0 || model.project.isWorking > 0 {
                WaitingSpinner(project: model.project)
            }
        }
        .popover(isPresented: $showingProjectSettings) {
            ProjectSettings(project: model.project)
        }
    }
}

struct VideoPlayback: View {
    @ObservedObject var playbackModel: PlaybackModel
    @ObservedObject var project: Project
    @State var showPlayer = false
    var showingProjectSettingsCallback: () -> ()
    
    var body: some View {
        ZStack {
            VideoPlayer(player: playbackModel.player)
            GeometryReader { geo in
                if !showPlayer {
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: geo.size.width, height: geo.size.height)
                    
                    if project.allClips[playbackModel.currentVideoIdx].thumbnail != nil {
                        // No video, but has a thumbnail
                        Image(uiImage: UIImage(data: project.allClips[playbackModel.currentVideoIdx].thumbnail!)!)
                            .resizable()
                            .frame(width: geo.size.height * (1080.0 / 1920.0), height: geo.size.height)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                }
                
                // Show regardless
                ClipMetadataView(playbackModel: playbackModel)
                    .position(x: (geo.size.width / 4) , y: geo.size.height / 15)
                    .frame(width: geo.size.width / 3, height: Sizes.projectButtonHeight * 1.3)
                
                Button(action: showingProjectSettingsCallback) {
                    Image(systemName: "gearshape")
                        .frame(maxWidth: .infinity, maxHeight: Sizes.projectButtonHeight)
                }
                    .background(Color.blue)
                    .foregroundColor(Color.white)
                    .font(.system(.title2).bold())
                    .frame(width: Sizes.projectButtonHeight * 2, height: Sizes.projectButtonHeight)
                    .cornerRadius(90)
                    .position(x: (5/6) * geo.size.width , y: (16 / 18) * geo.size.height)
            }
        }
        .onReceive(playbackModel.$currentVideoCanPlay) { canPlay in showPlayer = canPlay }
    }
}

struct ClipMetadataView: View {
    @ObservedObject var playbackModel: PlaybackModel
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Sizes.buttonCornerRadius)
                .fill(Color.black)
                .opacity(0.2)
            VStack(alignment: .leading) {
                Text("\(playbackModel.currentVideoTimestamp.displayDate) \(playbackModel.currentVideoTimestamp.displayTime)")
                Text("\(playbackModel.currentVideoCreatorName)")
            }
        }
        .foregroundColor(Color.white)
        
    }
}

struct ThumbnailReel: View {
    @ObservedObject var project: Project
    @ObservedObject var playbackModel: PlaybackModel
    @State private var showDeleteAlert = false
    @State private var clipToDelete = UUID()
    
    var body: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    ForEach(project.allClips.indices, id: \.self) { idx in
                        let clip = project.allClips[idx]
                        Thumbnail(
                            clip: clip,
                            playbackModel: playbackModel,
                            isCurrentClip: idx == playbackModel.currentVideoIdx
                        )
                            .id(clip.id)
                            .onTapGesture(count: 2, perform: {
                                print("Tapped on \(clip.id.uuidString)")
                                showDeleteAlert = true
                                clipToDelete = clip.id
                            })
                            .onTapGesture(count: 1, perform: {
                                print("Playing \(clip.id)")
                                playbackModel.playNVideo(n: idx)
                            })
                            .alert(isPresented: $showDeleteAlert) {
                                Alert(
                                    title: Text("Delete clip?"),
                                    primaryButton: .destructive(Text("Delete")) {
                                        Task { await playbackModel.deleteClip(id: clipToDelete) }
                                    },
                                    secondaryButton: .cancel(Text("Cancel")) {
                                        showDeleteAlert = false
                                    }
                                )
                            }
                    }
                    .onAppear {
                        reader.scrollTo(project.allClips.last?.id)
                    }
                    /*
                     The auto scroll behavior makes it look like the videos aren't progressing during playback.for now
                     */
//                    .onReceive(playbackModel.$currentVideoIdx) { idx in
//                        guard project.allClips.count > 0 else { return }
//                        if project.allClips.count - idx > 2 {
//                            // Roughly center the currently playing clip
//                            reader.scrollTo(project.allClips[idx + 2].id)
//                        } else {
//                            guard idx < project.allClips.count else {return}
//                            reader.scrollTo(project.allClips[idx].id)
//                        }
//                    }
                }
                    .frame(height: Sizes.thumbnailSize)
            }
        }
    }
}

struct Thumbnail: View {
    @ObservedObject var clip: Clip
    @ObservedObject var playbackModel: PlaybackModel
    var isCurrentClip: Bool
    
    var body: some View {
        ZStack {
            if clip.thumbnail != nil {
                Image(uiImage: UIImage(cgImage: UIImage(data: clip.thumbnail!)!.cgImage!.cropToCenter()))
                    .resizable(resizingMode: .stretch)
            }
            
            if !clip.seen {
                Rectangle().stroke(.blue, lineWidth: 2.0)
            }
            
            if isCurrentClip {
                Rectangle()
                    .stroke(.white, lineWidth: 3.0)
            }
            
            if clip.videoLocation == .deviceAndRemote {
                Image(systemName: "checkmark.circle.fill")
                    .position(x: Sizes.thumbnailSize - Sizes.playbackStatusIconInset, y: Sizes.playbackStatusIconInset)
            } else if clip.videoLocation == .remoteOnly {
                Image(systemName: "icloud.and.arrow.down")
                    .position(x: Sizes.thumbnailSize - Sizes.playbackStatusIconInset, y: Sizes.playbackStatusIconInset)
            } else if clip.videoLocation == .deviceOnly {
                Image(systemName: "icloud.and.arrow.up")
                    .position(x: Sizes.thumbnailSize - Sizes.playbackStatusIconInset, y: Sizes.playbackStatusIconInset)
            }
        }
        .frame(width: Sizes.thumbnailSize, height: Sizes.thumbnailSize)
    }
}

//struct ThumbnailProgressOverlay: View {
//    @ObservedObject var playbackModel: PlaybackModel
//
//    var body: some View {
//        if playbackModel.currentVideoTotalTime != CMTime.zero {
//            Rectangle()
//                .background(Color.black)
//                .opacity(0.5)
//                .frame(
//                    width: Sizes.thumbnailSize * (playbackModel.currentVideoElapsedTime.seconds / playbackModel.currentVideoTotalTime.seconds),
//                    height: Sizes.thumbnailSize
//                )
//        }
//    }
//}


//struct PlaybackView_Previews: PreviewProvider {
//
//    static var previews: some View {
//
//        PlaybackView(model: {
//            let model = ContentViewModel()
//
//            for _ in 1...10 {
//                model.project.allClips.append(Clip(projectId: model.project.id))
//            }
//
//            return model
//        }(),
//                     playbackModel: )
//            .previewDevice("iPhone 13 Pro")
//            .preferredColorScheme(.dark)
//    }
//}
