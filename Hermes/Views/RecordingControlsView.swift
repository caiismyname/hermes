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
    @State var upgradeInterstitialShowing = false
    @Binding var orientation: UIDeviceOrientation
    
    func computeControlPositions(geometry: GeometryProxy, relativePosition: Double) -> [String: Double] {
        var results = [String: Double]()
        
        switch orientation {
        case .portrait, .unknown, .faceUp, .faceDown: // Last four should be filtered out before it reaches here. This is just for completeness of the switch.
            results["x"] = geometry.size.width * relativePosition
            results["y"] = geometry.size.height - Sizes.bottomOffset
        case .portraitUpsideDown: // Not currently supported
            results["x"] = geometry.size.width * relativePosition
            results["y"] = Sizes.bottomOffset
        case .landscapeLeft:
            results["x"] = geometry.size.width - Sizes.bottomOffset
            results["y"] = geometry.size.height * (1.0 - relativePosition) // (1.0 - ... is to maintain ordering of the icons relative to portrait
        case .landscapeRight:
            results["x"] = Sizes.bottomOffset
            results["y"] = geometry.size.height * relativePosition
        @unknown default:
            results["x"] = geometry.size.width * relativePosition
            results["y"] = geometry.size.height - Sizes.bottomOffset
        }
        
        return results
    }

    var body: some View {
        GeometryReader { geometry in
                // Recording indicator at top of screen, with duration counter
                if recordingManager.isRecording {
                    RecordingTimeCounter(recordingManager: recordingManager)
                        .frame(width: geometry.size.width * Sizes.infoPillWidthPercentage, height: Sizes.projectButtonHeight)
                        .position(x: geometry.size.width / 2, y: geometry.size.height * Sizes.infoPillTopOffset)
                }
                
                ZStack {
                    if !(recordingManager.isRecording) {
                        // Playback Button
                        PlaybackButton(
                            project: model.project,
                            lastClip: model.project.allClips.last ?? Clip(projectId: model.project.id),
                            tapCallback: {playbackModalShowing = !playbackModalShowing}
                        )
                            .position(
                                x: computeControlPositions(geometry: geometry, relativePosition: 1.0/4.0)["x"]!,
                                y: computeControlPositions(geometry: geometry, relativePosition: 1.0/4.0)["y"]!
                            )
                            .popover(isPresented: $playbackModalShowing, content: { PlaybackView(model: model, playbackModel: PlaybackModel(project: model.project)) })
                        
                        // Projects button
                        Button(action: {projectSwitcherModalShowing = !projectSwitcherModalShowing}) {
                            ZStack {
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: Sizes.secondaryButtonSize + 35, height: Sizes.secondaryButtonSize + 35)
                                Image(systemName: "square.stack.3d.up.fill")
                                    .font(.system(size: Sizes.secondaryButtonSize))
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
                        ProjectNameDisplay(project: model.project)
                            .frame(width: geometry.size.width * Sizes.infoPillWidthPercentage, height: Sizes.projectButtonHeight)
                            .position(x: geometry.size.width / 2, y: geometry.size.height * Sizes.infoPillTopOffset)
                    }
                    
                    
                    // Record button
                    if recordingManager.recordingButtonStyle == .camera {
                        RecordButtonCameraStyle(recordingManager: recordingManager, upgradeInterstitialShowing: $upgradeInterstitialShowing)
                            .position(
                                x: computeControlPositions(geometry: geometry, relativePosition: 2.0/4.0)["x"]!,
                                y: computeControlPositions(geometry: geometry, relativePosition: 2.0/4.0)["y"]!
                            )
                    } else {
                        RecordButtonSnapchatStyle(recordingManager: recordingManager, upgradeInterstitialShowing: $upgradeInterstitialShowing)
                            .position(
                                x: computeControlPositions(geometry: geometry, relativePosition: 2.0/4.0)["x"]!,
                                y: computeControlPositions(geometry: geometry, relativePosition: 2.0/4.0)["y"]!
                            )
                    }
                    
                    if upgradeInterstitialShowing {
                        UpgradeInterstitial(
                            dismissCallback: {self.upgradeInterstitialShowing = false},
                            upgradeCallback: {
                                Task {
                                    let success = await self.model.project.upgradeProject(upgradeLevel: ProjectLevel.upgrade1)
                                    if success {
                                        self.upgradeInterstitialShowing = false
                                    }
                                }
                            },
                            isOwner: self.model.project.isOwner(),
                            title: "You've hit the limit"
                        )
                    }
                }
            }
//        }
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
    @Binding var upgradeInterstitialShowing: Bool
    
    var body: some View {
        Button(action: {
            guard recordingManager.project.canAddClip() else {
                upgradeInterstitialShowing = true
                return
            }
            recordingManager.toggleRecording()
        }) {
            ZStack {
                Circle()
                    .strokeBorder(.white, lineWidth: Sizes.recordButtonSize / 15)
                    .frame(width: Sizes.recordButtonOuterSize, height: Sizes.recordButtonOuterSize)
                
                if recordingManager.isRecording {
                    RoundedRectangle(cornerSize: CGSize.init(width: 10, height: 10))
                        .fill(Color.red)
                        .frame(width: Sizes.stopButtonSize, height: Sizes.stopButtonSize)
                } else {
                    Circle()
                        .fill(Color.red)
                        .frame(width: Sizes.recordButtonSize, height: Sizes.recordButtonSize)
                }
            }
        }
    }
}

struct RecordButtonSnapchatStyle: View {
    @ObservedObject var recordingManager: RecordingManager
    @Binding var upgradeInterstitialShowing: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.white, lineWidth: Sizes.recordButtonSize / 10)
                .frame(width: Sizes.recordButtonOuterSize, height: Sizes.recordButtonOuterSize)
            
            if recordingManager.isRecording {
                Circle()
                    .trim(from: 0.0, to: Double(recordingManager.snapchatStyleProgress))
                    .stroke(style: StrokeStyle(lineWidth: Sizes.recordButtonSize / 6, lineCap:.round))
                    .foregroundColor(.red)
                    .frame(width: (Sizes.recordButtonSize * 1.7), height: Sizes.recordButtonSize * 1.7)
                    .rotationEffect(Angle(degrees: 270.0))
                
                Circle()
                    .fill(.white)
                    .frame(width: Sizes.recordButtonOuterSize, height: Sizes.recordButtonOuterSize)
            }
        }
        .contentShape(Circle())
        .onLongPressGesture(minimumDuration: (recordingManager.snapchatFullTime * recordingManager.snapchatMaxConsecutiveClips), maximumDistance: 200) {
            // An event is triggered when it starts, and when it hits the minimum duration again, so this duration effective caps how long the button will hold for
        } onPressingChanged: { startedPressing in
            guard recordingManager.project.canAddClip() else {
                upgradeInterstitialShowing = true
                return
            }
            
            // Only trigger the toggle if we're not recording and we're starting, or we are recording and we're stopping
            // Without this, it'll send one last toggle event if the user hits the time limit and then lifts off the button
            if (startedPressing && !recordingManager.isRecording) || (!startedPressing && recordingManager.isRecording) {
                recordingManager.toggleRecording()
            }
        }
    }
}

