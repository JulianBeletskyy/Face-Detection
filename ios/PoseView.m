//
//  PoseView.m
//  OgaFace
//
//  Created by Julian on 21.02.2022.
//

#import <React/RCTViewManager.h>

@interface RCT_EXTERN_MODULE(PoseViewManager, RCTViewManager)
RCT_EXPORT_VIEW_PROPERTY(cameraType, NSString)
RCT_EXPORT_VIEW_PROPERTY(detectionMode, NSString)
RCT_EXPORT_VIEW_PROPERTY(onDetect, RCTBubblingEventBlock)
@end
