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
    var playbackModel: PlaybackModel
    private let sizes = Sizes()
    @State var showingRenameAlert = false
    @ObservedObject var exporter: Exporter
    
    init(model: ContentViewModel) {
        self.model = model
        self.playbackModel = PlaybackModel(project: model.project)
        self.exporter = Exporter(project: model.project)
    }
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack{
                    // TODO This code works for editing, but not sure how to handle dirty db updates with it
//                    Image(systemName: "pencil.circle")
//                        .font(.system(.title2))
//                        .onTapGesture {
//                            showingRenameAlert = !showingRenameAlert
//                        }
//                        .alert("Rename Project", isPresented: $showingRenameAlert, actions: {
//                            TextField("New name value", text: $model.project.name)
//                                .foregroundColor(Color.black)
//                        })
                    Text("\(model.project.name)")
                        .font(.system(.title2).bold())
                }.padding()
                HStack {
                    Button(action: {
//                        spinnerLabel = "Syncing clips to cloud"
                        // Go through the model so it does the firebase auth
                        Task {
                            await model.networkSync()
                        }
                    }) {
                        Text("Sync")
                            .frame(maxWidth: .infinity, maxHeight: sizes.projectButtonHeight)
                    }
                    .foregroundColor(Color.white)
                    .background(Color.green)
                    .cornerRadius(sizes.buttonCornerRadius)
                    .disabled(model.isWorking)
                    
                    if #available(iOS 16.0, *) {
                        Button(action: {}) {
                            ShareLink("Share", item: model.project.generateURL())
                                .frame(maxWidth: .infinity, maxHeight: sizes.projectButtonHeight)
                        }
                        .foregroundColor(Color.white)
                        .background(Color.blue)
                        .cornerRadius(sizes.buttonCornerRadius)
                        .disabled(model.isWorking)
                    } else {
                        // Fallback on earlier versions
                    }
                    
                    Button(action: {
//                        spinnerLabel = "Exporting vlog to your photos library"
                        Task {
                            model.startWork()
                            let exporter = Exporter(project: model.project)
                            await exporter.export()
                            model.stopWork()
                        }
                    }) {
                        if exporter.isProcessing {
                            Text("Exporting...")
                                .frame(maxWidth: .infinity, maxHeight: sizes.projectButtonHeight)
                        } else {
                            Text("Export")
                                .frame(maxWidth: .infinity, maxHeight: sizes.projectButtonHeight)
                        }
                    }
                    .foregroundColor(Color.white)
                    .background(Color.purple)
                    .cornerRadius(sizes.buttonCornerRadius)
                    .disabled(model.isWorking)
                }
                .padding([.leading, .trailing])
                VideoPlayer(player: playbackModel.player)
                ThumbnailReel(project: model.project, playbackModel: playbackModel)
            }
            
            WaitingSpinner(spinnerLabel: "", model: model)
        }
    }
}

struct WaitingSpinner: View {
    @State var spinnerLabel = ""
    @ObservedObject var model: ContentViewModel
    private let sizes = Sizes()
    
    var body: some View {
        if model.isWorking {
            ZStack {
                RoundedRectangle(cornerRadius: sizes.buttonCornerRadius)
                    .fill(Color.white)
                VStack (alignment: .center) {
                    if spinnerLabel != "" {
                        Text("\(spinnerLabel)")
                            .foregroundColor(Color.black)
                            .padding()
                    }
                    Spacer()
                    ProgressView()
                        .controlSize(ControlSize.large)
                        .colorInvert()
                    Spacer()
                }
            }
            .frame(width: 175, height: 175)
        }
    }
}

struct ThumbnailReel: View {
    @ObservedObject var project: Project
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
