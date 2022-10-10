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
                .onRotate { newOrientation in orientation = newOrientation }
            }
        }.preferredColorScheme(.dark)
    }
}

//struct ContentView_Previews: PreviewProvider {
//    static var previews: some View {
//        ContentView(model: ContentViewModel())
//    }
//}
