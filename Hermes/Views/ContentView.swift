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
    private let sizes = Sizes()
    
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
                                model.cameraManager.changeCamera()
                            }
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
