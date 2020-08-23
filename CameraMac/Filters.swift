//
//  Filters.swift
//  TestFilters
//
//  Created by Charanbir sandhu on 15/07/20.
//  Copyright © 2020 Charan Sandhu. All rights reserved.
//

import AVFoundation
import Cocoa
import Vision

struct Model {
    let noseLine: [CGPoint]
    let faceCurve: [CGPoint]
    let medianLine: [CGPoint]
    let fullSize: CGSize
    let boxRect: CGRect
    let xAxisRotation: CGFloat
    let yAxisRotation: CGFloat
    let zAxisRotation: CGFloat
    let faceWidth: CGFloat
    let faceHeight: CGFloat
    let faceXpoint: CGFloat
    let faceYpoint: CGFloat
    let faceLeftYpoint: CGFloat
    let degre: Double
    let quadent: Int
}

class FilterMask: CIFilter {
    
    @objc var inputImage: CIImage?
    var arrFaces: [Any] = []
    
    override var attributes: [String : Any] {
        return [
            kCIAttributeFilterDisplayName: "Mask Filter" as AnyObject,
            "inputImage": [kCIAttributeIdentity: 0,
                           kCIAttributeClass: "CIImage",
                           kCIAttributeDisplayName: "Image",
                           kCIAttributeType: kCIAttributeTypeImage],
            
            "inputRectFace": [kCIAttributeClass: "[Any]"]
        ]
    }
    
    
    override func setDefaults() {
       
    }
    
