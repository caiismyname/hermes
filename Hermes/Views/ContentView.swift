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
    @State var playbackIdx = 0
   
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CameraPreviewWrapper(session: model.cameraManager.session)
                    .ignoresSafeArea(.all)
                    .popover(isPresented: $playbackMode) {
                        PlaybackView(playbackModel: PlaybackModel(allClips: model.project.allClips, currentVideoIdx: playbackIdx))
                            .frame(height:300)
                    }
                RecordingControlsView(
                    playbackCallback: { idx in
                        self.playbackMode = !self.playbackMode
                        self.playbackIdx = idx
                    },
                    recordingManager: model.recordingManager,
                    model: model
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
