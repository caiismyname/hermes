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
   
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CameraPreviewWrapper(session: model.cameraManager.session)
                    .ignoresSafeArea(.all)
                RecordingControlsView(
                    recordingManager: model.recordingManager,
                    model: model
                )
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(model: ContentViewModel())
    }
}
