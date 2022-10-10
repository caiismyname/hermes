//
//  File.swift
//  Hermes
//
//  Created by David Cai on 9/17/22.
//

import SwiftUI

struct RecordingControlsView: View {
    @ObservedObject var model: ContentViewModel
    @ObservedObject var recordingManager: RecordingManager
    @State var playbackModalShowing = false
    @State var projectSwitcherModalShowing = false
    
    private let sizes = Sizes()

    var body: some View {
        GeometryReader { geometry in
            // Recording indicator at top of screen, with duration counter
            if recordingManager.isRecording {
                RecordingTimeCounter(recordingManager: recordingManager)
                    .position(x: geometry.size.width / 2, y: sizes.topOffset)
            }
            
            
            if !(recordingManager.isRecording) {
                // Playback button
                Button(action: {playbackModalShowing = !playbackModalShowing}) {
                    Image(systemName: "film.stack")
                        .font(.system(size: sizes.secondaryButtonSize))
                }
                .position(x: geometry.size.width / 4, y: geometry.size.height - sizes.bottomOffset)
                .popover(isPresented: $playbackModalShowing, content: { PlaybackView(model: model) })
            
                // Projects button
                Button(action: {projectSwitcherModalShowing = !projectSwitcherModalShowing}) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: sizes.secondaryButtonSize))
                }
                .position(x: (geometry.size.width / 4) * 3, y: geometry.size.height - sizes.bottomOffset)
                .popover(isPresented: $projectSwitcherModalShowing, content: {
                    SwitchProjectsModal(
                        model: model,
                        dismissCallback: {self.projectSwitcherModalShowing = !self.projectSwitcherModalShowing}
                    )
                    
                })
                
                // Project Name
                
                Text("\(model.project.name)")
                    .font(.system(size: sizes.fontSize, weight: .regular , design: .monospaced))
                    .foregroundColor(Color.white)
                    .minimumScaleFactor(0.01)
                    .lineLimit(1)
                    .position(x: geometry.size.width / 2, y: sizes.topOffset)
            }
            
            
            // Record button
            RecordButton(recordingManager: recordingManager)
                .position(x: geometry.size.width / 2, y: geometry.size.height - sizes.bottomOffset)
            
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
    private let sizes = Sizes()
    
    var body: some View {
        if recordingManager.isRecording {
            Button(action: recordingManager.toggleRecording) {
                RoundedRectangle(cornerSize: CGSize.init(width: 10, height: 10))
                    .fill(Color.black)
            }
            .frame(width: sizes.primaryButtonSize, height: sizes.primaryButtonSize)

        } else {
            Button(action: recordingManager.toggleRecording) {
                ZStack {
                    Circle()
                        .strokeBorder(.white, lineWidth: sizes.primaryButtonSize / 15)
                        .frame(width: (sizes.primaryButtonSize * 1.07) + 10, height: (sizes.primaryButtonSize * 1.07) + 10)
                    Circle()
                        .fill(Color.red)
                        .frame(width: sizes.primaryButtonSize, height: sizes.primaryButtonSize)
                }
            }
        }
    }
}

struct RecordingTimeCounter: View {
    @ObservedObject var recordingManager: RecordingManager
    private let sizes = Sizes()
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.red)
                .frame(width: 125, height: 30)
                .cornerRadius(sizes.buttonCornerRadius)
            
            Text("\(recordingManager.recordingDuration.formattedTimeNoMilliLeadingZero)")
                .font(.system(size: sizes.fontSize, weight: .regular , design: .monospaced))
                .foregroundColor(Color.white)
        }
    }
}

