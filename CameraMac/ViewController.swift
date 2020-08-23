//
//  ViewController.swift
//  CameraMac
//
//  Created by Charanbir sandhu on 18/07/20.
//  Copyright © 2020 Charan Sandhu. All rights reserved.
//

import Cocoa
import Vision

class ViewController: NSViewController {
    @IBOutlet weak var imageView: NSImageView!
    private var filters: [CIFilter] = [FilterMask()]
    var frameExtractor: FrameExtractor!
    private lazy var sequenceHandler = VNSequenceRequestHandler()
    private var tuppleToReturn: [Any] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        frameExtractor = FrameExtractor()
        frameExtractor.delegate = self
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

extension ViewController: FrameExtractorDelegate {
    func filterImage(image: CIImage) -> CIImage {
//        return image
        return runFilter(cameraImage: image)
    }
    
    func recorderDidUpdate(image: NSImage) {
        DispatchQueue.main.async {
            self.imageView.image = image
        }
    }
    
    func runFilter(cameraImage: CIImage) -> CIImage {
        var filterdImage = cameraImage
        if filters.count > 0  {
            let val = detect(image: cameraImage)
            for filter in filters {
                if filter is FilterMask {
                    filter.setValue(val, forKey: "inputRectFace")
                    filter.setValue(filterdImage, forKey: kCIInputImageKey)
                } else {
                    filter.setValue(filterdImage, forKey: kCIInputImageKey)
                }
                if let image = filter.outputImage {
                    filterdImage = image
                }
            }
        }
        return filterdImage
    }
    
    func detect(image: CIImage) -> [Any] {
        if #available(iOS 11.0, *) {
            let detectFaceRequest = VNDetectFaceLandmarksRequest(completionHandler: detectedFace)
            do {
                try sequenceHandler.perform( [detectFaceRequest], on: image)
                return tuppleToReturn
            } catch { return [] }
        } else { return [] }
    }
    
    @available(iOS 11.0, *)
    private func detectedFace(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNFaceObservation] else { return }
        tuppleToReturn = results
    }
    
}
