//
//  PoseView.swift
//  OgaFace
//
//  Created by Julian on 21.02.2022.
//

import UIKit
import MLKit
import MLImage
import CoreVideo
import React
import AVFoundation
import ARKit

class PoseView: UIView, ARSessionDelegate
{
  let captureOutputQueue: DispatchQueue = DispatchQueue(label: "capture-output-queue", qos: .userInitiated)
  
  var cameraCaptureSession: AVCaptureSession!
  var previewLayer: AVCaptureVideoPreviewLayer!
  var videoCaptureOutput: AVCaptureVideoDataOutput!
  
  let videoCaptureResolution: AVCaptureSession.Preset = .vga640x480
  var videoCaptureDeviceInput: AVCaptureDeviceInput!
  let videoCaptureBitrate: Int32 = 2600000
  let videoCaptureFramerate: Int32 = 15
  
  var faceDetector: FaceDetector? = nil
  
  private let sceneView = ARSCNView(frame: UIScreen.main.bounds)
  
  @objc var cameraType: NSString!
  {
    didSet
    {
      // Removing current video input if it exists
      if videoCaptureDeviceInput != nil
      {
        cameraCaptureSession.removeInput(videoCaptureDeviceInput)
        videoCaptureDeviceInput = nil
      }
      
      // Creating and storing the device input
      guard let videoCaptureDevice = PoseView.getVideoCaptureDevice(cameraType: cameraType, at: videoCaptureFramerate), let videoDeviceInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else
      {
        print("failed to add camera video capture device")
        return
      }
      // Setting video input
      videoCaptureDeviceInput = videoDeviceInput
      
      // Adding video input
      if (videoCaptureDeviceInput != nil)
      {
        cameraCaptureSession.addInput(videoCaptureDeviceInput)
      }
    }
  }
  
  @objc var detectionMode : NSString!
  {
    didSet
    {
      print("detectionMode set \(detectionMode)")
      
      let options = FaceDetectorOptions()
      options.performanceMode = .fast
      options.minFaceSize = 0.5
      options.landmarkMode = detectionMode == "landmark" ? .all : .none
      options.classificationMode = .none
      options.contourMode = detectionMode == "contour" ? .all : .none
      options.isTrackingEnabled = true
      faceDetector = FaceDetector.faceDetector(options: options)
      print("Face detector initialize")
    }
  }
  
  @objc var onDetect: RCTBubblingEventBlock?
  {
    didSet
    {
      print("on pose callback set")
    }
  }
  
  override init(frame: CGRect)
  {
    super.init(frame: frame)
    initialize()
  }
    
  required init?(coder: NSCoder)
  {
    super.init(coder: coder)
    initialize()
  }
  
  deinit
  {
    cameraCaptureSession.stopRunning()
  }
  
  override func layoutSubviews()
  {
    super.layoutSubviews()
    previewLayer.frame = bounds
  }
  
  private func initialize()
  {
    // Setting up video capture session
    cameraCaptureSession = AVCaptureSession()
    cameraCaptureSession.sessionPreset = videoCaptureResolution
    cameraCaptureSession.startRunning()
    
    // Setting up video and audio devices for recording video and receiving frames
    videoCaptureOutput = AVCaptureVideoDataOutput()
    videoCaptureOutput.alwaysDiscardsLateVideoFrames = true
    videoCaptureOutput.connection(with: .video)?.isEnabled = true
    cameraCaptureSession.addOutput(videoCaptureOutput)
    
    videoCaptureOutput.setSampleBufferDelegate(self, queue: captureOutputQueue)
    
    previewLayer = AVCaptureVideoPreviewLayer(session: cameraCaptureSession)
    previewLayer.videoGravity = .resizeAspectFill
    
//    let session = ARSession()
//    session.delegate = self
//    guard ARFaceTrackingConfiguration.isSupported else { return }
//    let configuration = ARFaceTrackingConfiguration()
//    if #available(iOS 13.0, *) {
//      configuration.maximumNumberOfTrackedFaces = ARFaceTrackingConfiguration.supportedNumberOfTrackedFaces
//    }
//    configuration.isLightEstimationEnabled = true
////    previewLayer.session?.startRunning()
//    sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    
    
    layer.masksToBounds = true
    layer.addSublayer(previewLayer)
    previewLayer.frame = bounds
    previewLayer.connection?.videoOrientation = .portrait
    print("initialize finished")
    // Adding callbacks for background process
//    let notificationCenter = NotificationCenter.default
//    notificationCenter.addObserver(self, selector: #selector(onMovedFromBackgroundToApp), name: UIApplication.didBecomeActiveNotification, object: nil)
//    notificationCenter.addObserver(self, selector: #selector(onMovedFromAppToBackground), name: UIApplication.willResignActiveNotification, object: nil)
  }
  
