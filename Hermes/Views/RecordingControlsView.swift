//
//  File.swift
//  Hermes
//
//  Created by David Cai on 9/17/22.
//

import SwiftUI
import Foundation

struct RecordingControlsView: View {
    @ObservedObject var recordingManager: RecordingManager
    @State var playbackModalShowing = false
    @ObservedObject var model: ContentViewModel

    var body: some View {
        HStack {
            Button(action: {
                playbackModalShowing = !playbackModalShowing
            }) {
                Image(systemName: "photo.circle.fill")
            }
            .frame(width: 100, height: 100)
            RecordButton(recordingManager: recordingManager)
        }
        .popover(isPresented: $playbackModalShowing, content:
            {
                PlaybackView(model: model)
            }
        )
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
