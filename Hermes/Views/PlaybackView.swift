//
//  PlaybackView.swift
//  Hermes
//
//  Created by David Cai on 9/20/22.
//

import Foundation
import SwiftUI
import AVKit

struct PlaybackView: View {
    @StateObject var playbackModel: PlaybackModel
    
    var body: some View {
        VideoPlayer(player: playbackModel.currentVideo()!)
            .frame(width: 400, height: 300, alignment: .center)
    }
}

//struct PlaybackView_Preview: PreviewProvider {
//    static var previews: some View {
//        PlaybackView()
//    }
//}