  private static func getVideoCaptureDevice(cameraType: NSString, at framerate: Int32) -> AVCaptureDevice!
  {
    var captureDevice: AVCaptureDevice! = nil
    
    if (cameraType == "front")
    {
      captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
    }
    else if (cameraType == "back")
    {
      captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }
    
    print("setting framerate of capture device to \(framerate) ...")
    
    // Trying to set framerate of capture device
    do
    {
      try captureDevice.lockForConfiguration()
      captureDevice.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: framerate)
      captureDevice.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: framerate)
      captureDevice.unlockForConfiguration()
      print("successfully set framerate of capture device to \(framerate)")
    }
    catch
    {
      print("failed to set framerate of capture device");
    }
    
    return captureDevice
  }
}

extension PoseView : AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate
{
  
  private func imageOrientation(deviceOrientation: UIDeviceOrientation, cameraPosition: AVCaptureDevice.Position) -> UIImage.Orientation
  {
    switch deviceOrientation
    {
    case .portrait:
      return cameraPosition == .front ? .leftMirrored : .right
    case .landscapeLeft:
      return cameraPosition == .front ? .downMirrored : .up
    case .portraitUpsideDown:
      return cameraPosition == .front ? .rightMirrored : .left
    case .landscapeRight:
      return cameraPosition == .front ? .upMirrored : .down
    case .faceDown, .faceUp, .unknown:
      return .up
    }
  }
  
  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
  {
    // Checking if the output captured is a video frame
    if (output == videoCaptureOutput)
    {
      // Setting orientation
      connection.videoOrientation = .portrait
      connection.isVideoMirrored = cameraType == "front"
      
      processVideoFrame(sampleBuffer: sampleBuffer)
    }
  }
  
  func processVideoFrame(sampleBuffer: CMSampleBuffer)
  {
    guard let onDetect = onDetect else { return }

//    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else
//    {
//        print("Failed to get image buffer from sample buffer.")
//        return
//    }
    
    // Creating vision image
    let image = VisionImage(buffer: sampleBuffer)
    
    if (cameraType == "front")
    {
      image.orientation = imageOrientation(deviceOrientation: UIDevice.current.orientation, cameraPosition: .front)
    }
    else if (cameraType == "back")
    {
      image.orientation = imageOrientation(deviceOrientation: UIDevice.current.orientation, cameraPosition: .back)
    }
    
    var faces: [Face]
  
    do
    {
      faces = try self.faceDetector!.results(in: image)
    }
    catch let error
    {
      print("Failed to detect pose with error: \(error.localizedDescription).")
      return
    }
    
    guard !faces.isEmpty else
    {
//      onDetect(["faces": []])
      print("Empty contours")
      return
    }
    let convertedFace = PoseView.convertMLKitFace(face: faces[0])
    onDetect(["face": convertedFace])
//    onDetect(["pose": PoseModule.convertMLKitPoseToOgaPose(pose: results[0], width: Int(imageWidth), height: Int(imageHeight), mirrorPositions: mirror, swapLimbs: swapLimbs)])
  }
  
