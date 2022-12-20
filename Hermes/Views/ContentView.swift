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
    @State var orientation = UIDeviceOrientation.portrait // default assume portrait
    @GestureState var magnificationLevel = 1.0
    @State var shouldShowSwitcherModal = false
    
    func updateOrientation(newOrientation: UIDeviceOrientation) {
        switch newOrientation {
            // Prevent jankiness when the phone moves through the Z axis
        case .faceUp, .faceDown, .portraitUpsideDown:
            return
        case .portrait, .landscapeLeft, .landscapeRight:
            self.orientation = newOrientation
        case .unknown:
            self.orientation = UIDeviceOrientation(rawValue: 1)! // Default unknown to portrait
        @unknown default:
            return
        }
    }
   
    var body: some View {
        GeometryReader { geometry in
            if model.isOnboarding {
                OnboardingView(model: model)
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color.black)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .edgesIgnoringSafeArea(.all)
                    
                    CameraPreviewWrapper(session: model.cameraManager.session, orientation: $orientation)
                        .mask {
                            Rectangle()
                                .cornerRadius(Sizes.cameraPreviewCornerRadius)
                                .frame(width: geometry.size.width, height: geometry.size.width * (16/9))
                        }
                        .onTapGesture(count: 2) {
                            model.cameraManager.flipCamera()
                        }
                        .gesture(DragGesture(minimumDistance: 1.0)
                            .onEnded({ drag in
                                if drag.translation.width < -250 && abs(drag.translation.height) < 150  {
                                    _ = model.switchToNextProject()
                                } else if drag.translation.width > 250 && abs(drag.translation.height) < 150 {
                                    _ = model.switchToPreviousProject()
                                }
                            }))
                        .onReceive(model.$project) { _ in
                            // This listens for when the project changes and displays a message
                            shouldShowSwitcherModal = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                self.shouldShowSwitcherModal = false
                            }
                        }
                    //                        do u think there's desert' i was hoping but my hopes are decreasing :( a brownnie would have been nice)
                    //                            .gesture(MagnificationGesture(minimumScaleDelta: 0.6).updating($magnificationLevel) { currentState, gestureState, transaction in
                    //                                    print(currentState, gestureState)
                    //                                    if currentState < 1.0 {
                    //                                        model.cameraManager.zoomCamera(cameraType: .ultrawide)
                    //                                    } else if currentState > 3.0 {
                    //                                        model.cameraManager.zoomCamera(cameraType: .tele)
                    //                                    } else  {
                    //                                        model.cameraManager.zoomCamera(cameraType: .main)
                    //                                    }
                    //                            })
                    
                    RecordingControlsView(
                        model: model,
                        recordingManager: model.recordingManager,
                        orientation: $orientation
                    )
                    .onRotate { newOrientation in // Note this .onRotate handles the orientation for all aspects of the recording UI, but only UI. The actual recording has a separate manager
                        updateOrientation(newOrientation: newOrientation)
                    }
                    .popover(isPresented: $model.shouldShowProjects, content: {
                        SettingsModal(
                            model: model,
                            recordingManager: model.recordingManager,
                            dismissCallback: {model.shouldShowProjects = !model.shouldShowProjects}
                        )
                    })
                    
                    if shouldShowSwitcherModal {
                        RoundedRectangle(cornerRadius: Sizes.cameraPreviewCornerRadius)
                            .foregroundColor(Color.gray)
                            .opacity(0.9)
                            .frame(width: 250, height: 250)
                            .overlay(
                                VStack {
                                    Text("\(model.project.name)")
                                        .font(.system(.title2).bold())
                                        .foregroundColor(Color.black)
                                        .minimumScaleFactor(0.01)
                                        .lineLimit(2)
                                }
                            )
                    }
                }
            }
        }.preferredColorScheme(.dark)
    }
}

struct ContentView_Previews: PreviewProvider {
    let model = ContentViewModel()
    
    init() {
        
    }
    
    static var previews: some View {
        ContentView(model: {
            let model = ContentViewModel()
            return model
        }())
    }
}
