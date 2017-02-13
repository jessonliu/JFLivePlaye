//
//  JFLiveShowVC.m
//  JFLivePlaye
//
//  Created by Jessonliu iOS on 2017/1/5.
//  Copyright © 2017年 Jessonliu. All rights reserved.
//

#import "JFLiveShowVC.h"
#import <AVFoundation/AVFoundation.h>
#import "GPUImage.h"
#import "AACEncoder.h"
#import "JFVideoEncoder.h"
#import "JFLiveStreamInfo.h"
#import "JFRtmpSocket.h"

#define NOW (CACurrentMediaTime()*1000)


@interface JFLiveShowVC () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, JFRtmpSocketDelegate, JFVideoEncoderDelegate, AACEncoderDelegate> {
    dispatch_queue_t
                            videoProcessingQueue,
                            audioProcessingQueue,
                            _jfEncodeQueue_video,
                            _jfEncodeQueue_audio;
    VTCompressionSessionRef _encodeSesion;
    long                    _frameCount;
    FILE    *               _h264File;
    int                     _spsppsFound;
    FILE    *               _aacFile;
    dispatch_semaphore_t    _lock;
}

@property (weak, nonatomic) IBOutlet UIView *liveView;
@property (nonatomic, strong) AVCaptureSession *session;    // 音视频录制期间管理者
@property (nonatomic, strong) AVCaptureDevice *videoDevice; // 视频管理者, (用来操作所闪光灯, 聚焦, 摄像头切换)
@property (nonatomic, strong) AVCaptureDevice *audioDevice; // 音频管理者
@property (nonatomic, strong) AVCaptureDeviceInput *videoInput;   // 视频输入数据的管理对象
@property (nonatomic, strong) AVCaptureDeviceInput *audioInput;   // 音频输入数据的管理对象
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput; // 视频输出数据的管理者
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioOutput; // 音频输出数据的管理者

@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer; // 用来展示视频的图像

@property (nonatomic, strong) NSString *documentDictionary;

@property (nonatomic , strong) AACEncoder    *audioEncoder;
@property (nonatomic, strong) JFVideoEncoder *videoEncoder;

@property (nonatomic, strong) JFRtmpSocket *socket; // Rtmp 推流管理类

@property (nonatomic, assign) uint64_t timestamp;
@property (nonatomic, assign) BOOL isFirstFrame;
@property (nonatomic, assign) uint64_t currentTimestamp;
@property (nonatomic, assign) BOOL uploading;

@end

@implementation JFLiveShowVC

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBarHidden = NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    videoProcessingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    audioProcessingQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    _jfEncodeQueue_video = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    _jfEncodeQueue_audio = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    [self checkDeviceAuth];
    
    self.documentDictionary = [(NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES)) objectAtIndex:0];
    
    self.audioEncoder = [[AACEncoder alloc] init];
    self.audioEncoder.delegate = self;
    self.videoEncoder = [[JFVideoEncoder alloc] init];
    self.videoEncoder.delegate = self;
    
     _lock = dispatch_semaphore_create(1);
}

// 检查是否授权摄像头的使用权限
- (void)checkDeviceAuth {
    switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]) {
        case AVAuthorizationStatusAuthorized:   // 已授权
            NSLog(@"已授权");
            [self initAVCaptureSession];
            break;
        case AVAuthorizationStatusNotDetermined:    // 用户尚未进行允许或者拒绝,
        {
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                if (granted) {
                    NSLog(@"已授权");
                    [self initAVCaptureSession];
                } else {
                    NSLog(@"用户拒绝授权摄像头的使用, 返回上一页, 请打开--> 设置 -- > 隐私 --> 通用等权限设置");
                }
            }];
        }
            break;
        default:
        {
            NSLog(@"用户尚未授权摄像头的使用权");
        }
            break;
    }
}

