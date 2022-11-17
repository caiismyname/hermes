//
//  Exporter.swift
//  Hermes
//
//  Created by David Cai on 10/21/22.
//

import Foundation
import AVFoundation
import Photos
import UIKit
import SwiftUI

class Exporter: ObservableObject {
    private var project: Project
    @Published var isProcessing = false
    
    init(project: Project) {
        self.project = project
    }
    
    func export() async {
        self.isProcessing = true
        guard photosPermissionsCheck() else { return }
        
        let movieInfo = await compileMovie()
//        let url = await exportMovieToURL(movie: movieInfo.asset, instructions: movieInfo.instructions)
        let url = await exportMovieToURL(movie: movieInfo)
        await saveToPhotoLibrary(movieURL: url)
        
        self.isProcessing = false
    }
    
    private func photosPermissionsCheck() -> Bool {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .notDetermined:
            var res = false
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { authorized in
                res = self.photosPermissionsCheck()
            }
            return res
        case .restricted, .denied, .limited:
            return false
        case .authorized:
            return true
        @unknown default:
            return false
        }
    }
    
    private func saveToPhotoLibrary(movieURL: URL) async {
        guard photosPermissionsCheck() else { return } // Double checking but we should already have it from the beginning of the func
        print("Saving full movie to photo library for project \(self.project.id.uuidString))")
        
        PHPhotoLibrary.shared().performChanges({
            let assetCollection = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: "Hermes Vlogs")
            let creationRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: movieURL)
            assetCollection.addAssets([creationRequest?.placeholderForCreatedAsset] as NSFastEnumeration)
        }) {success, error in
            if !success {
                print(error?.localizedDescription)
            } else {
                print("Movie finished saving to photo library")
            }
        }
    }
    
//    private func compileMovie() async -> (asset: AVAsset, instructions: AVMutableVideoCompositionInstruction) {
    private func compileMovie() async -> AVAsset {
        print("Compiling full movie for project \(self.project.id.uuidString))")
        
        let fullMovie = AVMutableComposition()
        let fullMovieVideoTrack = fullMovie.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let fullMovieAudioTrack = fullMovie.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        var startCumulative = CMTime.zero
        
        return await withThrowingTaskGroup(of: AVMutableVideoCompositionLayerInstruction?.self) { group in
            do {
                for clip in project.allClips {
//                    guard clip.finalURL != nil else { return (AVMutableComposition(), AVMutableVideoCompositionInstruction()) }
                    guard clip.finalURL != nil else { return (AVMutableComposition()) }
                    
                    let clipContent = AVURLAsset(url: clip.finalURL!)
                    let clipDuration = try await clipContent.load(.duration) // Run this synchronously so we can use it in the following operations
                    
                    let timeRange = CMTimeRange(start: CMTime.zero, duration: clipDuration)
                    // Keep track of the unique start time for each clip's position in the full movie
                    let start = startCumulative
                    startCumulative = CMTimeAdd(startCumulative, clipDuration)
                    
                    // Async load and insert the audio track
                    group.addTask {
                        clipContent.loadTracks(withMediaType: .audio) { track, error in
                            do {
                                try fullMovieAudioTrack?.insertTimeRange(timeRange, of: track![0], at: start)
                            } catch {
                                print("Could not merge audio for clip \(clip.id.uuidString)")
                            }
                        }
                        return nil
                    }
                    
                    // Async load and insert the video track
                    group.addTask {
                        clipContent.loadTracks(withMediaType: .video) { track, error in
                            do {
                                try fullMovieVideoTrack?.insertTimeRange(timeRange, of: track![0], at: start)
                            } catch {
                                print("Could not merge video for clip \(clip.id.uuidString)")
                            }
                        }
                        return nil
                    }
                    
                    // Generate the orientation-fixing instruction for the video clip
                    group.addTask {
                        return await self.videoCompositionInstruction(
                            fullMovieVideoTrack!,
                            asset: clipContent,
                            clipStart: start,
                            orientation: clip.orientation
                        )
                    }
                }

                // Wait for the TaskGroup to compete, then compile all the instructions together
//                let fullInstruction = AVMutableVideoCompositionInstruction()
//                fullInstruction.timeRange = CMTimeRange(start: .zero, duration: startCumulative) // By the end, `startCumulative` will be equal to the end time of the full movie
//
//                var allInstructions = [AVMutableVideoCompositionLayerInstruction]()
//                for try await instruction in group {
//                    if instruction != nil {
//                        allInstructions.append(instruction!)
//                    }
//                }
                
                // Apply the compiled instructions to the full movie. Note that each instruction has its own start time so the list order doesn't matter
//                fullInstruction.layerInstructions = allInstructions
                
//                return (fullMovie, fullInstruction)
                return (fullMovie)
            } catch {
//                return (AVMutableComposition(), AVMutableVideoCompositionInstruction())
                return (AVMutableComposition())
            }
        }
    }
    
    private func videoCompositionInstruction(_ track: AVCompositionTrack, asset: AVAsset, clipStart: CMTime, orientation: AVCaptureVideoOrientation) async -> AVMutableVideoCompositionLayerInstruction {
        do {
            let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
            let assetTrack = try await asset.loadTracks(withMediaType: .video)[0]
            
            var transform = try await assetTrack.load(.preferredTransform)
            let size = try await assetTrack.load(.naturalSize)
            
//            print(transform, size.width, size.height)
            
            if orientation == .portrait {
                print("Portrait \(CGAffineTransformIsIdentity(transform))")
            } else if orientation == .portraitUpsideDown {
                print("upsidedown \(CGAffineTransformIsIdentity(transform))")
            } else if orientation == .landscapeLeft {
                print("left \(CGAffineTransformIsIdentity(transform))")
            } else if orientation == .landscapeRight {
                print("right \(CGAffineTransformIsIdentity(transform))")
//                transform = CGAffineTransformIdentity.scaledBy(x: 1080.0 / size.width, y: 1080.0 / 1920.0)
//                transform = transform.translatedBy(x: 0, y: 1920.0 / 2)
            }
        
            instruction.setTransform(transform, at: clipStart)
            return instruction
        } catch {
            print("Catching error in transform")
            return AVMutableVideoCompositionLayerInstruction()
        }
    }
  
//    private func exportMovieToURL(movie: AVAsset, instructions: AVMutableVideoCompositionInstruction) async -> URL {
    private func exportMovieToURL(movie: AVAsset) async -> URL {
        let exporter = AVAssetExportSession(asset: movie, presetName: AVAssetExportPresetHighestQuality)
        let url = URL(
            fileURLWithPath:
                (NSTemporaryDirectory() as NSString).appendingPathComponent(
                    (UUID().uuidString as NSString).appendingPathExtension("mov")!
                )
        )
        
        print("Exporting full movie to \(url) for project \(self.project.id.uuidString))")
        
        let composition = AVMutableVideoComposition()
//        composition.instructions = [instructions]
        composition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        composition.renderSize = CGSize(width: 1080, height: 1920)
        
        exporter?.outputURL = url
        exporter?.outputFileType = .mov
//        exporter?.videoComposition = composition
        await exporter?.export()
        
        print("Exported")
        
        return url
    }
}