struct ProjectNameDisplay: View {
    @ObservedObject var project: Project
    
    var body: some View {
        ZStack {
            Text("\(project.name)")
                .font(.system(.title2).bold())
                .foregroundColor(Color.white)
                .minimumScaleFactor(0.01)
                .lineLimit(1)
        }
    }
}

struct RecordingTimeCounter: View {
    @ObservedObject var recordingManager: RecordingManager
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.red)
                .cornerRadius(Sizes.buttonCornerRadius)
            
            Text(
                recordingManager.recordingButtonStyle == .snapchat
                    ? recordingManager.recordingDuration.formattedTimeNoMilliNoLeadingZeroRoundUpOneSecond
                    : recordingManager.recordingDuration.formattedTimeNoMilliLeadingZero
            )
                .font(.system(size: Sizes.fontSize, weight: .regular , design: .monospaced))
                .foregroundColor(Color.white)
        }
    }
}

struct PlaybackButton: View {
    @ObservedObject var project: Project
    @ObservedObject var lastClip: Clip // Pass in the clip separately so we can observe on it when the thumbnail becomes non-nil
    let tapCallback: () -> Void
    
    var body: some View {
        Button(action: {tapCallback()}) {
            ZStack {
                Circle()
                    .fill(.black)
                    .frame(width: Sizes.secondaryButtonSize + 35, height: Sizes.secondaryButtonSize + 35)
                
                // Fallback image if no thumbnail to display
                Circle()
                    .fill(.black)
                    .frame(width: Sizes.secondaryButtonSize + 35, height: Sizes.secondaryButtonSize + 35)
                Image(systemName: "film.stack")
                    .font(.system(size: Sizes.secondaryButtonSize))
                    .foregroundColor(Color.white)
                
                if let clip = project.allClips.last {
                    if clip.thumbnail != nil {
                        Image(uiImage: UIImage(cgImage: UIImage(data: clip.thumbnail!)!.cgImage!.cropToCenter()))
                            .resizable()
                            .frame(width: Sizes.secondaryButtonSize + 35, height: Sizes.secondaryButtonSize + 35)
                            .mask {
                                Circle()
                                    .frame(width: Sizes.secondaryButtonSize + 35, height: Sizes.secondaryButtonSize + 35)
                            }
                        Circle()
                            .strokeBorder(.black, lineWidth: Sizes.secondaryButtonSize / 15)
                            .frame(width: Sizes.secondaryButtonSize + 35, height: Sizes.secondaryButtonSize + 35)
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
                    .offset(CGSize(width: (Sizes.secondaryButtonSize * (4/5)), height: -1 * (Sizes.secondaryButtonSize * (4/5)) ))
                }
            }
        }
    }
}
