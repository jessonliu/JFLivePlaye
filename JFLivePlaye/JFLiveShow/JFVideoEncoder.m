//
//  JFVideoEncoder.m
//  JFLivePlaye
//
//  Created by Jessonliu iOS on 2017/1/6.
//  Copyright © 2017年 Jessonliu. All rights reserved.
//

#import "JFVideoEncoder.h"

@interface JFVideoEncoder () {
    VTCompressionSessionRef _encodeSesion;
    long    _frameCount;
    dispatch_queue_t  _jfEncodeQueue_video;
    int _fps;       // 帧率
    int _bitRate;   // 比特率
}
@property (nonatomic, copy) JFVideoEncoderCompletionBlock completionBlock;
@property (nonatomic, strong) NSData *sps_jf;
@property (nonatomic, strong) NSData *pps_jf;
@end

@implementation JFVideoEncoder

- (instancetype)init {
    if (self = [super init]) {
        _jfEncodeQueue_video = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        
        // 设置视频的宽高, 宽高必须给 2 的倍数, 不然会出现蓝边
        // framerate 设置帧率 级fps
        // 设置比特率
        
        /**
         // 分辨率： 368 *640 帧数：15 码率：500Kps
         // 分辨率： 368 *640 帧数：24 码率：800Kps
         // 分辨率： 368 *640 帧数：30 码率：800Kps
         // 分辨率： 540 *960 帧数：15 码率：800Kps
         // 分辨率： 540 *960 帧数：24 码率：800Kps
         // 分辨率： 540 *960 帧数：30 码率：800Kps
         // 分辨率： 720 *1280 帧数：15 码率：1000Kps
         // 分辨率： 720 *1280 帧数：24 码率：1200Kps
         // 分辨率： 720 *1280 帧数：30 码率：1200Kps
         */
        
        int width = 540;
        int height = 960;
        
        // fps 帧率, 即每秒显示图片的数量
        _fps = 24;
        
        // dps 比特率 即码率 比特率是指每秒传送的比特(bit)数, 也可理解为单位时间内二进制传输的数量 数据传输速率的常用单位
        _bitRate = 800 * 1000;
        [self startEncodeSessionWithVideoSize:CGSizeMake(width, height) framerate:_fps bitrate:_bitRate];
        
    }
    return self;
}


