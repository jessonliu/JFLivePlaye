//
//  JFRtmpSocket.h
//  JFLivePlaye
//
//  Created by Jessonliu iOS on 2017/1/9.
//  Copyright © 2017年 Jessonliu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JFLiveStreamInfo.h"
#import "JFFrame.h"

@class JFRtmpSocket;
@protocol JFRtmpSocketDelegate <NSObject>

/** callback socket current status (回调当前网络情况) */
- (void)socketStatus:(nullable JFRtmpSocket *)socket status:(JFLiveState)status;

@end

@interface JFRtmpSocket : NSObject

@property (nonatomic, assign)_Nullable id<JFRtmpSocketDelegate> delegate;

// 初始化
- (nullable instancetype)initWithStream:(nullable JFLiveStreamInfo *)stream;

- (void) start;
- (void) stop;
- (void) sendFrame:(nullable JFFrame*)frame;

@end
