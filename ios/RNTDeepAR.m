//
//  RNTDeepAR.m
//  deeparRNExample
//
//  Created by Matej Trbara on 02/03/2020.
//  Copyright © 2020 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RNTDeepAR.h"
#import "React/UIView+React.h"
#import <DeepAR/CameraController.h>

@implementation RNTDeepAR {
  CGRect _frame;
  ARView* _arview;
  UIImageView* _backgroundView;
}


-(instancetype)init {
  if ((self = [super init])) {
    
    // Instantiate ARView and add it to view hierarchy.
    self.deepar = [[DeepAR alloc] init];

    [self.deepar setLicenseKey:@"license_here"];
    [self.deepar initialize];
    self.deepar.delegate = self;

    _arview = (ARView*)[self.deepar createARViewWithFrame:[UIScreen mainScreen].bounds];
    [self insertSubview:_arview atIndex:0];
    self.cameraController = [[CameraController alloc] init];
    self.cameraController.deepAR = self.deepar;

    [self.cameraController startCamera];

    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self  selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification  object:nil];
  }
  
  return self;
}

- (void)dealloc {
  [self.deepar shutdown];
}


-(void)switchCamera {
  if (_arview) {
    self.cameraController.position = self.cameraController.position == AVCaptureDevicePositionBack ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
    
    NSString* message;
    if (self.cameraController.position == AVCaptureDevicePositionBack) {
      message = @"back";
    } else {
      message = @"front";
    }
    self.onEventSent(@{ @"type": @"cameraSwitch", @"value": message});
  }
}

-(void)pause {
  
  if (_arview) {
    [_arview pause];
  }
}

-(void)resume {
  if (_arview) {
    [_arview resume];
  }
}

- (void)reactSetFrame:(CGRect)frame {
  [super reactSetFrame: frame];
  _frame = frame;
  [self setupDeepARViewFrame];
}


-(void)startRecording {
  if (self.flashOn && self.cameraController.position == AVCaptureDevicePositionBack) {
    Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
    if (captureDeviceClass != nil) {
      AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
      if ([device hasTorch] && [device hasFlash]){
        
        [device lockForConfiguration:nil];
        [device setTorchMode:AVCaptureTorchModeOn];
        [device setFlashMode:AVCaptureFlashModeOn];
        [device unlockForConfiguration];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.25 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
          if(self->_arview) {
            [self->_arview startVideoRecordingWithOutputWidth:self.frame.size.width*0.75 outputHeight:self.frame.size.height*0.75];
            //[self->_arview startRecordingWithScale:0.5];
          }
        });
      }
    }
  } else {
    if(_arview) {
      [self->_arview startVideoRecordingWithOutputWidth:self.frame.size.width*0.75 outputHeight:self.frame.size.height*0.75];
     //[_arview startRecordingWithScale:0.5];
    }
  }

}

-(void)finishRecording {
    [self.deepar finishVideoRecording];
}

-(void)takeScreenshot {
  [self.deepar takeScreenshot];
}

-(void)switchEffect:(NSString*)effect andSlot:(NSString*)slot {
  NSString* path = [[NSBundle mainBundle]  pathForResource:effect ofType:@""];
  [_arview switchEffectWithSlot:slot path:path];
}


#pragma mark - ARViewDelegate methods

// Called when the engine initialization is complete. Do not call ARView methods before initialization.
- (void)didInitialize {
  
  [self setupDeepARViewFrame];
}

-(void) setupDeepARViewFrame {
  if(_arview.initialized && !CGRectIsEmpty(_frame) &&
                            (_arview.frame.size.height != _frame.size.height ||
                             _arview.frame.size.width != _frame.size.width ||
                             _arview.frame.origin.x != _frame.origin.x ||
                             _arview.frame.origin.y != _frame.origin.y ) ) {
    [_arview setFrame:_frame];
                              
    //[_arview switchEffectWithSlot:@"watermark" path:[[NSBundle mainBundle]  pathForResource:@"watermark" ofType:@""]];
    self.onEventSent(@{ @"type": @"initialized", @"value": @""});
  }
}

// Called when the finished the preparing for video recording.
- (void)didFinishPreparingForVideoRecording {
  
}

// Called when the video recording is started.
- (void)didStartVideoRecording {
  self.onEventSent(@{ @"type": @"didStartVideoRecording", @"value": @""});
}

// Called when the video recording is finished and video file is saved.
- (void)didFinishVideoRecording:(NSString*)videoFilePath {
  self.onEventSent(@{ @"type": @"didFinishVideoRecording", @"value": videoFilePath});
}

// Called if there is error encountered while recording video
- (void)recordingFailedWithError:(NSError*)error {
  self.onEventSent(@{ @"type": @"recordingFailedWithError", @"value": [error description]});
}

// Called when screenshot is taken
- (void)didTakeScreenshot:(UIImage*)screenshot {
  
  // Turn of torch
  if (self.flashOn) {
    // check if flashlight available
    Class captureDeviceClass = NSClassFromString(@"AVCaptureDevice");
    if (captureDeviceClass != nil) {
      AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
      if ([device hasTorch] && [device hasFlash]){
        [device lockForConfiguration:nil];
        [device setTorchMode:AVCaptureTorchModeOff];
        [device setFlashMode:AVCaptureFlashModeOff];
        [device unlockForConfiguration];
      }
    }
  }
  
  NSData *data = UIImageJPEGRepresentation(screenshot, 1.0);
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory , NSUserDomainMask, YES) lastObject];
  NSString *fullPath = [cachesDir stringByAppendingPathComponent:@"temp_screenshot.jpg"];
  [fileManager createFileAtPath:fullPath contents:data attributes:nil];
  
  self.onEventSent(@{ @"type": @"screenshotTaken", @"value": fullPath});
  
}

//- (void) didSwitchEffect:(NSString *)slot {
//   self.onEventSent(@{ @"type": @"didSwitchEffect", @"value": slot});
//}

// Called when the face appears or disappears.
- (void)faceVisiblityDidChange:(BOOL)faceVisible {
  
}

-(void)imageVisibilityChanged:(BOOL)imageVisible {
  self.onEventSent(@{ @"type": @"imageVisibilityChanged", @"value": imageVisible ? @"true" : @"false" });
}

- (void)orientationChanged:(NSNotification *)notification {
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    if (orientation == UIInterfaceOrientationLandscapeLeft) {
        self.cameraController.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
    } else if (orientation == UIInterfaceOrientationLandscapeRight) {
        self.cameraController.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
    } else if (orientation == UIInterfaceOrientationPortrait) {
        self.cameraController.videoOrientation = AVCaptureVideoOrientationPortrait;
    } else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
        self.cameraController.videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
    }
}

@end

