//
//  JFVideoCapture.h
//  JFLivePlaye
//
//  Created by Jessonliu iOS on 2017/1/13.
//  Copyright © 2017年 Jessonliu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>


/// 视频分辨率(都是16：9 当此设备不支持当前分辨率，自动降低一级)
typedef NS_ENUM(NSUInteger, JFCaptureSessionPreset){
    /// 低分辨率
    JFCaptureSessionPreset368x640 = 0,
    /// 中分辨率
    JFCaptureSessionPreset540x960 = 1,
    /// 高分辨率
    JFCaptureSessionPreset720x1280 = 2
};

@class JFVideoCapture;
@protocol JFVideoCaptureDelegate <NSObject>

- (void)jf_captureOutput:(JFVideoCapture *)capture pixeBuffer:(CVImageBufferRef)pixeBuffer;

@end

@interface JFVideoCapture : NSObject

@property (nonatomic, assign) id<JFVideoCaptureDelegate> delegate;
@property (nonatomic, assign) BOOL running;                             // 是否开始采集图像

@property (nonatomic, strong) UIView *showVideoView;                    // 显示视频的视图

@property (nonatomic, assign) AVCaptureDevicePosition devicePosition;   // 设备方向

@property (nonatomic, assign) BOOL beautyFace;                          // 是否美颜

@property (nonatomic, assign) NSInteger frameRate;                      // 帧率

// 分辨率
@property (nonatomic, assign) JFCaptureSessionPreset sessionPreset;



@end
