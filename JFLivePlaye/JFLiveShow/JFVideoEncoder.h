//
//  JFVideoEncoder.h
//  JFLivePlaye
//
//  Created by Jessonliu iOS on 2017/1/6.
//  Copyright © 2017年 Jessonliu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import "JFVideoFrame.h"



typedef void (^JFVideoEncoderCompletionBlock)(NSData *data, NSInteger length);

@protocol JFVideoEncoderDelegate <NSObject>

- (void)jf_videoEncoder_call_back_videoFrame:(JFVideoFrame *)frame;

@end

@interface JFVideoEncoder : NSObject

@property (nonatomic, assign) id<JFVideoEncoderDelegate> delegate;

// 编码
- (void)encodeWithSampleBuffer:(CMSampleBufferRef )sampleBuffer timeStamp:(uint64_t)timeStamp completionBlock:(JFVideoEncoderCompletionBlock)completionBlock;

- (void)stopEncodeSession;

@end
