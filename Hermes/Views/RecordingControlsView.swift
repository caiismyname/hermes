//
//  File.swift
//  Hermes
//
//  Created by David Cai on 9/17/22.
//

import SwiftUI

struct RecordingControlsView: View {
    @ObservedObject var recordingManager: RecordingManager
    @State var playbackModalShowing = false
    @ObservedObject var model: ContentViewModel

    var body: some View {
        GeometryReader { geometry in
            if recordingManager.isRecording {
                RecordingTimeCounter(recordingManager: recordingManager)
                    .position(x: geometry.size.width / 2, y: 60)
            }
            
            HStack {
                Button(action: {
                    playbackModalShowing = !playbackModalShowing
                }) {
                    Image(systemName: "photo.circle.fill")
                }
                .frame(width: 100, height: 100)
                RecordButton(recordingManager: recordingManager)
            }
            .position(x: geometry.size.width / 2, y: geometry.size.height - 100)
            .popover(isPresented: $playbackModalShowing, content:
                {
                    PlaybackView(model: model)
                }
            )
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
    
    let buttonSize = 65.0
    
    var body: some View {
        if recordingManager.isRecording {
            Button(action: recordingManager.toggleRecording) {
                RoundedRectangle(cornerSize: CGSize.init(width: 10, height: 10))
                    .fill(Color.black)
            }
            .frame(width: 75, height: 75)

        } else {
            Button(action: recordingManager.toggleRecording) {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: buttonSize / 15)
                        .frame(width: (buttonSize * 1.07) + 10, height: (buttonSize * 1.07) + 10)
                    Circle()
                        .fill(Color.red)
                        .frame(width: buttonSize, height: buttonSize)
                }
            }
        }
    }
}

struct RecordingTimeCounter: View {
    @ObservedObject var recordingManager: RecordingManager
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.red)
                .frame(width: 125, height: 40)
                .cornerRadius(15)
            
            Text("\(recordingManager.recordingDuration.formattedTimeNoMilliLeadingZero)")
                .font(.system(size: 20, weight: .regular , design: .monospaced))
                .foregroundColor(Color.white)
        }
    }
}
