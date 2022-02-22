//
//  ARKitView.swift
//  OgaFace
//
//  Created by Julian on 22.02.2022.
//

import UIKit
import MLKit
import MLImage
import CoreVideo
import React
import AVFoundation
import ARKit

@objc(ARKitView)
class ARKitView : RCTViewManager, ARSCNViewDelegate
{
  private let sceneView = ARSCNView(frame: UIScreen.main.bounds)
  
  override func view() -> UIView!
  {
//    guard ARWorldTrackingConfiguration.isSupported else { return }
    sceneView.delegate = self
    sceneView.showsStatistics = true
    sceneView.session.run(ARFaceTrackingConfiguration(), options: [.resetTracking, .removeExistingAnchors])
    return sceneView
  }
  
  func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
    guard let device = sceneView.device else { return nil }
    let node = SCNNode(geometry: ARSCNFaceGeometry(device: device))
    //Projects the white lines on the face.
    node.geometry?.firstMaterial?.fillMode = .lines
    return node
  }
  // Updating mesh
  func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
    guard let faceAnchor = anchor as? ARFaceAnchor, let faceGeometry = node.geometry as? ARSCNFaceGeometry else { return }
    print()
    faceGeometry.update(from: faceAnchor.geometry)
  }
  
  override class func requiresMainQueueSetup() -> Bool
  {
    return true
  }
}
