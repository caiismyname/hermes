//
//  CameraManager.swift
//  Hermes
//
//  Created by David Cai on 9/17/22.
//

import Foundation
import AVFoundation

class CameraManager: ObservableObject {
    @Published var error: CameraError?
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.caiismyname.SessionQ")
    private var videoInput: AVCaptureDeviceInput?
    private let videoOutput = AVCaptureVideoDataOutput()
    private var status = Status.unconfigured
    
    enum Status {
        case unconfigured
        case configured
        case unauthorized
        case failed
    }
    
    init() {
        configure()
    }
    
    private func configure() {
        checkPermissions()
        sessionQueue.async {
            self.configureCaptureSession()
            self.session.startRunning()
        }
    }
    
    private func set(error:CameraError?) {
        DispatchQueue.main.async {
            self.error = error
        }
    }
    
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { authorized in
                if !authorized {
                    self.status = Status.unauthorized
                    self.set(error: .deniedAuthorization)
                }
                self.sessionQueue.resume()
            }
        case .restricted:
            status = .unauthorized
            set(error: .restrictedAuthorization)
        case .denied:
            status = .unauthorized
            set(error: .deniedAuthorization)
        case .authorized:
            break
        @unknown default:
            status = .unauthorized
            set(error: .unknownAuthorization)
        }
    }
    
    private func configureCaptureSession() {
        guard status == .unconfigured else {
            return
        }
        
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }
        
//        let backVideoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInWideAngleCamera], mediaType: .video, position: .back)
//        let backVideoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTripleCamera, .builtInDualCamera, .builtInWideAngleCamera], mediaType: .video, position: .back)
//        print(backVideoDeviceDiscoverySession.devices[0].constituentDevices[0].)
//
        
        // Set up back camera device
        guard let mainBackCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            set(error: .cameraUnavailable)
            status = .failed
            return
        }
        
        // Extract Input from Device, attach Device to Session
        addCameraToSession(camera: mainBackCamera)
        
        // Connect Output to Session
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            let videoConnection = videoOutput.connection(with: .video)
            videoConnection?.videoOrientation = .portrait
            
            if ((videoConnection?.isVideoStabilizationSupported) != nil) {
                videoConnection?.preferredVideoStabilizationMode = .auto
            }
        } else {
            set(error: .cannotAddOutput)
            status = .failed
            return
        }
        
        configureAudioSession()
        
        status = .configured
    }
    
    private func addCameraToSession(camera: AVCaptureDevice) {
        do {
            let newInput = try AVCaptureDeviceInput(device: camera)
            
            if self.videoInput != nil {
                self.session.removeInput(self.videoInput!)
            }
            
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                self.videoInput = newInput
            } else {
                set(error: .cannotAddInput)
                status = .failed
                return
            }
        } catch {
            print("Error adding camera \(error)")
        }
    }
    
    private func configureAudioSession() {
        do {
            let audioDevice = AVCaptureDevice.default(for: .audio)
            let audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice!)
            
            if session.canAddInput(audioDeviceInput) {
                session.addInput(audioDeviceInput)
            } else {
                set(error: .cannotAddInput)
                status = .failed
                return
            }
        } catch {
            status = .failed
            print("Error configuring audio input")
            return
        }
    }
    
    func changeCamera() {
        guard self.videoInput != nil else { return }
        
        if self.videoInput!.device.position == .back {
            // Set up front camera device
            let frontCameraDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front)
            guard let frontCamera = frontCameraDiscoverySession.devices.first else {
                return
            }
            
            addCameraToSession(camera: frontCamera)
        } else {
            // Main back camera
            guard let mainBackCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                set(error: .cameraUnavailable)
                status = .failed
                return
            }
            
            addCameraToSession(camera: mainBackCamera)
        }
    }
    
    func set(_ delegate: AVCaptureVideoDataOutputSampleBufferDelegate, queue: DispatchQueue) {
        sessionQueue.async {
            self.videoOutput.setSampleBufferDelegate(delegate, queue: queue)
        }
    }
    
}
