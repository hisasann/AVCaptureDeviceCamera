//
//  ViewController.m
//  AVCaptureDeviceCamera
//
//  Created by hisasann on 12/09/11.
//  Copyright (c) 2012年 hisasann. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "ViewController.h"

#define FOCUS_LAYER_RECT_SIZE 73.0

@interface ViewController () {
    // require AVFoundation.framework
    // via https://developer.apple.com/library/mac/#documentation/AVFoundation/Reference/AVCaptureSession_Class/Reference/Reference.html
    AVCaptureSession *_session;
    AVCaptureStillImageOutput *_dataOutput;
    AVCaptureVideoDataOutput *_dataOutputVideo;

    CIContext *_ciContext;

    UIView *_focusView;

    NSInteger _layerHideCounter;

    BOOL _isShowFlash;
}

@property(weak, nonatomic) IBOutlet UIButton *albumButton;
@property(weak, nonatomic) IBOutlet UIButton *captureButton;
@property(weak, nonatomic) IBOutlet UIButton *closeButton;
@property(weak, nonatomic) IBOutlet UIButton *cameraPositionChangeButton;
@property(weak, nonatomic) IBOutlet UIButton *flashButton;
@property(weak, nonatomic) IBOutlet UIImageView *previewImage;
@property(weak, nonatomic) IBOutlet UIView *touchView;
@property (weak, nonatomic) IBOutlet UIImageView *confirmImage;

@property(nonatomic, strong) NSDictionary *exif;

- (IBAction)closeAction:(id)sender;

- (IBAction)cameraPositionChangeAction:(id)sender;

- (IBAction)flashAction:(id)sender;

- (IBAction)captureAction:(id)sender;

- (IBAction)showAlbumAction:(id)sender;

@end

@implementation ViewController
@synthesize albumButton;
@synthesize captureButton;
@synthesize closeButton;
@synthesize cameraPositionChangeButton;
@synthesize flashButton;
@synthesize previewImage;
@synthesize touchView;
@synthesize confirmImage;

@synthesize exif = _exif;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    // require CoreImage.framework
    // http://developer.apple.com/library/mac/#documentation/graphicsimaging/reference/QuartzCoreFramework/Classes/CIContext_Class/Reference/Reference.html
    _ciContext = [CIContext contextWithOptions:nil];

    // ビデオキャプチャデバイスの取得
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    // デバイス入力の取得 - input
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:NULL];

    // フラッシュをオフ
    NSError *error = nil;
    if ([device lockForConfiguration:&error]) {
        if ([device isFlashModeSupported:AVCaptureFlashModeOff]) {
            device.flashMode = AVCaptureFlashModeOff;
        }

        [device unlockForConfiguration];
    }

    // via http://berrytomato.blogspot.jp/2010/10/avfoundation.html
    // イメージデータ出力の作成 - output
    _dataOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:
            AVVideoCodecJPEG, AVVideoCodecKey, nil];
    _dataOutput.outputSettings = outputSettings;

    // ビデオデータ出力の作成 - output
    NSMutableDictionary *settings;
    settings = [NSMutableDictionary dictionary];
    [settings setObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA]
                 forKey:(__bridge id) kCVPixelBufferPixelFormatTypeKey];
    _dataOutputVideo = [[AVCaptureVideoDataOutput alloc] init];
    _dataOutputVideo.videoSettings = settings;
    [_dataOutputVideo setSampleBufferDelegate:self queue:dispatch_get_main_queue()];

    // セッションの作成
    _session = [[AVCaptureSession alloc] init];
    [_session addInput:deviceInput];
    [_session addOutput:_dataOutput];
    [_session addOutput:_dataOutputVideo];
    // ここ重要、AVCaptureSessionPreset1280x720だとフロントカメラで落ちる
    // via http://news.mynavi.jp/column/iphone/041/index.html
    _session.sessionPreset = AVCaptureSessionPresetPhoto;

    // add gesture
    UIGestureRecognizer *gr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapGesture:)];
    gr.delegate = self;
    [self.touchView addGestureRecognizer:gr];

    // フォーカスしたときの枠
    _focusView = [[UIView alloc] init];
    CGRect imageFrame = _focusView.frame;
    imageFrame.size.width = FOCUS_LAYER_RECT_SIZE;
    imageFrame.size.height = FOCUS_LAYER_RECT_SIZE;
    _focusView.frame = imageFrame;
    _focusView.center = CGPointMake(160, 202);
    CALayer *layer = _focusView.layer;
    layer.shadowOffset = CGSizeMake(2.5, 2.5);
    layer.shadowColor = [[UIColor blackColor] CGColor];
    layer.shadowOpacity = 0.5;
    layer.borderWidth = 2;
    layer.borderColor = [UIColor yellowColor].CGColor;
    [self.touchView addSubview:_focusView];
    _focusView.alpha = 0;

    // フラッシュしない
    _isShowFlash = NO;

    // タッチビューを前面に持ってくる
    [self.view bringSubviewToFront:self.touchView];

    // フッターを前面に持ってくる
    UIView *footerView = [self.view viewWithTag:2];
    [self.view bringSubviewToFront:footerView];
}

