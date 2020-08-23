//
//  FrameExtractor.swift
//  OpenCvFaceDetection
//
//  Created by Charanbir sandhu on 15/07/20.
//  Copyright © 2020 Charan Sandhu. All rights reserved.
//

import AVFoundation
import AVKit

protocol FrameExtractorDelegate: class {
    func recorderDidUpdate(image: NSImage)
    func filterImage(image: CIImage) -> CIImage
}

class FrameExtractor: NSObject {

    private var position = AVCaptureDevice.Position.unspecified
    private let quality = AVCaptureSession.Preset.medium
    
    private var permissionGranted = false
    let sessionQueue = DispatchQueue(label: "session queue")
    let captureSession = AVCaptureSession()
    private var videoDevice: AVCaptureDevice?
    let context = CIContext()
    private var zoom: CGFloat = 1
    private var beginZoomScale: CGFloat = 1
    private var hasFlash: Bool {
        return videoDevice?.hasTorch ?? false
    }
    var isRecording = false
    var torchLevel: Float = 0 {
        didSet {
            if !hasFlash { return }
            if !(videoDevice?.isTorchAvailable ?? false) { return }
            try? videoDevice?.lockForConfiguration()
            if torchLevel > 0.1 {
                try? videoDevice?.setTorchModeOn(level: torchLevel)
            } else {
                videoDevice?.torchMode = .off
            }
            videoDevice?.unlockForConfiguration()
        }
    }
    
    weak var delegate: FrameExtractorDelegate?
    
    override init() {
        super.init()
        checkPermission()
        sessionQueue.async { [unowned self] in
            self.configureSession()
            self.captureSession.startRunning()
        }
    }
    
    // MARK: AVSession configuration
    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            requestPermission()
        default:
            permissionGranted = false
        }
    }
    
    private func requestPermission() {
        sessionQueue.suspend()
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { [unowned self] granted in
            self.permissionGranted = granted
            self.sessionQueue.resume()
        }
    }
    
    private func configureSession() {
        guard permissionGranted else { return }
        captureSession.sessionPreset = quality
        
        if let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: position) {
            self.videoDevice = videoDevice
            if let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) {
                if captureSession.canAddInput(videoDeviceInput) {
                    captureSession.addInput(videoDeviceInput)
                }
            }
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer video"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
    }
}

