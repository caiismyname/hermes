//
//  File.swift
//  Hermes
//
//  Created by David Cai on 9/17/22.
//

import SwiftUI

struct RecordingControlsView: View {
    var recordingCallback: () -> ()
    var playbackCallback: () -> ()

    var body: some View {
        HStack {
            Button(action: recordingCallback) {
                Text("Record")
            }
            .frame(width: 100, height: 100)
            .cornerRadius(50)
            .background(Color.red)
            
            Button(action: playbackCallback) {
                Text("Play latest recording")
            }
            .frame(width: 50, height: 50)
            .background(Color.green)
        }
    }
}


struct RecordingControlsView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingControlsView(recordingCallback: {}, playbackCallback: {})
    }
}