- (void)viewDidUnload {
    [self setAlbumButton:nil];
    [self setCaptureButton:nil];
    [self setCloseButton:nil];
    [self setCameraPositionChangeButton:nil];
    [self setFlashButton:nil];
    [self setPreviewImage:nil];
    [self setTouchView:nil];
    [self setConfirmImage:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.

    _ciContext = nil;
    _session = nil;
    _dataOutput = nil;
    _dataOutputVideo = nil;
    _focusView = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // セッションの開始
    [_session startRunning];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    [_session stopRunning];
}

#pragma mark - delegate

- (void)didTapGesture:(UITapGestureRecognizer *)tgr {
    _layerHideCounter++;

    CGPoint point = [tgr locationInView:tgr.view];

    [_focusView.layer removeAllAnimations];

    _focusView.alpha = 0.1;
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.2];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
    [UIView setAnimationDidStopSelector:@selector(startupAnimationDone)];
    _focusView.alpha = 1;
    _focusView.frame = CGRectMake(point.x - FOCUS_LAYER_RECT_SIZE / 2.0,
            point.y - FOCUS_LAYER_RECT_SIZE / 2.0,
            FOCUS_LAYER_RECT_SIZE,
            FOCUS_LAYER_RECT_SIZE);
    [self setPoint:point];
    [UIView commitAnimations];
}

- (void)startupAnimationDone {
    if (_layerHideCounter > 1) {
        _layerHideCounter--;
        return;
    }

    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
    _focusView.alpha = 0;
    [UIView commitAnimations];

    _layerHideCounter--;
}

// ここでtouchしたのがViewなのかUIControlなのか判定している
// これをしないとUIViewに配置したUIButtonなどが反応しなくなる
// via http://stackoverflow.com/questions/3344341/uibutton-inside-a-view-that-has-a-uitapgesturerecognizer
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // via http://stackoverflow.com/questions/3344341/uibutton-inside-a-view-that-has-a-uitapgesturerecognizer
    if ([touch.view isKindOfClass:[UIControl class]]) {
        // we touched a button, slider, or other UIControl
        return NO; // ignore the touch
    }
    return YES; // handle the touch
}

#pragma mark - Method

