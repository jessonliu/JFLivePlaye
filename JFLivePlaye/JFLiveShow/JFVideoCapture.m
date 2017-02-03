//
//  JFVideoCapture.m
//  JFLivePlaye
//
//  Created by Jessonliu iOS on 2017/1/13.
//  Copyright © 2017年 Jessonliu. All rights reserved.
//

#import "JFVideoCapture.h"
#import "GPUImage.h"

@interface JFVideoCapture ()

@property(nonatomic, strong) GPUImageVideoCamera *videoCamera;
@property(nonatomic, strong) GPUImageOutput<GPUImageInput> *filter;
@property(nonatomic, strong) GPUImageOutput<GPUImageInput> *emptyFilter;
@property(nonatomic, strong) GPUImageOutput<GPUImageInput> *beau;
@property(nonatomic, strong) GPUImageCropFilter *cropfilter;
@property(nonatomic, strong) GPUImageView *gpuImageView;

@property (nonatomic, strong) NSString *videoavSessionPreset;

@end

@implementation JFVideoCapture

- (instancetype)init {
    if ([super init]) {
        self.videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionFront];
        self.videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
        self.videoCamera.horizontallyMirrorFrontFacingCamera = YES;
        self.videoCamera.horizontallyMirrorRearFacingCamera = NO;
        self.videoCamera.frameRate = 24;    // 默认帧率为 24;
        
        self.gpuImageView = [[GPUImageView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        
        [_gpuImageView setFillMode:kGPUImageFillModePreserveAspectRatioAndFill];
        [_gpuImageView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        
        self.beautyFace = YES;
    }
    return self;
}

- (void)dealloc {
    [self.videoCamera stopCameraCapture];
}

- (void)setRunning:(BOOL)running {
    if (_running != running) {
        _running = running;
        if (_running) {
            [UIApplication sharedApplication].idleTimerDisabled = YES;
        } else {
            [UIApplication sharedApplication].idleTimerDisabled = NO;
        }
    }
}

- (void)setShowVideoView:(UIView *)showVideoView {
    if (_gpuImageView.superview) {
        [_gpuImageView removeFromSuperview];
    }
    [showVideoView insertSubview:_gpuImageView atIndex:0];
}

- (UIView *)showVideoView {
    return _gpuImageView.superview;
}

//- (void)setCaptureDevicePosition:(AVCaptureDevicePosition)captureDevicePosition{
//    [_videoCamera rotateCamera];
//    _videoCamera.frameRate = (int32_t)_configuration.videoFrameRate;
//}










- (NSString *)videoavSessionPreset {
    NSString *preset;
    switch (self.sessionPreset) {
        case JFCaptureSessionPreset368x640:
        {
            preset = AVCaptureSessionPreset640x480;
        }
            break;
        case JFCaptureSessionPreset540x960:
        {
            preset = AVCaptureSessionPresetiFrame960x540;
        }
            break;
        case JFCaptureSessionPreset720x1280:
        {
            preset = AVCaptureSessionPreset1280x720;
        }
            break;
        default:{
            preset = AVCaptureSessionPreset640x480;
        }
            break;
    }
    return preset;
}

@end
