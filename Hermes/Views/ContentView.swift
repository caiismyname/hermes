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
    private let sizes = Sizes()
    @State var shouldShowSwitcherModal = false
    
    func updateOrientation(newOrientation: UIDeviceOrientation) {
        switch newOrientation {
            // Prevent jankiness when the phone moves through the Z axis
        case .unknown,.faceUp, .faceDown, .portraitUpsideDown, .landscapeLeft, .landscapeRight:
            return
        case .portrait:
            self.orientation = newOrientation
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
                    
                    if model.ready {
                        CameraPreviewWrapper(session: model.cameraManager.session, orientation: $orientation)
                            .mask {
                                Rectangle()
                                    .cornerRadius(sizes.cameraPreviewCornerRadius)
                                    .frame(width: geometry.size.width, height: geometry.size.width * (16/9))
                            }
                            .onTapGesture(count: 2) {
                                model.cameraManager.flipCamera()
                            }
                            .gesture(DragGesture(minimumDistance: 1.0)
                                .onEnded({ drag in
                                    var didSwitch = false
                                    if drag.translation.width < -250 && abs(drag.translation.height) < 150  {
                                        didSwitch = model.switchToNextProject()
                                    } else if drag.translation.width > 250 && abs(drag.translation.height) < 150 {
                                        didSwitch = model.switchToPreviousProject()
                                    }
                                    
                                    if didSwitch {
                                        shouldShowSwitcherModal = true
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                            self.shouldShowSwitcherModal = false
                                        }
                                    }
                                }))
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
                    }
                    
                    RecordingControlsView(
                        model: model,
                        recordingManager: model.recordingManager,
                        orientation: $orientation
                    )
                    .onRotate { newOrientation in // Note this .onRotate handles the orientation for all aspects of the recording UI
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
                        RoundedRectangle(cornerRadius: sizes.cameraPreviewCornerRadius)
                            .foregroundColor(Color.gray)
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

//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView(model: ContentViewModel())
//    }
//}