  public static func convertMLKitFace(face: Face) -> [NSDictionary]
  {
    var data = [NSDictionary]()
    let faceContour = face.contour(ofType: .face)
    let noseBottomContour = face.contour(ofType: .noseBottom)
    let noseBridgeContour = face.contour(ofType: .noseBridge)
    
    let leftEyeContour = face.contour(ofType: .leftEye)
    let rightEyeContour = face.contour(ofType: .rightEye)
    let lowerLipBottom = face.contour(ofType: .lowerLipBottom)
    let lowerLipTop = face.contour(ofType: .lowerLipTop)
    let upperLipBottom = face.contour(ofType: .upperLipBottom)
    let upperLipTop = face.contour(ofType: .upperLipTop)
    
    let rightEyeLandmark = face.landmark(ofType: .rightEye)
    let leftEyeLandmark = face.landmark(ofType: .leftEye)
    let leftCheekLandmark = face.landmark(ofType: .leftCheek)
    let rightCheekLandmark = face.landmark(ofType: .rightCheek)
    let leftEarLandmark = face.landmark(ofType: .leftEar)
    let rightEarLandmark = face.landmark(ofType: .rightEar)
    let mouthBottomLandmark = face.landmark(ofType: .mouthBottom)
    let mouthLeftLandmark = face.landmark(ofType: .mouthLeft)
    let mouthRightLandmark = face.landmark(ofType: .mouthRight)
    let noseBaseLandmark = face.landmark(ofType: .noseBase)

    data = [
      [
        "name": "faceContour",
        "points": convertContourPoints(points: faceContour?.points ?? [])
      ],
      [
        "name": "noseBottom",
        "points": convertContourPoints(points: noseBottomContour?.points ?? []),
        "position": convertPositionPoints(landmark: noseBaseLandmark ?? nil)
      ],
      [
        "name": "noseBridgeContour",
        "points":convertContourPoints(points: noseBridgeContour?.points ?? [])
      ],
      [
        "name": "leftEyeContour",
        "points":convertContourPoints(points: leftEyeContour?.points ?? []),
        "position": convertPositionPoints(landmark: leftEyeLandmark ?? nil)
      ],
      [
        "name": "rightEyeContour",
        "points":convertContourPoints(points: rightEyeContour?.points ?? []),
        "position": convertPositionPoints(landmark: rightEyeLandmark ?? nil)
      ],
      [
        "name": "lowerLipTop",
        "points":convertContourPoints(points: lowerLipTop?.points ?? [])
      ],
      [
        "name": "lowerLipBottom",
        "points":convertContourPoints(points: lowerLipBottom?.points ?? [])
      ],
      [
        "name": "upperLipTop",
        "points":convertContourPoints(points: upperLipTop?.points ?? [])
      ],
      [
        "name": "upperLipBottom",
        "points":convertContourPoints(points: upperLipBottom?.points ?? [])
      ],
      [
        "name": "leftCheek",
        "position": convertPositionPoints(landmark: leftCheekLandmark ?? nil)
      ],
      [
        "name": "rightCheek",
        "position": convertPositionPoints(landmark: rightCheekLandmark ?? nil)
      ],
      [
        "name": "leftEar",
        "position": convertPositionPoints(landmark: leftEarLandmark ?? nil)
      ],
      [
        "name": "rightEar",
        "position": convertPositionPoints(landmark: rightEarLandmark ?? nil)
      ],
      [
        "name": "mouthBottom",
        "position": convertPositionPoints(landmark: mouthBottomLandmark ?? nil)
      ],
      [
        "name": "mouthLeft",
        "position": convertPositionPoints(landmark: mouthLeftLandmark ?? nil)
      ],
      [
        "name": "mouthRight",
        "position": convertPositionPoints(landmark: mouthRightLandmark ?? nil)
      ],
    ]
    print("returning converted contours")
    return data
  }
  
  public static func convertContourPoints(points: [VisionPoint]) -> [Int: Any]
  {
    var data: [Int: Any] = [:]
    var index = 0
    for point in points {
      data[index] = ["x": point.x, "y": point.y]
      index += 1
    }
    return data
  }
  
  public static func convertPositionPoints(landmark: FaceLandmark?) -> [String: CGFloat]
  {
    let data = ["x": landmark?.position.x ?? 0, "y": landmark?.position.y ?? 0]
    return data
  }
}

@objc(PoseViewManager)
class PoseViewManager : RCTViewManager
{
  override func view() -> UIView!
  {
    return PoseView()
  }
  
  override class func requiresMainQueueSetup() -> Bool
  {
    return true
  }
}
