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

    var body: some View {
        HStack {
            RecordButton(recordingManager: recordingManager)
            
            Button(action: playbackCallback) {
                Text("Play latest recording")
            }
            .frame(width: 50, height: 50)
            .background(Color.green)
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