    override init() {
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setValue(_ value: Any?, forKey key: String) {
        switch key {
        case "inputImage":
            if let value = value as? CIImage {
                inputImage = value
            }else {
                inputImage = nil
            }
        case "inputRectFace":
            if let value = value as? [Any] {
                arrFaces = value
            }else {
                arrFaces = []
            }
        default:
            break
        }
    }

    
        override var outputImage: CIImage! {
            guard let inputImage = inputImage else {return nil}
            guard let cgimage = convertCIImageToCGImage(inputImage: inputImage) else { return inputImage }

            let width =  cgimage.width
            let height = cgimage.height
            let imageSize = CGSize(width: width, height: height)
            let bitsPerComponent = cgimage.bitsPerComponent
            let bytesPerRow = cgimage.bytesPerRow
            let totalBytes = height * bytesPerRow
            let bitMapInfo = cgimage.bitmapInfo.rawValue
            let colorSpace = cgimage.colorSpace ?? CGColorSpaceCreateDeviceGray()
            var intensities = [UInt8](repeating: 0, count: totalBytes)
            let context = CGContext(data: &intensities, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitMapInfo)
            
            context?.draw(cgimage, in: CGRect(x: 0.0, y: 0.0, width: imageSize.width, height: imageSize.height))
            
            if arrFaces.count > 0, let faces = arrFaces as? [VNFaceObservation] {
                context?.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
                context?.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0))
                context?.setLineWidth(3)
                for face in faces {
                    let model = getPointsOfFace(coreImageSize: imageSize, face: face)
                    
                    context?.addLines(between: model.faceCurve)
                    context?.closePath()
                    context?.drawPath(using: .fillStroke)
                    
                    context?.addLines(between: model.noseLine)
                    context?.drawPath(using: .fillStroke)
                    
                    var faceHeight = model.faceHeight
//                    if faceHeight < model.faceWidth {
//                        faceHeight = model.faceWidth
//                    }
                    var val = Double(0)
                    if model.degre < 0 {
                        val = model.degre/(-90)
                    } else {
                        val = model.degre/90
                    }
                    let newVal = (model.faceWidth/2)*CGFloat(val)
                    
                    let x = model.faceXpoint+(model.xAxisRotation)
                    var y = CGFloat(0)
                    var newY = CGFloat(0)
                    if model.quadent == 1 || model.quadent == 2 {
                        y = ((model.faceYpoint+newVal)+(model.xAxisRotation))-faceHeight
                        newY = (model.faceYpoint+(model.xAxisRotation))+newVal
                    } else {
                        y = (model.faceYpoint-newVal)-faceHeight
                        newY = model.faceYpoint-newVal
                    }
                    let newX = model.faceXpoint
                    let transform = CGAffineTransform(translationX: newX, y: newY) .rotated(by: model.zAxisRotation) .translatedBy(x: -newX, y: -newY)
                    
                    if let newCiImage = NSImage(named: "mask")?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                        guard let newContext = CGContext(data: &intensities, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitMapInfo) else { continue }
                        newContext.concatenate(transform)
                        newContext.draw(newCiImage, in: CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: model.faceWidth, height: faceHeight)))
                        if let cgimg = newContext.makeImage() {
                            context?.draw(cgimg, in: CGRect(x: 0, y: 0, width: width, height: height))
                        }
                    }
                    
                }
            }
            
            guard let ciim = context?.makeImage() else { return inputImage }
            return CIImage(cgImage: ciim)
            
        }
    
    func getPointsOfFace(coreImageSize: CGSize, face: VNFaceObservation) -> Model {
        
        let box = readBoxRect(result: face, fullSize: coreImageSize)

        let faceCounter = readPointsOffaceContour(result: face, fullSize: coreImageSize)
        
        let midLine = readPointsOfMediumLine(result: face, fullSize: coreImageSize)
        
        let nose = readPointsOfnoseCrest(result: face, fullSize: coreImageSize)
        let noseLine = Array(nose.prefix(Int(Float(nose.count)/1.5)))

        var xAxisRotation: CGFloat = 0
        var zAxisRotation: CGFloat = 0
        var faceWidth: CGFloat = 0
        var faceXpoint: CGFloat = 0
        var faceYpoint: CGFloat = 0
        var faceLeftYpoint: CGFloat = 0
        var deg = Double(0)
        var quadent: Int = 0
        if let pointFirst = faceCounter.last, let pointLast = faceCounter.first {
            let slope = Double((pointLast.y - pointFirst.y) / (pointLast.x - pointFirst.x))
            var radient = Double(0)
            radient = Double(atanl(Float80(slope)))
            let degre = (radient * 180.0) / Double.pi
            deg = degre
            var newDeg = Double(0)
            if degre > 0 {
                if (pointLast.x - pointFirst.x) < 0 {
                    newDeg = -(90+(90-degre))
                    quadent = 2
                }else {
                    newDeg = -(270+(90-degre))
                    quadent = 4
                }
            }else {
                if (pointLast.x - pointFirst.x) > 0 {
                    newDeg = degre
                    quadent = 1
                }else {
                    newDeg = -(180+(-degre))
                    quadent = 3
                }
            }
            xAxisRotation = CGFloat((newDeg * Double.pi) / 180)

            let base = (pointLast.x - pointFirst.x)
            let perpendicular = (pointLast.y - pointFirst.y)
            let polygenWidth = sqrt((base*base)+(perpendicular*perpendicular))
            faceWidth = polygenWidth
            
            faceXpoint = pointFirst.x
            faceLeftYpoint = pointFirst.y
            if let pointFirstNose = noseLine.first, let pointLastNose = noseLine.last {
                faceYpoint = pointFirstNose.y
                let slopeNose = Double((pointLastNose.y - pointFirstNose.y) / (pointLastNose.x - pointFirstNose.x))
                var radientNose = Double(0)
                radientNose = Double(atanl(Float80(slopeNose)))
                let degreNose = (radientNose * 180.0) / Double.pi
                
                var newNoseDeg = Double(0)
                if degreNose > 0 {
                    if (pointLastNose.x - pointFirstNose.x) < 0 {
                        newNoseDeg = -(90+(90-degreNose))
                    }else {
                        newNoseDeg = -(270+(90-degreNose))
                    }
                }else {
                    if (pointLastNose.x - pointFirstNose.x) > 0 {
                        newNoseDeg = -(360-degreNose)
                    }else {
                        newNoseDeg = -(180+(-degreNose))
                    }
                }
                newNoseDeg = -(-90-newNoseDeg)
                zAxisRotation = CGFloat(newNoseDeg - newDeg)
                if (zAxisRotation < 0 ? -zAxisRotation : zAxisRotation) > 180 {
                    if zAxisRotation < 0 {
                        zAxisRotation = 360 + zAxisRotation
                    }else {
                        zAxisRotation = -(360 - zAxisRotation)
                    }
                }
            }
        }
        
        var faceHeight: CGFloat = 0
        if let pointFirst = midLine.first, let pointLast = midLine.last{
            let base = (pointLast.x - pointFirst.x)
            let perpendicular = (pointLast.y - pointFirst.y)
            let polygenHeight = sqrt((base*base)+(perpendicular*perpendicular))
            faceHeight = polygenHeight
        }
        
        let yAxisRotation = (faceLeftYpoint-faceYpoint)
        
        let model = Model(noseLine: noseLine, faceCurve: faceCounter, medianLine: midLine, fullSize: coreImageSize, boxRect: box, xAxisRotation: zAxisRotation, yAxisRotation: yAxisRotation, zAxisRotation: xAxisRotation, faceWidth: faceWidth, faceHeight: faceHeight, faceXpoint: faceXpoint, faceYpoint: faceYpoint, faceLeftYpoint: faceLeftYpoint, degre: deg, quadent: quadent)
        return model
    }
    
    private func readBoxRect(result: VNFaceObservation, fullSize: CGSize) -> CGRect {
        let faceBounds = VNImageRectForNormalizedRect(result.boundingBox, Int(fullSize.width), Int(fullSize.height))
        return faceBounds
    }
    
    private func readPointsOffaceContour(result: VNFaceObservation, fullSize: CGSize) -> [CGPoint] {
        let boundingBox = result.boundingBox
        let faceContour = result.landmarks?.faceContour
        let face = getPointsOfElementFaceContour(landmark: faceContour, boundingBox: boundingBox, fullSize: fullSize)
        return face
    }
    
    private func readPointsOfMediumLine(result: VNFaceObservation, fullSize: CGSize) -> [CGPoint] {
        let boundingBox = result.boundingBox
        let faceContour = result.landmarks?.medianLine
        let medianLine = getPointsOfElementFaceContour(landmark: faceContour, boundingBox: boundingBox, fullSize: fullSize)
        return medianLine
    }
    
    private func readPointsOfnoseCrest(result: VNFaceObservation, fullSize: CGSize) -> [CGPoint] {
        let boundingBox = result.boundingBox
        let faceContour = result.landmarks?.noseCrest
        let noseCrest = getPointsOfElementFaceContour(landmark: faceContour, boundingBox: boundingBox, fullSize: fullSize)
        return noseCrest
    }
    
    private func getPointsOfElementFaceContour(landmark: VNFaceLandmarkRegion2D?, boundingBox: CGRect, fullSize: CGSize) -> [CGPoint] {
        guard let normalizedPoints = landmark?.normalizedPoints else { return []}
        let points = normalizedPoints.compactMap { point -> CGPoint in
            let absolute = point.absolutePoint(in: boundingBox)
            return VNImagePointForNormalizedPoint(absolute, Int(fullSize.width), Int(fullSize.height))
        }
        return points
    }
}

