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
        
        let screenRect = UIScreen.main.bounds
        
        layer.frame = CGRect(x: 0, y: 0, width: screenRect.size.width, height: screenRect.size.height)
        layer.videoGravity = AVLayerVideoGravity.resizeAspect
        layer.connection?.videoOrientation = .portrait
        layer.removeAllAnimations()
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
    @Binding var orientation: UIDeviceOrientation
    
    func updateUIView(_ uiView: CameraPreview, context: Context) {
        uiView.videoPreviewLayer.connection?.videoOrientation = AVCaptureVideoOrientation(rawValue: orientation.rawValue)!
    }
    
    func makeUIView(context: Context) -> CameraPreview {
        let preview = CameraPreview()
        preview.session = session
        return preview
   }
}

struct AnimationBlockerView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> some UIViewController {
         OrientationHandler()
     }

     func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
     }

     class OrientationHandler: UIViewController {
         override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
             coordinator.animate(alongsideTransition: nil) { _ in
                 UIView.setAnimationsEnabled(true)
             }
             UIView.setAnimationsEnabled(false)
             super.viewWillTransition(to: size, with: coordinator);
         }
     }
}
