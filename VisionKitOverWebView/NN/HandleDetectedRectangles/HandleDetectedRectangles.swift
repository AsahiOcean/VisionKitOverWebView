import UIKit
import CoreML
import Vision

class HandleDetectedRectangles: UIView {
    
    fileprivate let remake = RemakeBounds()
    fileprivate let shapeLayer = RectangleShapeLayer()
    private var model: MLModel?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // https://developer.apple.com/machine-learning/models/
        guard let modelURL = Bundle.main.url(forResource: "YOLOv3Tiny", withExtension: "mlmodelc")
        else {
            self.backgroundColor = .systemRed
            return }
        self.model = try? MLModel(contentsOf: modelURL)
        
        // чтобы можно было нажать на webView
        self.isUserInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func inputImage(image: UIImage) {
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        guard let cgimage = image.cgImage else { return }
        
        let requests = self.handleDetectedRectangles()
        
        let imageRequestHandler = VNImageRequestHandler(cgImage: cgimage, orientation: orientation, options: [:])
        
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try imageRequestHandler.perform(requests)
            } catch let error as NSError {
                print("Failed to perform image request: \(error)")
                return
            }
        }
    }
    
    fileprivate func handleDetectedRectangles() -> [VNCoreMLRequest] {
        guard let model = try? VNCoreMLModel(for: self.model!)
        else { fatalError("VNCoreMLModel") }
        
        return [VNCoreMLRequest(model: model, completionHandler: { request, error in
            guard error == nil else { return }
            
            DispatchQueue.main.async {
                guard let results = request.results as? [VNRecognizedObjectObservation]
                else { return }
                
                CATransaction.begin()
                for result in results {
                    let len = result.labels.count > 5 ? 1 : result.labels.count
                    
                    for i in 0..<len {
                        let identifier = result.labels[i].identifier
                        let confidence = results[i].confidence
                        
                        let frame = self.remake.boundingBox(bBox: result.boundingBox, bounds: self.bounds)
                        let rectLayer = self.shapeLayer.painter(color: .systemBlue, frame: frame)
                        
                        self.layer.addSublayer(rectLayer)
                        
                        print("detected: \(identifier)\n  – conf: \(confidence)\n  – pos: (x: \(Int(frame.minX)), y: \(Int(frame.minY)), width: \(Int(frame.maxX)), height: \(Int(frame.maxY)))\n", terminator: "\n")
                    }
                }
                CATransaction.commit()
                self.setNeedsDisplay()
            }
        })]
    }
}
