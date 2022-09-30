//
//  ContentView.swift
//  Hermes
//
//  Created by David Cai on 9/17/22.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @StateObject var model: ContentViewModel
    @State var playbackMode = false
   
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CameraPreviewWrapper(session: model.cameraManager.session)
                    .ignoresSafeArea(.all)
                    .popover(isPresented: $playbackMode) {
                        PlaybackView(videoURL: model.recordingManager.project.allClips.last?.finalURL)
                            .frame(height:200)
                    }
                RecordingControlsView(
                    playbackCallback: {self.playbackMode = !self.playbackMode},
                    recordingManager: model.recordingManager,
                    project: model.project
                )
                    .position(x: geometry.size.width / 2, y: geometry.size.height - 100)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(model: ContentViewModel())
    }
}
