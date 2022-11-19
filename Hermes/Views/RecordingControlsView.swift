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
    @Binding var orientation: UIDeviceOrientation
    
    private let sizes = Sizes()
    
    func computeControlPositions(geometry: GeometryProxy, relativePosition: Double) -> [String: Double] {
        var results = [String: Double]()
        
        switch orientation {
        case .portrait, .unknown, .faceUp, .faceDown: // Last three should be filtered out before it reaches here. This is just for completeness of the switch.
            results["x"] = geometry.size.width * relativePosition
            results["y"] = geometry.size.height - sizes.bottomOffset
        case .portraitUpsideDown: // Not currently supported
            results["x"] = geometry.size.width * relativePosition
            results["y"] = sizes.bottomOffset
        case .landscapeLeft:
            results["x"] = geometry.size.width - sizes.bottomOffset
            results["y"] = geometry.size.height * (1.0 - relativePosition) // (1.0 - ... is to maintain ordering of the icons relative to portrait
        case .landscapeRight:
            results["x"] = sizes.bottomOffset
            results["y"] = geometry.size.height * relativePosition
        @unknown default:
            results["x"] = geometry.size.width * relativePosition
            results["y"] = geometry.size.height - sizes.bottomOffset
        }
        
        return results
    }

    var body: some View {
        GeometryReader { geometry in
            if !model.ready {
                Circle()
                    .strokeBorder(.gray, lineWidth: sizes.recordButtonSize / 10)
                    .frame(width: sizes.recordButtonOuterSize, height: sizes.recordButtonOuterSize)
                    .position(
                        x: computeControlPositions(geometry: geometry, relativePosition: 2.0/4.0)["x"]!,
                        y: computeControlPositions(geometry: geometry, relativePosition: 2.0/4.0)["y"]!
                    )
            } else {
                // Recording indicator at top of screen, with duration counter
                if recordingManager.isRecording {
                    RecordingTimeCounter(recordingManager: recordingManager)
                        .position(x: geometry.size.width / 2, y: sizes.topOffset)
                }
                
                if !(recordingManager.isRecording) {
                    PlaybackButton(
                        project: model.project,
                        lastClip: model.project.allClips.last ?? Clip(projectId: model.project.id),
                        tapCallback: {playbackModalShowing = !playbackModalShowing}
                    )
                        .position(
                            x: computeControlPositions(geometry: geometry, relativePosition: 1.0/4.0)["x"]!,
                            y: computeControlPositions(geometry: geometry, relativePosition: 1.0/4.0)["y"]!
                        )
                        .popover(isPresented: $playbackModalShowing, content: { PlaybackView(model: model) })
                    
                    // Projects button
                    Button(action: {projectSwitcherModalShowing = !projectSwitcherModalShowing}) {
                        ZStack {
                            Circle()
                                .fill(Color.black)
                                .frame(width: sizes.secondaryButtonSize + 35, height: sizes.secondaryButtonSize + 35)
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.system(size: sizes.secondaryButtonSize))
                                .foregroundColor(Color.white)
                        }
                    }
                    .position(
                        x: computeControlPositions(geometry: geometry, relativePosition: 3.0/4.0)["x"]!,
                        y: computeControlPositions(geometry: geometry, relativePosition: 3.0/4.0)["y"]!
                    )
                    .popover(isPresented: $projectSwitcherModalShowing, content: {
                        SettingsModal(
                            model: model,
                            recordingManager: recordingManager,
                            dismissCallback: {self.projectSwitcherModalShowing = !self.projectSwitcherModalShowing}
                        )
                    })
                    
                    // Project Name
                    
                    Text("\(model.project.name)")
                        .font(.system(.title2).bold())
                        .foregroundColor(Color.white)
                        .minimumScaleFactor(0.01)
                        .lineLimit(1)
                        .position(x: geometry.size.width / 2, y: sizes.topOffset - 10)
                }
                
                
                // Record button
                if recordingManager.recordingButtonStyle == .camera {
                    RecordButtonCameraStyle(recordingManager: recordingManager)
                        .position(
                            x: computeControlPositions(geometry: geometry, relativePosition: 2.0/4.0)["x"]!,
                            y: computeControlPositions(geometry: geometry, relativePosition: 2.0/4.0)["y"]!
                        )
                } else {
                    RecordButtonSnapchatStyle(recordingManager: recordingManager)
                        .position(
                            x: computeControlPositions(geometry: geometry, relativePosition: 2.0/4.0)["x"]!,
                            y: computeControlPositions(geometry: geometry, relativePosition: 2.0/4.0)["y"]!
                        )
                }
            }
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


struct RecordButtonCameraStyle: View {
    @ObservedObject var recordingManager: RecordingManager
    private let sizes = Sizes()
    
    var body: some View {
        Button(action: recordingManager.toggleRecording) {
            ZStack {
                Circle()
                    .strokeBorder(.white, lineWidth: sizes.recordButtonSize / 15)
                    .frame(width: sizes.recordButtonOuterSize, height: sizes.recordButtonOuterSize)
                
                if recordingManager.isRecording {
                    RoundedRectangle(cornerSize: CGSize.init(width: 10, height: 10))
                        .fill(Color.red)
                        .frame(width: sizes.stopButtonSize, height: sizes.stopButtonSize)
                } else {
                    Circle()
                        .fill(Color.red)
                        .frame(width: sizes.recordButtonSize, height: sizes.recordButtonSize)
                }
            }
        }
    }
}

struct RecordButtonSnapchatStyle: View {
    @ObservedObject var recordingManager: RecordingManager
    private let sizes = Sizes()
    
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.white, lineWidth: sizes.recordButtonSize / 10)
                .frame(width: sizes.recordButtonOuterSize, height: sizes.recordButtonOuterSize)
            
            if recordingManager.isRecording {
                Circle()
                    .trim(from: 0.0, to: Double(recordingManager.snapchatStyleProgress))
                    .stroke(style: StrokeStyle(lineWidth: sizes.recordButtonSize / 6, lineCap:.round))
                    .foregroundColor(.red)
                    .frame(width: (sizes.recordButtonSize * 1.7), height: sizes.recordButtonSize * 1.7)
                    .rotationEffect(Angle(degrees: 270.0))
                
                Circle()
                    .fill(.white)
                    .frame(width: sizes.recordButtonOuterSize, height: sizes.recordButtonOuterSize)
            }
        }
        .contentShape(Circle())
        .onLongPressGesture(minimumDuration: recordingManager.snapchatFullTime, maximumDistance: 200) {
        } onPressingChanged: { _ in
            recordingManager.toggleRecording()
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

struct PlaybackButton: View {
    @ObservedObject var project: Project
    @ObservedObject var lastClip: Clip // Pass in the clip separately so we can observe on it when the thumbnail becomes non-nil
    private let sizes = Sizes()
    let tapCallback: () -> Void
    
    var body: some View {
        Button(action: {tapCallback()}) {
            ZStack {
                Circle()
                    .fill(.black)
                    .frame(width: sizes.secondaryButtonSize + 35, height: sizes.secondaryButtonSize + 35)
                
                // Fallback image if no thumbnail to display
                Circle()
                    .fill(.black)
                    .frame(width: sizes.secondaryButtonSize + 35, height: sizes.secondaryButtonSize + 35)
                Image(systemName: "film.stack")
                    .font(.system(size: sizes.secondaryButtonSize))
                    .foregroundColor(Color.white)
                
                if let clip = project.allClips.last {
                    if clip.thumbnail != nil {
                        Image(uiImage: UIImage(data:(clip.thumbnail)!)!)
                            .resizable()
                            .frame(width: sizes.secondaryButtonSize + 35, height: sizes.secondaryButtonSize + 35)
                            .mask {
                                Circle()
                                    .frame(width: sizes.secondaryButtonSize + 35, height: sizes.secondaryButtonSize + 35)
                            }
                        Circle()
                            .strokeBorder(.black, lineWidth: sizes.secondaryButtonSize / 15)
                            .frame(width: sizes.secondaryButtonSize + 35, height: sizes.secondaryButtonSize + 35)
                    }
                }
                
                if project.unseenCount > 0 {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 30, height: 30)
                        Text("\(project.unseenCount)")
                            .foregroundColor(Color.white)
                    }
                    .offset(CGSize(width: (sizes.secondaryButtonSize * (4/5)), height: -1 * (sizes.secondaryButtonSize * (4/5)) ))
                }
            }
        }
    }
}
