//
//  FrameExtrectorDelegates.swift
//  OpenCvFaceDetection
//
//  Created by Charanbir sandhu on 15/07/20.
//  Copyright © 2020 Charan Sandhu. All rights reserved.
//

import Foundation
import AVKit

extension FrameExtractor: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from _: AVCaptureConnection) {
        handleVideoSampleBuffer(buffer: sampleBuffer)
    }
    
    private func handleVideoSampleBuffer(buffer: CMSampleBuffer) {
        // update the video dimensions information        
        guard let imageBuffer = CMSampleBufferGetImageBuffer(buffer) else { return }
        let sourceImage = CIImage(cvPixelBuffer: imageBuffer)
        let mirerodCiimage = sourceImage.oriented(forExifOrientation: 2)
        guard let coreImage = delegate?.filterImage(image: mirerodCiimage) else {return}
        getUIImageFromCIImage(ciImage: coreImage)
    }
    
    // MARK: CIImage to UIImage conversion
    func getUIImageFromCIImage(ciImage: CIImage) {
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let uiImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        delegate?.recorderDidUpdate(image: uiImage)
    }
}
