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
    
    func updateOrientation(newOrientation: UIDeviceOrientation) {
        switch newOrientation {
            // Prevent jankiness when the phone moves through the Z axis
        case .unknown,.faceUp, .faceDown, .portraitUpsideDown:
            return
        case .portrait, .landscapeLeft, .landscapeRight:
            self.orientation = newOrientation
        @unknown default:
            return
        }
    }
   
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(Color.black)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
                
                CameraPreviewWrapper(session: model.cameraManager.session, orientation: $orientation)
                    .ignoresSafeArea(.all)
                
                RecordingControlsView(
                    model: model,
                    recordingManager: model.recordingManager,
                    orientation: $orientation
                )
                .onRotate { newOrientation in // Note this .onRotate handles the orientation for all aspects of the recording UI
                    updateOrientation(newOrientation: newOrientation)
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
