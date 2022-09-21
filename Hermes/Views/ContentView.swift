//
//  ContentView.swift
//  Hermes
//
//  Created by David Cai on 9/17/22.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @StateObject private var model = ContentViewModel()
    @State var playbackMode = false
   
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CameraPreview(image: model.frame)
                    .ignoresSafeArea(.all)
                    .popover(isPresented: $playbackMode) {
                        PlaybackView(videoURL: model.recordingManager.projectManager.allClips.last?.finalURL)
                            .frame(height:200)
                    }
                RecordingControlsView(
                    playbackCallback: {self.playbackMode = !self.playbackMode},
                    recordingManager: model.recordingManager
                )
                    .position(x: geometry.size.width / 2, y: geometry.size.height - 100)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
