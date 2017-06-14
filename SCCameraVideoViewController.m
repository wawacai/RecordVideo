//
//  SCCameraVideoViewController.m
//  SoSoRun
//
//  Created by 彭作青 on 2017/4/19.
//  Copyright © 2017年 SouSouRun. All rights reserved.
//

#import "SCCameraVideoViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "Masonry.h"
#import <MediaPlayer/MediaPlayer.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>

@interface SCCameraVideoViewController () <AVCaptureFileOutputRecordingDelegate>
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureDeviceInput *videoCaptureDeviceInput;
@property (nonatomic, strong) AVCaptureDeviceInput *audioCaptureDeviceInput;
@property (nonatomic, strong) AVCaptureMovieFileOutput *captureMovieFileOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (nonatomic, assign) AVCaptureDevicePosition cameraPosition;
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, weak) AVPlayerLayer *playerLayer;
@property (nonatomic, copy) NSString *originFilePath;
@property (nonatomic, copy) NSString *compressVideoFilePath;
@property (nonatomic, weak) UIButton *cancelBtn;
@property (nonatomic, weak) UIButton *turnBtn;
@property (nonatomic, weak) CAShapeLayer *maskLayer;
@property (nonatomic, weak) UIButton *recordBtn;
@property (nonatomic, assign) CGRect beginRect;
@property (nonatomic, strong) UIBezierPath *beginPath;
@property (nonatomic, strong) CAShapeLayer *animateShapLayer;
@property (nonatomic, assign) CGFloat recordBtnWidth;
@property (nonatomic, weak) UIVisualEffectView *effectView;
@property (nonatomic, weak) UIButton *repeatRecordBtn;
@property (nonatomic, weak) UIButton *sendVideoBtn;
@property (nonatomic, assign) CGRect repeatRecordBtnFrame;
@property (nonatomic, assign) CGRect sendVideoBtnFrame;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSFileManager *fileManager;
@property (nonatomic, strong) UIImage *videoFirstImage;
@property (nonatomic, assign) NSInteger seconds;

@end

@implementation SCCameraVideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _fileManager = [NSFileManager defaultManager];
    _recordBtnWidth = 117;
    [self setupUI];
    [self deleteOutTimeVideo];
    [self setNeedsStatusBarAppearanceUpdate];
    if (self.navigationController.navigationBarHidden == NO) {
        [self.navigationController setNavigationBarHidden:YES animated:NO];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    self.repeatRecordBtnFrame = self.repeatRecordBtn.frame;
    self.sendVideoBtnFrame = self.sendVideoBtn.frame;
    
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    
    switch (status) {
        case PHAuthorizationStatusNotDetermined:
        {
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                
            }];
        }
            break;
        default:
//            [CustomHUD showHUDText:@"需要获得相册权限" inView:self.view hideDelay:2];
            break;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self.navigationController setNavigationBarHidden:NO animated:NO];
}

#pragma mark - AVCaptureFileOutputRecordingDelegate

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error {
    SOLog(@"---- 录制结束 ----");
    double fileSize = [self getfileSize:self.originFilePath];
    if (fileSize < 0.01) {
        [self repeatRecordVideo];
        return;
    }
    [self compressVideoWithOriginOutPutFileURL:outputFileURL];
}

#pragma mark - event response

- (void)repeatRecordVideo {
    [self.player pause];
    [self.playerLayer removeFromSuperlayer];
    
    self.playerLayer = nil;
    self.player = nil;
    self.recordBtn.hidden = NO;
    self.effectView.hidden = NO;
    self.cancelBtn.hidden = NO;
    self.turnBtn.hidden = NO;
    self.repeatRecordBtn.hidden = YES;
    self.sendVideoBtn.hidden = YES;
    [self.captureSession startRunning];
    self.repeatRecordBtn.frame = self.repeatRecordBtnFrame;
    self.sendVideoBtn.frame = self.sendVideoBtnFrame;
    [self deleteVideoWithPaht:self.compressVideoFilePath];
}

- (void)sendVideo {
    [self saveVideoToCameraRoll];
    
    if (self.sendVideoBlock) {
        self.sendVideoBlock(self.compressVideoFilePath, self.videoFirstImage);
    }
    
    [self cancelCamera];
}