// AVCaptureStillImageOutputで呼ばれる
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    // require CoreVideo.framework and CoreMedia.framework
    // via http://stackoverflow.com/questions/3393239/why-wont-avfoundation-link-with-my-xcode-3-2-3-iphone-4-0-1-project
    // イメージバッファの取得
    CVImageBufferRef buffer = CMSampleBufferGetImageBuffer(sampleBuffer);

    // イメージバッファのロック
    CVPixelBufferLockBaseAddress(buffer, 0);

    // イメージバッファ情報の取得
    uint8_t *base = CVPixelBufferGetBaseAddress(buffer);
    size_t width = CVPixelBufferGetWidth(buffer);
    size_t height = CVPixelBufferGetHeight(buffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(buffer);

    // ビットマップコンテキストの作成
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef cgContext = CGBitmapContextCreate(
            base, width, height, 8, bytesPerRow, colorSpace,
            kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);

    // 画像の作成
    CGImageRef cgImage = CGBitmapContextCreateImage(cgContext);

    // 反転させる
    UIImage *uiImage = [UIImage imageWithCGImage:cgImage scale:1.0f orientation:UIImageOrientationRight];

    // イメージバッファのアンロック
    CVPixelBufferUnlockBaseAddress(buffer, 0);

    // 画像の表示
    self.previewImage.image = uiImage;

    CGColorSpaceRelease(colorSpace);
    CGImageRelease(cgImage);
    CGContextRelease(cgContext);
}

- (void)setPoint:(CGPoint)point {
    CGSize viewSize = self.view.bounds.size;
    CGPoint pointOfInterest = CGPointMake(point.y / viewSize.height,
            1.0 - point.x / viewSize.width);

    AVCaptureDevice *captureDevice =
            [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    NSError *error = nil;
    if ([captureDevice lockForConfiguration:&error]) {
        if ([captureDevice isFocusPointOfInterestSupported] &&
                [captureDevice isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            captureDevice.focusPointOfInterest = pointOfInterest;
            captureDevice.focusMode = AVCaptureFocusModeAutoFocus;
        }

        if ([captureDevice isExposurePointOfInterestSupported] &&
                [captureDevice isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
            captureDevice.exposurePointOfInterest = pointOfInterest;
            captureDevice.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
        }

        [captureDevice unlockForConfiguration];
    }
}

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }
    return nil;
}

- (void)swapFrontAndBackCameras {
    NSLog(@"swapFrontAndBackCameras");
    // Assume the session is already running

    NSArray *inputs = _session.inputs;
    for (AVCaptureDeviceInput *input in inputs) {
        AVCaptureDevice *device = input.device;

        if ([device hasMediaType :AVMediaTypeVideo]) {
            AVCaptureDevicePosition position = device.position;
            AVCaptureDevice *newCamera;
            AVCaptureDeviceInput *newInput;

            if (position == AVCaptureDevicePositionFront) {
                newCamera = [self cameraWithPosition:AVCaptureDevicePositionBack];
                newInput = [AVCaptureDeviceInput deviceInputWithDevice:newCamera error:nil];
                self.flashButton.hidden = NO;
            } else {
                newCamera = [self cameraWithPosition:AVCaptureDevicePositionFront];
                newInput = [AVCaptureDeviceInput deviceInputWithDevice:newCamera error:nil];
                self.flashButton.hidden = YES;
            }

            // beginConfiguration ensures that pending changes are not applied immediately
            [_session beginConfiguration];

            [_session removeInput :input];
            [_session addInput :newInput];

            // Changes take effect once the outermost commitConfiguration is invoked.
            [_session commitConfiguration];
            break;
        }
    }
}

- (void)showCameraConfirmView:(UIImage *)image isAlbum:(BOOL)isAlbum exif:(NSDictionary *)exif {
    // 確認画面を開く
    self.confirmImage.image = image;
}

#pragma mark - delegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo {
    UIImage *editedImage = [editingInfo objectForKey:UIImagePickerControllerEditedImage];
    UIImage *originalImage = [editingInfo objectForKey:UIImagePickerControllerOriginalImage];

    __weak ViewController *__self = self;
    NSURL *assetURL = [editingInfo objectForKey:UIImagePickerControllerReferenceURL];
    // require AssetsLibrary.framework
    // via http://developer.apple.com/library/ios/#DOCUMENTATION/AssetsLibrary/Reference/ALAssetsLibrary_Class/Reference/Reference.html
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library assetForURL:assetURL
            resultBlock:^(ALAsset *asset) {
                ALAssetRepresentation *representation = [asset defaultRepresentation];
                NSDictionary *metadataDict = [representation metadata]; // ←ここにExifとかGPSの情報が入ってる
                __self.exif = [metadataDict objectForKey:@"{Exif}"];

                // イメージピッカーを隠す
                [__self dismissModalViewControllerAnimated:NO];

                // ここでプレビュー画面を開く
                [__self showCameraConfirmView:image isAlbum:YES exif:__self.exif];
            } failureBlock:^(NSError *error) {
        // エラーの場合はExifは無視する
        __self.exif = nil;

        // イメージピッカーを隠す
        [__self dismissModalViewControllerAnimated:NO];

        // ここでプレビュー画面を開く
        [__self showCameraConfirmView:image isAlbum:YES exif:__self.exif];
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissModalViewControllerAnimated:YES];
}

