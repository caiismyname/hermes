//
//  CameraPreview.swift
//  Hermes
//
//  Created by David Cai on 9/17/22.
//

import SwiftUI
import UIKit
import AVFoundation

// This is a UIKit class, use the CameraPreviewWrapper for SwiftUI
class CameraPreview: UIView {
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer. Check PreviewView.layerClass implementation.")
        }
        return layer
    }
    
    var session: AVCaptureSession? {
        get {
            return videoPreviewLayer.session
        }
        set {
            videoPreviewLayer.session = newValue
        }
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}

struct CameraPreviewWrapper: UIViewRepresentable {
    
    var session: AVCaptureSession
    
    func updateUIView(_ uiView: CameraPreview, context: Context) {
        return
    }
    
    func makeUIView(context: Context) -> CameraPreview {
        let preview = CameraPreview()
        preview.session = session
        return preview
   }
}