#pragma mark -- UseVideoToolbox encode
// 利用系统 VideoToolbox 视频硬编码框架近视 h.264 编码
- (int)startEncodeSessionWithVideoSize:(CGSize)size framerate:(int)fps bitrate:(int)bt {
    
    if (_encodeSesion) {
        VTCompressionSessionCompleteFrames(_encodeSesion, kCMTimeInvalid);
        VTCompressionSessionInvalidate(_encodeSesion);
        CFRelease(_encodeSesion);
        _encodeSesion = NULL;
    }
    
    OSStatus status;
    _frameCount = 0;    // 帧数
    
    status = VTCompressionSessionCreate(kCFAllocatorDefault, size.width, size.height, kCMVideoCodecType_H264, NULL, NULL, NULL, VideoCompressonOutputCallback, (__bridge void *)(self), &_encodeSesion);
    
    if (status != noErr) {
        NSLog(@"VTCompressionSessionCreate failed. ret=%d", (int)status);
        return -1;
    }
    
    // 设置关键帧间隔，即gop size 一组图片的间隔
    status = VTSessionSetProperty(_encodeSesion, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)@(fps*2));
    
    status = VTSessionSetProperty(_encodeSesion, kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, (__bridge CFTypeRef)@(fps*2));
    
    // 设置帧率，只用于初始化session，不是实际fps
    status = VTSessionSetProperty(_encodeSesion, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef)@(fps));
    
    // 设置编码码率，如果不设置，默认将会以很低的码率编码，导致编码出来的视频很模糊
    status  = VTSessionSetProperty(_encodeSesion, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(bt));
    
    NSArray *limit = @[@(bt * 1.5/8),@(1)];
    // 设置数据速率限制
    status = VTSessionSetProperty(_encodeSesion, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)limit);
    // 设置实时编码输出，降低编码延迟
    status = VTSessionSetProperty(_encodeSesion, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    
    // h264 profile, 直播一般使用baseline，可减少由于b帧带来的延时
    status = VTSessionSetProperty(_encodeSesion, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
    
    // 防止编译B真是被自动重新排序
    status = VTSessionSetProperty(_encodeSesion, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
    
    // 设置H264 熵编码模式 H264标准采用了两种熵编码模式
    // 熵编码即编码过程中按熵原理不丢失任何信息的编码。信息熵为信源的平均信息量（不确定性的度量）
    status = VTSessionSetProperty(_encodeSesion, kVTCompressionPropertyKey_H264EntropyMode, kVTH264EntropyMode_CABAC);
    
    // 开始编码
    status = VTCompressionSessionPrepareToEncodeFrames(_encodeSesion);
    NSLog(@"start encode  return: %d", (int)status);
    
    return 0;
}

// 编码一帧图像，使用queue，防止阻塞系统摄像头采集线程
- (void)encodeWithSampleBuffer:(CMSampleBufferRef )sampleBuffer timeStamp:(uint64_t)timeStamp completionBlock:(JFVideoEncoderCompletionBlock)completionBlock {
    self.completionBlock = completionBlock;
    dispatch_sync(_jfEncodeQueue_video, ^{
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        // pts,必须设置，否则会导致编码出来的数据非常大，原因未知
        _frameCount ++;
        CMTime pts = CMTimeMake(_frameCount, 1000);
        CMTime duration = kCMTimeInvalid;
        NSDictionary *properties = nil;
        
        // 关键帧的最大间隔 设为 帧率的二倍
        if(_frameCount % (int32_t)_fps * 2 == 0){
            properties = @{(__bridge NSString *)kVTEncodeFrameOptionKey_ForceKeyFrame: @YES};
        }
        NSNumber *timeNumber = @(timeStamp);
        VTEncodeInfoFlags flags;
        
        // 送入编码器编码
        OSStatus statusCode = VTCompressionSessionEncodeFrame(_encodeSesion,
                                                              imageBuffer,
                                                              pts, duration,
                                                              (__bridge CFDictionaryRef)properties, (__bridge_retained void *)timeNumber, &flags);
        
        if (statusCode != noErr) {
            NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
            
            [self stopEncodeSession];
            return;
        }
    });

}

- (void)dealloc{
    if(_encodeSesion != NULL)
    {
        VTCompressionSessionCompleteFrames(_encodeSesion, kCMTimeInvalid);
        
        VTCompressionSessionInvalidate(_encodeSesion);
        CFRelease(_encodeSesion);
        _encodeSesion = NULL;
    }
}

- (void) stopEncodeSession
{
    VTCompressionSessionCompleteFrames(_encodeSesion, kCMTimeInvalid);
    
    VTCompressionSessionInvalidate(_encodeSesion);
    
    CFRelease(_encodeSesion);
    _encodeSesion = NULL;
}


// 编码回调, 系统每完成一帧编码后, 就会异步调用该方法, 该方法为c 语言
static void VideoCompressonOutputCallback(void *userData, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer) {
    
    if(!sampleBuffer) return;
    CFArrayRef array = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    if(!array) return;
    CFDictionaryRef dic = (CFDictionaryRef)CFArrayGetValueAtIndex(array, 0);
    if(!dic) return;
    
    
    uint64_t timeStamp = [((__bridge_transfer NSNumber*)sourceFrameRefCon) longLongValue];
    JFVideoEncoder *coder = (__bridge JFVideoEncoder *)userData;
    if (status != noErr) return;
    
    // 判断当前帧是否为关键帧
    BOOL keyFrame = !CFDictionaryContainsKey(dic, kCMSampleAttachmentKey_NotSync);
    
    // 获取 sps pps 数据, sps pps 只需要获取一次, 保存在h.264文件开头即可
    // SPS 对于H264而言，就是编码后的第一帧，如果是读取的H264文件，就是第一个帧界定符和第二个帧界定符之间的数据的长度是4
    // PPS 就是编码后的第二帧，如果是读取的H264文件，就是第二帧界定符和第三帧界定符中间的数据长度不固定。
    if (keyFrame && !coder.sps_jf)
    {
        size_t spsSize, spsCount;
        size_t ppsSize, ppsCount;
        
        const uint8_t *spsData, *ppsData;
        
        CMFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer);
        OSStatus err0 = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDesc, 0, &spsData, &spsSize, &spsCount, 0 );
        OSStatus err1 = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDesc, 1, &ppsData, &ppsSize, &ppsCount, 0 );
        
        if (err0==noErr && err1==noErr)
        {
            NSData *sData = [NSData dataWithBytes:spsData length:spsSize];
            NSData *pData = [NSData dataWithBytes:ppsData length:ppsSize];
            coder.sps_jf = sData;
            coder.pps_jf = pData;
            [coder writeH264Data:sData length:spsSize];
            [coder writeH264Data:pData length:ppsSize];
        }
    }
    
    size_t lengthAtOffset, totalLength;
    char *data;
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    OSStatus error = CMBlockBufferGetDataPointer(dataBuffer, 0, &lengthAtOffset, &totalLength, &data);
    
    if (error == noErr) {
        size_t offset = 0;
        const int lengthInfoSize = 4; // 返回的nalu数据前四个字节不是0001的startcode，而是大端模式的帧长度length
        
        // 循环获取nalu数据
        while (offset < totalLength - lengthInfoSize) {
            uint32_t naluLength = 0;
            memcpy(&naluLength, data + offset, lengthInfoSize); // 获取nalu的长度，
            
            // 大端模式转化为系统端模式
            naluLength = CFSwapInt32BigToHost(naluLength);
            
            JFVideoFrame *videoFrame = [JFVideoFrame new];
            videoFrame.timestamp = timeStamp;
            videoFrame.data = [[NSData alloc] initWithBytes:(data + offset + lengthInfoSize) length:naluLength];
            videoFrame.isKeyFrame = keyFrame;
            videoFrame.sps = coder.sps_jf;
            videoFrame.pps = coder.pps_jf;
            if (coder.delegate && [coder.delegate respondsToSelector:@selector(jf_videoEncoder_call_back_videoFrame:)]) {
                [coder.delegate jf_videoEncoder_call_back_videoFrame:videoFrame];
            }
            // 保存nalu数据到文件
            [coder writeH264Data:[[NSData alloc] initWithBytes:(data + offset + lengthInfoSize) length:naluLength] length:naluLength];
            
            // 读取下一个nalu，一次回调可能包含多个nalu
            offset += lengthInfoSize + naluLength;
        }
    }
}

// 保存h264数据到文件
- (void) writeH264Data:(NSData *)data length:(size_t)length
{
    // 添加4字节的 h264 协议 start code
    const Byte bytes[] = "\x00\x00\x00\x01"; // 每帧的界定符
    NSMutableData *mData = [[NSMutableData alloc] init];
    [mData appendBytes:bytes length:4];
    [mData appendData:data];
    self.completionBlock (mData, mData.length);
}



@end