- (void)cancelCamera {
    [self.captureSession stopRunning];
	
    if (self.navigationController == nil) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)turnCamera {
    if (self.cameraPosition == AVCaptureDevicePositionBack) {
        self.cameraPosition = AVCaptureDevicePositionFront;
    } else {
        self.cameraPosition = AVCaptureDevicePositionBack;
    }
    AVCaptureDevice *device = [self getCameraDeviceWithPosition:self.cameraPosition];
    
    if (device == nil) {
        SOLog(@"摄像头无法使用");
    }
    
    [self.captureSession beginConfiguration];
    [self.captureSession removeInput:self.videoCaptureDeviceInput];
    self.videoCaptureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:device error:nil];
    [self.captureSession addInput:self.videoCaptureDeviceInput];
    [self.captureSession commitConfiguration];
}

- (void)takeMovie:(UIButton *)btn {
    SOLog(@"录制视频");
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(timerMethod) userInfo:nil repeats:YES];
    [self startMaskLayerAnimationWithIsChangeBig];
    self.cancelBtn.hidden = YES;
    self.turnBtn.hidden = YES;
    AVCaptureConnection *captureConnection = [self.captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    
    if ([self.audioCaptureDeviceInput.device.activeFormat isVideoStabilizationModeSupported:AVCaptureVideoStabilizationModeCinematic]) {
        [captureConnection setPreferredVideoStabilizationMode:AVCaptureVideoStabilizationModeCinematic];
    }
    
    // 预览图层和视频方向保持一致,这个属性设置很重要，如果不设置，那么出来的视频图像可以是倒向左边的。
    captureConnection.videoOrientation= [self.captureVideoPreviewLayer connection].videoOrientation;
    
    // 路径转换成 URL 要用这个方法，用 NSBundle 方法转换成 URL 的话可能会出现读取不到路径的错误
    _originFilePath = [self getOriginMovieFilePath];
    NSURL *fileUrl=[NSURL fileURLWithPath:_originFilePath];
    
    // 往路径的 URL 开始写入录像 Buffer ,边录边写
    [self.captureMovieFileOutput startRecordingToOutputFileURL:fileUrl recordingDelegate:self];
}

- (void)finishMovie:(UIButton *)sender {
    SOLog(@"完成按钮被点击");
    if (self.seconds == 20 && sender != nil) {
        self.seconds = 0;
        return;
    }
    
    [self.timer invalidate];
    self.timer = nil;
    [self.captureMovieFileOutput stopRecording];
    [self.captureSession stopRunning];
    [self.maskLayer removeAllAnimations];
    [self.animateShapLayer removeAllAnimations];
}

#pragma mark - private methods

- (void)timerMethod {
    self.seconds++;
    
    if (self.seconds == 20) {
        [self finishMovie:nil];
    }
}

- (void)deleteOutTimeVideo {
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject stringByAppendingPathComponent:@"ssvideo"];
    SOLog(@"%@", [self.fileManager subpathsAtPath:path]);
    for (NSString *fileName in [self.fileManager subpathsAtPath:path]) {
        NSString *filePath = [path stringByAppendingPathComponent:fileName];
        NSDictionary *dict = [_fileManager attributesOfItemAtPath:filePath error:nil];
        SOLog(@"%@", dict);
        NSDate *startDate = [dict objectForKey:NSFileCreationDate];
        NSTimeInterval distance = [startDate timeIntervalSinceNow];
        if (fabs(distance) / 3600 / 24 > 7) {
            [self deleteVideoWithPaht:filePath];
        } else {
            return;
        }
    }
}

- (void)saveVideoToCameraRoll{
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library writeVideoAtPathToSavedPhotosAlbum:[NSURL fileURLWithPath:self.compressVideoFilePath] completionBlock:^(NSURL *assetURL, NSError *error){
        SOLog(@"ASSET URL: %@", assetURL);
        
        if(error) {
            SOLog(@"CameraViewController: Error on saving movie : %@ {imagePickerController}", error);
        } else {
            SOLog(@"保存成功");
        }
    }];
}

// 获取第一帧图片
- (UIImage*)getVideoPreViewImageWithPath:(NSString *)path {
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:path] options:nil];
    AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    gen.appliesPreferredTrackTransform = YES;
    CMTime time = CMTimeMakeWithSeconds(0.0, 600);
    NSError *error = nil;
    CMTime actualTime;
    CGImageRef image = [gen copyCGImageAtTime:time actualTime:&actualTime error:&error];
    UIImage *img = [[UIImage alloc] initWithCGImage:image];
    CGImageRelease(image);
    return img;
}

- (void)deleteVideoWithPaht:(NSString *)path {
    if ([_fileManager isDeletableFileAtPath:path]) {
        [_fileManager removeItemAtPath:path error:nil];
    }
}

