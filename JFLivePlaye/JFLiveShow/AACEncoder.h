//
//  AACEncoder.h
//  JFLivePlaye
//
//  Created by Jessonliu iOS on 2017/1/6.
//  Copyright © 2017年 Jessonliu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "JFAudioFrame.h"

@protocol AACEncoderDelegate <NSObject>

- (void)jf_AACEncoder_call_back_audioFrame:(JFAudioFrame *)audionFrame;

@end

@interface AACEncoder : NSObject

@property (nonatomic) dispatch_queue_t encoderQueue;
@property (nonatomic) dispatch_queue_t callbackQueue;
@property (nonatomic, assign) id<AACEncoderDelegate> delegate;

- (void) encodeSampleBuffer:(CMSampleBufferRef)sampleBuffer timeStamp:(uint64_t)timeStamp completionBlock:(void (^)(NSData *encodedData, NSError* error))completionBlock;


@end
