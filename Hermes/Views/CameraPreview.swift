//
//  RecordingView.swift
//  Hermes
//
//  Created by David Cai on 9/17/22.
//

import SwiftUI

struct CameraPreview: View {
    var image: CGImage?
    private let label = Text("Recording label")
    
    var body: some View {
        if let image = image {

            GeometryReader { geometry in
                Image(image, scale: 1.0, orientation: .up, label: label)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
                    .clipped()
            }
        } else {
            EmptyView()
        }
    }
}

struct RecordingView_Previews: PreviewProvider {
    static var previews: some View {
        CameraPreview(image: nil)
    }
}