- (IBAction)closeAction:(id)sender {
    UIAlertView *alert = [[UIAlertView alloc]
            initWithTitle:@"閉じる" message:@"クローズ処理だよ" delegate:self
        cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];

    [alert show];
}

- (IBAction)cameraPositionChangeAction:(id)sender {
    NSLog(@"cameraPositionChangeAction");
    [self swapFrontAndBackCameras];
}

- (IBAction)flashAction:(id)sender {
    NSLog(@"flashAction");
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

    NSError *error = nil;
    if ([captureDevice lockForConfiguration:&error]) {
        // ライト
        if (_isShowFlash) {
            if ([captureDevice isFlashModeSupported:AVCaptureFlashModeOff]) {
                captureDevice.flashMode = AVCaptureFlashModeOff;
            }

            // 画像を切替えるなどの処理

            [sender setSelected:NO];

            _isShowFlash = NO;
        } else {
            if ([captureDevice isFlashModeSupported:AVCaptureFlashModeAuto]) {
                captureDevice.flashMode = AVCaptureFlashModeAuto;
                captureDevice.torchMode = AVCaptureTorchModeAuto;
            }

            // 画像を切替えるなどの処理

            [sender setSelected:YES];

            _isShowFlash = YES;
        }

        [captureDevice unlockForConfiguration];
    }
}

- (IBAction)showAlbumAction:(id)sender {
    UIImagePickerController *album = [[UIImagePickerController alloc] init];
    UIImagePickerControllerSourceType sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    album.sourceType = sourceType;
    album.allowsEditing = YES;
    album.wantsFullScreenLayout = YES;
    album.navigationBar.barStyle = UIBarStyleBlackOpaque;
    album.navigationBar.tintColor = [UIColor colorWithRed:(255 / 255.f) green:(51 / 255.f) blue:(153 / 255.f) alpha:1.0f];
    album.delegate = self;

    [self presentModalViewController:album animated:YES];
}

- (IBAction)captureAction:(id)sender {
    // コネクションを検索
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in _dataOutput.connections) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection)
            break;
    }

    __weak ViewController *__self = self;
    // 静止画をキャプチャする
    [_dataOutput captureStillImageAsynchronouslyFromConnection:videoConnection
                                             completionHandler:
                                                     ^(CMSampleBufferRef imageSampleBuffer, NSError *error) {
                                                         if (imageSampleBuffer == NULL) {
                                                             return;
                                                         }

                                                         // キャプチャしたデータを取る
                                                         NSData *data = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];

                                                         // 押されたボタンにキャプチャした静止画を設定する
                                                         UIImage *originalImage = [[UIImage alloc] initWithData:data];

                                                         // 反転させる
                                                         UIImage *uiImage = [UIImage imageWithCGImage:originalImage.CGImage scale:1.0f orientation:UIImageOrientationRight];

                                                         // ここでプレビュー画面を開く
                                                         [__self showCameraConfirmView:uiImage isAlbum:NO exif:nil];
                                                     }];
}

@end