- (void)startPlayMovieWithOutputFileURL:(NSURL *)outputFileURL {
    // 创建AVPlayerItem
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:outputFileURL];
    // 创建AVPlayer
    _player = [AVPlayer playerWithPlayerItem:item];
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    [self.view.layer addSublayer:_playerLayer];
    [self.view.layer insertSublayer:_playerLayer below:self.cancelBtn.layer];
    
    _playerLayer.frame = self.view.bounds;
    _playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.player play];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playbackFinished:) name:AVPlayerItemDidPlayToEndTimeNotification object:self.player.currentItem];
}

// 压缩视频
- (void)compressVideoWithOriginOutPutFileURL:(NSURL *)originOutPutFileURL {
    [self getfileSize:self.originFilePath];
    
    // 通过文件的 url 获取到这个文件的资源
    AVURLAsset *avAsset = [[AVURLAsset alloc] initWithURL:originOutPutFileURL options:nil];
    // 用 AVAssetExportSession 这个类来导出资源中的属性
    NSArray *compatiblePresets = [AVAssetExportSession exportPresetsCompatibleWithAsset:avAsset];
    
    // 压缩视频
    if ([compatiblePresets containsObject:AVAssetExportPresetLowQuality]) { // 导出属性是否包含低分辨率
        // 通过资源（AVURLAsset）来定义 AVAssetExportSession，得到资源属性来重新打包资源 （AVURLAsset, 将某一些属性重新定义
        AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:avAsset presetName:AVAssetExportPresetMediumQuality];
        // 设置导出文件的存放路径
        NSString *outFilePath = [self getCompressMovieFilePath];
        self.compressVideoFilePath = outFilePath;
        exportSession.outputURL = [NSURL fileURLWithPath:outFilePath];
        
        // 是否对网络进行优化
        exportSession.shouldOptimizeForNetworkUse = true;
        
        // 转换成MP4格式
        exportSession.outputFileType = AVFileTypeMPEG4;
        
        __weak typeof(self) weakSelf = self;
        // 开始导出,导出后执行完成的block
        [exportSession exportAsynchronouslyWithCompletionHandler:^{
            
            dispatch_async(dispatch_get_main_queue(), ^{
                int exportStatus = exportSession.status;
                switch (exportStatus) {
                    case AVAssetExportSessionStatusFailed:
                    {
                        NSError *exportError = exportSession.error;
                        SOLog (@"AVAssetExportSessionStatusFailed: %@", exportError);
                        break;
                    }
                    case AVAssetExportSessionStatusCompleted:
                    {
                        SOLog(@"视频转码成功 ---%@", [NSDate new]);
                        [weakSelf getfileSize:outFilePath];
                        weakSelf.videoFirstImage = [weakSelf getVideoPreViewImageWithPath:weakSelf.compressVideoFilePath];
                        
                        [weakSelf startPlayMovieWithOutputFileURL:[NSURL fileURLWithPath:weakSelf.compressVideoFilePath]];
                        
                        weakSelf.effectView.hidden = YES;
                        weakSelf.recordBtn.hidden = YES;
                        weakSelf.repeatRecordBtn.hidden = NO;
                        weakSelf.sendVideoBtn.hidden = NO;
                        CGRect repeatRecordBtnFrame = weakSelf.repeatRecordBtnFrame;
                        CGRect sendVideoBtnFrame = weakSelf.sendVideoBtnFrame;
                        repeatRecordBtnFrame.origin.x = 50;
                        sendVideoBtnFrame.origin.x = [UIScreen mainScreen].bounds.size.width - weakSelf.sendVideoBtn.bounds.size.width - 40;
                        
                        [UIView animateWithDuration:0.5 animations:^{
                            weakSelf.repeatRecordBtn.frame = repeatRecordBtnFrame;
                            weakSelf.sendVideoBtn.frame = sendVideoBtnFrame;
                        } completion:^(BOOL finished) {
                        }];
                        
                        [weakSelf deleteVideoWithPaht:weakSelf.originFilePath];
                        break;
                    }
                }
                
            });
        }];
    }
}

- (double)getfileSize:(NSString *)path {
    SOLog(@"%@", path);
    NSDictionary *outputFileAttributes = [self.fileManager attributesOfItemAtPath:path error:nil];
    double fileSize = (double)[outputFileAttributes fileSize]/1024.00 /1024.00;
    SOLog (@"file size: %f -- %lf", (unsigned long long)[outputFileAttributes fileSize]/1024.00 /1024.00, fileSize);
    return fileSize;
}

