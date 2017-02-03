//
//  JFLiveStreamInfo.h
//  JFLivePlaye
//
//  Created by Jessonliu iOS on 2017/1/9.
//  Copyright © 2017年 Jessonliu. All rights reserved.
//

#import <Foundation/Foundation.h>

/// 流状态
typedef NS_ENUM(NSUInteger, JFLiveState){
    /// 准备
    JFLiveReady = 0,
    /// 连接中
    JFLivePending = 1,
    /// 已连接
    JFLiveStart = 2,
    /// 已断开
    JFLiveStop = 3,
    /// 连接出错
    JFLiveError = 4
};

typedef NS_ENUM(NSUInteger,JFLiveSocketErrorCode) {
    JFLiveSocketError_PreView               = 201,///< 预览失败
    JFLiveSocketError_GetStreamInfo         = 202,///< 获取流媒体信息失败
    JFLiveSocketError_ConnectSocket         = 203,///< 连接socket失败
    JFLiveSocketError_Verification          = 204,///< 验证服务器失败
    JFLiveSocketError_ReConnectTimeOut      = 205///< 重新连接服务器超时
};

@interface JFLiveStreamInfo : NSObject

/**
 流ID
 */
@property (nonatomic, copy) NSString *streamId;

/**
 token
 */
@property (nonatomic, copy) NSString *token;

/**
 上传地址 RTMP
 */
@property (nonatomic, copy) NSString *url;

/**
 上传 IP
 */
@property (nonatomic, copy) NSString *host;

/**
 上传端口
 */
@property (nonatomic, assign) NSInteger port;


@end
