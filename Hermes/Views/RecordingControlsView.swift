//
//  File.swift
//  Hermes
//
//  Created by David Cai on 9/17/22.
//

import SwiftUI

struct RecordingControlsView: View {
    var playbackCallback: () -> ()
    @ObservedObject var recordingManager: RecordingManager
    @ObservedObject var model: ContentViewModel
    @State var projectSwitcherModalShowing = false

    var body: some View {
        VStack {
            HStack {
                Button("Sync") {
                    model.project.saveToRTDB()
                    model.project.pullNewClipMetadata()
                    model.project.pullNewClipVideos()
                }
                Button("Switch") {
                    projectSwitcherModalShowing = true
                }
            }
            RecordButton(recordingManager: recordingManager)
            ThumbnailReel(project: model.project)
        }.frame(height: 200)
            .popover(isPresented: $projectSwitcherModalShowing) {
                SwitchProjectsModal(model: model)
                    .frame(height:200)
            }
    }
}


//struct RecordingControlsView_Previews: PreviewProvider {
//    static var previews: some View {
//
//        RecordingControlsView(recordingCallback: {}, playbackCallback: {}, isRecording: true)
//        RecordingControlsView(recordingCallback: {}, playbackCallback: {}, isRecording: false)
//    }
//}


struct RecordButton: View {
    @ObservedObject var recordingManager: RecordingManager
    
    var body: some View {
        if recordingManager.isRecording {
            Button(action: recordingManager.toggleRecording) {
                RoundedRectangle(cornerSize: CGSize.init(width: 10, height: 10))
                    .fill(Color.black)
            }
            .frame(width: 75, height: 75)

        } else {
            Button(action: recordingManager.toggleRecording) {
                Circle()
                    .fill(Color.red)
            }
            .frame(width: 100, height: 100)
        }
    }
}


struct ThumbnailReel: View {
    @ObservedObject var project: Project
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
//            ScrollViewReader { scrollReader in // This will eventually allow for programmatic scrolling
                HStack {
                    ForEach(project.allClips) { c in
                        Thumbnail(clip: c)
                    }
                }
//            }
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
                Button(action: {
                    model.findRemoteProject(id: "83BB2051-A8B6-459C-A5D1-C2B1F035E02E")
                }) {
                    Text("Find existing")
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