fileprivate func pointToRect(pointsArray: [CGPoint]) -> CGRect {
    var greatestXValue = pointsArray[0].x
    var greatestYValue = pointsArray[0].y
    var smallestXValue = pointsArray[0].x
    var smallestYValue = pointsArray[0].y
    for point in pointsArray {
        greatestXValue = max(greatestXValue, point.x);
        greatestYValue = max(greatestYValue, point.y);
        smallestXValue = min(smallestXValue, point.x);
        smallestYValue = min(smallestYValue, point.y);
    }
    let origin = CGPoint(x: smallestXValue, y: smallestYValue)
    let size = CGSize(width: greatestXValue - smallestXValue, height: greatestYValue - smallestYValue)
    return CGRect(origin: origin, size: size)
}

fileprivate func convertCIImageToCGImage(inputImage: CIImage) -> CGImage? {
    let context = CIContext(options: nil)
    return context.createCGImage(inputImage, from: inputImage.extent)
}

fileprivate func + (left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x + right.x, y: left.y + right.y)
}

extension CGRect {
    func scaled(size: CGSize) -> CGRect {
        return CGRect(
            x: self.origin.x * size.width,
            y: self.origin.y * size.height,
            width: self.size.width * size.width,
            height: self.size.height * size.height
        )
    }
}

extension CGPoint {
    var cgSize: CGSize { return CGSize(width: x, height: y) }

    func absolutePoint(in rect: CGRect) -> CGPoint {
        return CGPoint(x: x * rect.size.width, y: y * rect.size.height) + rect.origin
    }
    
    func scaled(size: CGSize) -> CGPoint {
        let origin = CGPoint(x: self.x * size.width,
                             y: (self.y) * size.height)
        return origin
    }
}

extension NSImage {
    var CGImage: CGImage {
        get {
            let imageData = self.tiffRepresentation!
            let source = CGImageSourceCreateWithData(imageData as CFData, nil).unsafelyUnwrapped
            let maskRef = CGImageSourceCreateImageAtIndex(source, Int(0), nil)
            return maskRef.unsafelyUnwrapped
        }
    }
}