// 初始化 管理者
- (void)initAVCaptureSession {
    self.session = [[AVCaptureSession alloc] init];
    // 设置录像的分辨率
    // 先判断是被是否支持要设置的分辨率
    if ([self.session canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
        // 如果支持则设置
        [self.session canSetSessionPreset:AVCaptureSessionPreset1280x720];
    } else if ([self.session canSetSessionPreset:AVCaptureSessionPresetiFrame960x540]) {
        [self.session canSetSessionPreset:AVCaptureSessionPresetiFrame960x540];
    } else if ([self.session canSetSessionPreset:AVCaptureSessionPreset640x480]) {
        [self.session canSetSessionPreset:AVCaptureSessionPreset640x480];
    }
    // 开始配置
    [self.session beginConfiguration];
    // 初始化视频管理
    self.videoDevice = nil;
    // 创建摄像头类型数组
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    // 便利管理抓捕道德所有支持制定类型的 设备集合
    for (AVCaptureDevice *device in devices) {
        if (device.position == AVCaptureDevicePositionFront) {
            self.videoDevice = device;
        }
    }
    // 视频
    [self videoInputAndOutput];
    
    // 音频
    [self audioInputAndOutput];
    
    // 录制的同时播放
    [self initPreviewLayer];
    
    // 提交配置
    [self.session commitConfiguration];
}

// 视频输入输出
- (void)videoInputAndOutput {
    NSError *error;
    // 视频输入
    // 初始化 根据输入设备来初始化输出对象
    self.videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.videoDevice error:&error];
    if (error) {
        NSLog(@"-- 摄像头出错 -- %@", error);
        return;
    }
    // 将输入对象添加到管理者 -- AVCaptureSession 中
    // 先判断是否能搞添加输入对象
    if ([self.session canAddInput:self.videoInput]) {
        // 管理者能够添加 才可以添加
        [self.session addInput:self.videoInput];
    }
    
    // 视频输出
    // 初始化 输出对象
    self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    // 是否允许卡顿时丢帧
    self.videoOutput.alwaysDiscardsLateVideoFrames = NO;
    if ([self supportsFastTextureUpload])
    {
        // 是否支持全频色彩编码 YUV 一种色彩编码方式, 即YCbCr, 现在视频一般采用该颜色空间, 可以分离亮度跟色彩, 在不影响清晰度的情况下来压缩视频
        BOOL supportsFullYUVRange = NO;
        
        // 获取输出对象 支持的像素格式
        NSArray *supportedPixelFormats = self.videoOutput.availableVideoCVPixelFormatTypes;
        
        for (NSNumber *currentPixelFormat in supportedPixelFormats)
        {
            if ([currentPixelFormat intValue] == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
            {
                supportsFullYUVRange = YES;
            }
        }
        
        // 根据是否支持 来设置输出对象的视频像素压缩格式,
        if (supportsFullYUVRange)
        {
            [self.videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        }
        else
        {
            [self.videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        }
    }
    else
    {
        [self.videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    }
    
    // 设置代理
    [self.videoOutput setSampleBufferDelegate:self queue:videoProcessingQueue];
    // 判断管理是否可以添加 输出对象
    if ([self.session canAddOutput:self.videoOutput]) {
        [self.session addOutput:self.videoOutput];
        AVCaptureConnection *connection = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo];
        // 设置视频的方向
        connection.videoOrientation = AVCaptureVideoOrientationPortrait;
        // 视频稳定设置
        if ([connection isVideoStabilizationSupported]) {
            connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
        }
        connection.videoScaleAndCropFactor = connection.videoMaxScaleAndCropFactor;
    }
}


// 音频输入输出
- (void)audioInputAndOutput {
    NSError *jfError;
    // 音频输入设备
    self.audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    
    // 音频输入对象
    self.audioInput = [[AVCaptureDeviceInput alloc] initWithDevice:self.audioDevice error:&jfError];
    if (jfError) {
        NSLog(@"-- 录音设备出错 -- %@", jfError);
    }
    
    // 将输入对象添加到 管理者中
    if ([self.session canAddInput:self.audioInput]) {
        [self.session addInput:self.audioInput];
    }
    
    // 音频输出对象
    self.audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    // 将输出对象添加到管理者中
    if ([self.session canAddOutput:self.audioOutput]) {
        [self.session addOutput:self.audioOutput];
    }
    
    // 设置代理
    [self.audioOutput setSampleBufferDelegate:self queue:audioProcessingQueue];
}

// 播放同时进行播放
- (void)initPreviewLayer {
    [self.view layoutIfNeeded];
    // 初始化对象
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    self.previewLayer.frame = self.view.layer.bounds;
    self.previewLayer.connection.videoOrientation = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo].videoOrientation;
    
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.previewLayer.position = CGPointMake(self.liveView.frame.size.width*0.5,self.liveView.frame.size.height*0.5);
    
    CALayer *layer = self.liveView.layer;
    layer.masksToBounds = true;
    [layer addSublayer:self.previewLayer];
}

#pragma mark 返回上一级
- (IBAction)backAction:(id)sender {
    // 结束直播
    [self.socket stop];
    [self.session stopRunning];
    [self.videoEncoder stopEncodeSession];
    fclose(_h264File);
    fclose(_aacFile);
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark 开始直播
- (IBAction)startLiveAction:(UIButton *)sender {
    _h264File = fopen([[NSString stringWithFormat:@"%@/jf_encodeVideo.h264", self.documentDictionary] UTF8String], "wb");
    _aacFile = fopen([[NSString stringWithFormat:@"%@/jf_encodeAudio.aac", self.documentDictionary] UTF8String], "wb");
    
    // 初始化 直播流信息
    JFLiveStreamInfo *streamInfo = [[JFLiveStreamInfo alloc] init];
    streamInfo.url = @"rtmp://192.168.1.110:1935/rtmplive/room";
    
    self.socket = [[JFRtmpSocket alloc] initWithStream:streamInfo];
    self.socket.delegate = self;
    [self.socket start];
    
    // 开始直播
    [self.session startRunning];
    sender.hidden = YES;
}

#pragma mark --  AVCaptureAudioDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (captureOutput == self.audioOutput) {
            [self.audioEncoder encodeSampleBuffer:sampleBuffer timeStamp:self.currentTimestamp completionBlock:^(NSData *encodedData, NSError *error) {
                fwrite(encodedData.bytes, 1, encodedData.length, _aacFile);
            }];
    } else {
        [self.videoEncoder encodeWithSampleBuffer:sampleBuffer timeStamp:self.currentTimestamp completionBlock:^(NSData *data, NSInteger length) {
            fwrite(data.bytes, 1, length, _h264File);
        }];
    }
}


- (void)dealloc {
    if ([self.session isRunning]) {
        [self.session stopRunning];
    }
    [self.videoOutput setSampleBufferDelegate:nil queue:dispatch_get_main_queue()];
    [self.audioOutput setSampleBufferDelegate:nil queue:dispatch_get_main_queue()];
}


// 是否支持快速纹理更新
- (BOOL)supportsFastTextureUpload;
{
#if TARGET_IPHONE_SIMULATOR
    return NO;
#else
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-pointer-compare"
    return (CVOpenGLESTextureCacheCreate != NULL);
#pragma clang diagnostic pop
    
#endif
}


// 保存h264数据到文件
- (void) writeH264Data:(void*)data length:(size_t)length addStartCode:(BOOL)b
{
    // 添加4字节的 h264 协议 start code
    const Byte bytes[] = "\x00\x00\x00\x01";
    
    if (_h264File) {
        if(b)
            fwrite(bytes, 1, 4, _h264File);
        
        fwrite(data, 1, length, _h264File);
    } else {
        NSLog(@"_h264File null error, check if it open successed");
    }
}


#pragma mark - JFRtmpSocketDelegate
- (void)jf_videoEncoder_call_back_videoFrame:(JFVideoFrame *)frame {
    if (self.uploading) {
       [self.socket sendFrame:frame];
    }
}

#pragma mark - AACEncoderDelegate
- (void)jf_AACEncoder_call_back_audioFrame:(JFAudioFrame *)audionFrame {
    
    if (self.uploading) {
        [self.socket sendFrame:audionFrame];
    }
}

#pragma mark -- JFRtmpSocketDelegate
- (void)socketStatus:(nullable JFRtmpSocket *)socket status:(JFLiveState)status {
    switch (status) {
        case JFLiveReady:
            NSLog(@"准备");
            break;
        case JFLivePending:
            NSLog(@"链接中");
            break;
        case JFLiveStart:
            NSLog(@"已连接");
            if (!self.uploading) {
                self.timestamp = 0;
                self.isFirstFrame = YES;
                self.uploading = YES;
            }
            break;
        case JFLiveStop:
            NSLog(@"已断开");
            break;
        case JFLiveError:
            NSLog(@"链接出错");
            self.uploading = NO;
            self.isFirstFrame = NO;
            self.uploading = NO;
            break;
        default:
            break;
    }
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}




- (uint64_t)currentTimestamp{
    dispatch_semaphore_wait(_lock, DISPATCH_TIME_FOREVER);
    uint64_t currentts = 0;
    if(_isFirstFrame == true) {
        _timestamp = NOW;
        _isFirstFrame = false;
        currentts = 0;
    }
    else {
        currentts = NOW - _timestamp;
    }
    dispatch_semaphore_signal(_lock);
    return currentts;
}












/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end