- (NSString *)getOriginMovieFilePath {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ssvideo"];
    [self.fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *filePath = [path stringByAppendingPathComponent:@"test.mp4"];
    return filePath;
}

- (NSString *)getCompressMovieFilePath {
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject stringByAppendingPathComponent:@"ssvideo"];
    if (![_fileManager fileExistsAtPath:path]) {
        [_fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd-HH:mm:ss"];
    NSDate *date = [[NSDate alloc] init];
    NSString *outPutPath = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"output-%@.mp4",[formatter stringFromDate:date]]];
    SOLog(@"%@",[_fileManager subpathsAtPath:path]);
    return outPutPath;
}

/**
 *  取得指定位置的摄像头
 */
- (AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position] == position) {
            return camera;
        }
    }
    return nil;
}

- (void)startMaskLayerAnimationWithIsChangeBig {
    UIBezierPath *endPath = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(_beginRect, -23.5, -23.5)];
    CABasicAnimation *anim = [CABasicAnimation animationWithKeyPath:@"path"];
    anim.duration = 0.25;
    
    anim.fromValue = (__bridge id _Nullable)(_beginPath.CGPath);
    anim.toValue = (__bridge id _Nullable)(endPath.CGPath);
    
    anim.removedOnCompletion = NO;
    anim.fillMode = kCAFillModeForwards;
    [_maskLayer addAnimation:anim forKey:nil];
    
    [self.recordBtn.layer addSublayer:self.animateShapLayer];
    CABasicAnimation *pathAnima = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    pathAnima.duration = 20.0f;
    pathAnima.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
    pathAnima.fromValue = [NSNumber numberWithFloat:0];
    pathAnima.toValue = [NSNumber numberWithFloat:1];
    pathAnima.fillMode = kCAFillModeForwards;
    pathAnima.removedOnCompletion = NO;
    [self.animateShapLayer addAnimation:pathAnima forKey:@"strokeEndAnimation"];
}

- (void)playbackFinished:(NSNotification *)notification {
    SOLog(@"视频播放完成.");
    // 播放完成后重复播放
    // 跳到最新的时间点开始播放
    [_player seekToTime:CMTimeMake(0, 1)];
    [_player play];
}

#pragma mark - system methods

- (BOOL)prefersStatusBarHidden {
    return YES;
}

#pragma mark - setter and getter

- (void)setupUI {
    [self setupVideoSessionUI];
    [self setupVideotapButton];
    [self setupUp];
    [self setupDownButton];
}

- (void)setupUp {
    // 取消按钮
    UIButton *cancelBtn = [UIButton new];
    [self.view addSubview:cancelBtn];
    [cancelBtn setImage:[UIImage imageNamed:@"closeCameraImage"] forState:UIControlStateNormal];
    cancelBtn.adjustsImageWhenHighlighted = NO;
    [cancelBtn addTarget:self action:@selector(cancelCamera) forControlEvents:UIControlEventTouchUpInside];
    
    [cancelBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.offset(20);
    }];
    
    // 翻转摄像头
    UIButton *turnBtn = [UIButton new];
    [self.view addSubview:turnBtn];
    [turnBtn setImage:[UIImage imageNamed:@"setCameraImage"] forState:UIControlStateNormal];
    turnBtn.adjustsImageWhenHighlighted = NO;
    [turnBtn addTarget:self action:@selector(turnCamera) forControlEvents:UIControlEventTouchUpInside];
    
    [turnBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(cancelBtn);
        make.right.offset(-20);
    }];
    
    _cancelBtn = cancelBtn;
    _turnBtn = turnBtn;
}

- (void)setupDownButton {
    // 重新录制
    UIButton *repeatRecordBtn = [UIButton new];
    [self.view addSubview:repeatRecordBtn];
    [repeatRecordBtn setImage:[UIImage imageNamed:@"repeatVideoImage"] forState:UIControlStateNormal];
    repeatRecordBtn.hidden = YES;
    [repeatRecordBtn addTarget:self action:@selector(repeatRecordVideo) forControlEvents:UIControlEventTouchUpInside];
    
    [repeatRecordBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.offset(0);
        make.bottom.offset(-40);
    }];
    
    // 发送视频
    UIButton *sendVideoBtn = [UIButton new];
    [self.view addSubview:sendVideoBtn];
    [sendVideoBtn setImage:[UIImage imageNamed:@"sendVideoImage"] forState:UIControlStateNormal];
    sendVideoBtn.hidden = YES;
    [sendVideoBtn addTarget:self action:@selector(sendVideo) forControlEvents:UIControlEventTouchUpInside];
    
    [sendVideoBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.bottom.equalTo(repeatRecordBtn);
    }];
    
    [self.view layoutIfNeeded];
    
    _repeatRecordBtn = repeatRecordBtn;
    _sendVideoBtn = sendVideoBtn;
}

- (void)setupVideotapButton {
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleExtraLight];
    UIVisualEffectView *effectView = [[UIVisualEffectView alloc] initWithEffect:effect];
    [self.view addSubview:effectView];
    effectView.userInteractionEnabled = YES;
    
    [effectView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.offset(-15.0);
        make.centerX.offset(0);
        make.size.mas_equalTo(CGSizeMake(_recordBtnWidth, _recordBtnWidth));
    }];
    
    UIButton *btn = [UIButton new];
    [effectView addSubview:btn];
    [btn addTarget:self action:@selector(takeMovie:) forControlEvents:UIControlEventTouchDown];
    [btn addTarget:self action:@selector(finishMovie:) forControlEvents:UIControlEventTouchUpInside];
    
    [btn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.offset(0);
    }];
    
    
    CAShapeLayer *maskLayer = [CAShapeLayer new];
    _beginRect = CGRectMake(23.5, 23.5, 70, 70);
    _beginPath = [UIBezierPath bezierPathWithOvalInRect:_beginRect];
    maskLayer.path = _beginPath.CGPath;
    effectView.layer.mask = maskLayer;
    
    CAShapeLayer *smallCircleLayer = [CAShapeLayer new];
    smallCircleLayer.path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(33.5, 33.5, 50, 50)].CGPath;
    smallCircleLayer.fillColor = [UIColor whiteColor].CGColor;
    [btn.layer addSublayer:smallCircleLayer];
    
    _maskLayer = maskLayer;
    _recordBtn = btn;
    _effectView = effectView;
}

- (void)setupVideoSessionUI {
    // 1. 创建拍摄会话
    _captureSession = [AVCaptureSession new];
    if (([_captureSession canSetSessionPreset:AVCaptureSessionPreset640x480])) {
        [_captureSession setSessionPreset:AVCaptureSessionPresetMedium];
    }
    SOLog(@"%@",_captureSession.sessionPreset);
    // 2. 创建输入设备
    self.cameraPosition = AVCaptureDevicePositionBack;
    AVCaptureDevice *videoCaptureDevice = [self getCameraDeviceWithPosition:self.cameraPosition];
    if (videoCaptureDevice == nil) {
        SOLog(@"--- 无法取得后置摄像头 ---");
        return;
    }
    AVCaptureDevice *audioCaptureDevice = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    
    // 3. 创建输入对象
    NSError *error;
    _videoCaptureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:videoCaptureDevice error:&error];
    if (error) {
        SOLog(@"---- 取得设备输入对象时出错 ------ %@",error);
        return;
    }
    
    if ([_captureSession canAddInput:_videoCaptureDeviceInput]) {
        [_captureSession addInput:_videoCaptureDeviceInput];
    }
    
    error = nil;
    _audioCaptureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:audioCaptureDevice error:&error];
    if (error) {
        SOLog(@"取得设备输入对象时出错 ------ %@",error);
        return;
    }
    
    if ([_captureSession canAddInput:_audioCaptureDeviceInput]) {
        [_captureSession addInput:_audioCaptureDeviceInput];
        AVCaptureConnection *captureConnection = [_captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        captureConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeAuto;
    }
    
    // 4. 初始化输出数据管理对象
    _captureMovieFileOutput = [AVCaptureMovieFileOutput new];
    
    if ([_captureSession canAddOutput:_captureMovieFileOutput]) {
        [_captureSession addOutput:_captureMovieFileOutput];
    }
    
    // 5. 创建预览图层
    _captureVideoPreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:_captureSession];
    _captureVideoPreviewLayer.frame = self.view.layer.bounds;
    _captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _captureVideoPreviewLayer.masksToBounds = YES;
    [self.view.layer addSublayer:_captureVideoPreviewLayer];
    [_captureSession startRunning];
}

- (CAShapeLayer *)animateShapLayer {
    if (_animateShapLayer == nil) {
        _animateShapLayer = [CAShapeLayer layer];
        _animateShapLayer.frame = self.recordBtn.bounds;
        UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(_recordBtnWidth * 0.5, _recordBtnWidth * 0.5) radius:_recordBtnWidth / 2 - 1.5 startAngle:-M_PI_2 endAngle:M_PI * 1.5 clockwise:YES];
        _animateShapLayer.path = path.CGPath;
        _animateShapLayer.lineCap = kCALineCapSquare;
        _animateShapLayer.fillColor = [UIColor clearColor].CGColor;
        _animateShapLayer.lineWidth = 3;
        _animateShapLayer.strokeColor = [UIColor colorWithHexString:@"#FF8903"].CGColor;
    }
    return _animateShapLayer;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    SOLog(@"控制器释放了");
}

@end
