/**
*	The BSD 2-Clause License (aka "FreeBSD License")
*
*	Copyright (c) 2012, Benjamin Thiel, Kamil Kloch
*	All rights reserved.
*
*	Redistribution and use in source and binary forms, with or without
*	modification, are permitted provided that the following conditions are met: 
*
*	1. Redistributions of source code must retain the above copyright notice, this
*	   list of conditions and the following disclaimer. 
*	2. Redistributions in binary form must reproduce the above copyright notice,
*	   this list of conditions and the following disclaimer in the documentation
*	   and/or other materials provided with the distribution. 
*
*	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
*	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
*	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
*	DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
*	ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
*	(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
*	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
*	ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
*	(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
*	SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**/

#import "PantsPocketDetector.h"
#define PANTS_DETECTOR_USE_ONLY_CAM

typedef enum {
    
    Off,
    NotProximate,
    ProximateAndWaitingForDarkness,
    ProximateAndDark
    
} PocketDetectorStatus;

typedef enum {
    
    Start,
    Stop,
    BecameProximate,
    BecameNotProximate,
    BecameDark
    
} PocketDetectorEvent;

@interface PantsPocketDetector ()

@property(nonatomic) PocketDetectorStatus status;

-(void)didReceiveEvent:(PocketDetectorEvent)event;

-(void)proximitySensorStateChanged;
-(void)startCapturing;
-(void)stopCapturing;

@end

@implementation PantsPocketDetector

@synthesize isCameraAvailable, delegate, status;
@dynamic isStarted, isInPocket;

-(id)init {
    
    if (self = [super init]) {
        
        delegate = nil;
        isCameraAvailable = NO;
        self.status = Off;
        
        frameCounter = 0;
        
        captureSession = [[AVCaptureSession alloc] init];
        videoOut = [[AVCaptureVideoDataOutput alloc] init];
        captureQueue = dispatch_queue_create("PantsPocketDetector's video capture queue", DISPATCH_QUEUE_SERIAL);
        
        //set the color model to YpCbCr, in which we get lumninance (read: brightness) for "free" with the Y channel
        videoOut.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
                                                             forKey:(NSString *)kCVPixelBufferPixelFormatTypeKey];
        
        
        if ([captureSession canSetSessionPreset:AVCaptureSessionPreset352x288]) {
            
            captureSession.sessionPreset = AVCaptureSessionPreset352x288;//lowest possible resolution
        }
        
        //look for the camera at the back...
        for (AVCaptureDevice *device in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
            
            NSError *error = nil;
            AVCaptureDeviceInput *deviceInput = nil;
            
            deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device
                                                                error:&error];
            
            if (deviceInput 
                && !error 
                && [captureSession canAddInput:deviceInput]
                && (device.position == AVCaptureDevicePositionFront)) {
                
                [captureSession addInput:deviceInput];//...and add it to the session

                /* if you want to fumble with that, go ahead: (Ben suggests not to! ;) )
                if ([device lockForConfiguration:nil]) {
                    
                    NSLog(@"camera exposure before: %d, whitebal: %d", device.exposureMode, device.whiteBalanceMode);
                    device.exposureMode = AVCaptureExposureModeLocked;
                    device.whiteBalanceMode = AVCaptureWhiteBalanceModeLocked;
                    [device unlockForConfiguration];
                    NSLog(@"camera exposure after: %d, whitebal: %d", device.exposureMode, device.whiteBalanceMode);
                }*/
                
                if ([captureSession canAddOutput:videoOut]) {
                    
                    [captureSession addOutput:videoOut];
                    videoOut.alwaysDiscardsLateVideoFrames = YES;//we don't need all frames
                    [videoOut setSampleBufferDelegate:self
                                                queue:captureQueue];
                    
                    //now we've successfully added the camera and the image output to the session,
                    //they're connected automatically be the session
                    isCameraAvailable = YES;
                }
            }
        }
        
        //listen for proximity sensor
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(proximitySensorStateChanged) 
                                                     name:@"UIDeviceProximityStateDidChangeNotification" 
                                                   object:nil];
    }
    
    return self;
}

-(void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stop];
    
    [captureSession release];
    [videoOut release];
    dispatch_release(captureQueue);
    
    [super dealloc];
}

-(BOOL)isStarted {
    
    return (self.status != Off);
}

-(BOOL)isInPocket {
    
    if (isCameraAvailable) {
        
        return (self.status == ProximateAndDark);
   
    } else {
        
        //use only the proximity sensor to determine the status if no camera is available
        return (self.status == ProximateAndWaitingForDarkness);
    }
}

//MARK: -
-(void)start {
    
    [self didReceiveEvent:Start];
}

-(void)stop {
    
    [self didReceiveEvent:Stop];
}

//MARK: - logic (finite state machine)
-(void)didReceiveEvent:(PocketDetectorEvent)event {
    
    //this method may be called from several threads, but setting the status is critical, hence the mutex
    @synchronized(self) {
        
#ifdef PANTS_DETECTOR_USE_ONLY_CAM
        switch (event) {
                
            case Start:
                
                switch (self.status) {
                        
                    case Off:
                        [self startCapturing];
                        self.status = NotProximate;
                        break;
                        
                    default:
                        break;
                }
                break;
                
            case Stop:
                [self stopCapturing];
                self.status = Off;
                break;
                
            case BecameDark:
                if (   self.status != Off
                    && self.status != ProximateAndDark) {
                    
                    self.status = ProximateAndDark;
                    [self.delegate devicesPocketStatusChanged:YES];
                }
            default:
                break;
        }
#else
        switch (event) {
                
            case Start:
                
                switch (self.status) {
                        
                    case Off:
                        [UIDevice currentDevice].proximityMonitoringEnabled = YES;
                        //set the next status by querying the devices proximity status
                        [self proximitySensorStateChanged];
                        break;
                        
                    default:
                        break;
                }
                break;
                
                
            case Stop:
                
                switch (self.status) {
                        
                    case ProximateAndWaitingForDarkness:
                        [self stopCapturing];
                        //no break;
                    default:
                        //ATTENTION: The proximity will not turn itself off and unlock the screen, 
                        //until the object triggering is actually moving away.
                        //Another undocumented side-effect is the muting of the audio speaker.
                        [UIDevice currentDevice].proximityMonitoringEnabled = NO;
                        self.status = Off;
                        break;
                }
                break;
                
                
            case BecameProximate:
                
                switch (self.status) {
                        
                    case Off:
                    case NotProximate:
                        
                        if (isCameraAvailable) {
                            
                            [self startCapturing];
                        
                        } else {
                            
                            [self.delegate devicesPocketStatusChanged:YES];
                        }
                        self.status = ProximateAndWaitingForDarkness;
                        break;
                        
                    default:
                        break;
                }
                break;
                
                
            case BecameNotProximate:
                
                switch (self.status) {
                        
                    case ProximateAndWaitingForDarkness:
                        
                        if (isCameraAvailable) {
                            
                            [self stopCapturing];
                        
                        } else {
                            
                            [self.delegate devicesPocketStatusChanged:NO];
                        }
                        break;
                    
                    case ProximateAndDark:
                        self.status = NotProximate;
                        [self.delegate devicesPocketStatusChanged:NO];
                        break;
                        
                    default:
                        break;
                }
                self.status = NotProximate;
                break;
                
                
            case BecameDark:
                
                switch (self.status) {
                        
                    case ProximateAndWaitingForDarkness:
                        [self stopCapturing];
                        self.status = ProximateAndDark;
                        [self.delegate devicesPocketStatusChanged:YES];
                        break;
                        
                    default:
                        break;
                }
                break;
                
            default:
                break;
        }
#endif
    }
}

//MARK: - capturing
-(void)startCapturing {
    
    frameCounter = 0;
    [captureSession startRunning];
}

-(void)stopCapturing {
    
    [captureSession stopRunning];   
}

//MARK: - sensor callbacks
-(void)proximitySensorStateChanged {
    
    if ([UIDevice currentDevice].proximityState) {
        
        [self didReceiveEvent:BecameProximate];
        
    } else {
        
        [self didReceiveEvent:BecameNotProximate];
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    
    if (++frameCounter % (30 * kPantsPocketDetectorCaptureInterval) == 0) {//assuming 30fps due to lack of other information
        
        // Get a CMSampleBuffer's Core Video image buffer for the media data
        CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer); 
        // Lock the base address of the pixel buffer, necessary for subsequent calls to CVPixelBufferGet...
        CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly); 
        
        size_t yPlaneIndex = 0;//hopefully the right index (undocumented!) for the Y-plane (Y = luminance in YCbCr color model)
        size_t bytesPerRowOfYPlane = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, yPlaneIndex);
        size_t heightOfYPlane = CVPixelBufferGetHeightOfPlane(imageBuffer, yPlaneIndex);
        
        unsigned char* pixelsOfYPlane = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, yPlaneIndex);
        
        //compute the average luminance
        double luminanceSum = 0;
        size_t totalBytes = heightOfYPlane * bytesPerRowOfYPlane;
        
        for (size_t i = 0; i < totalBytes; i++) {
            
            luminanceSum += pixelsOfYPlane[i];
        }
        
        double averageLuminance = luminanceSum / totalBytes;
        
        //compute the standard deviation
        double sumOfSquaredDifferences = 0;
        for (size_t i = 0; i < totalBytes; i++) {
            
            double difference = (pixelsOfYPlane[i] - averageLuminance) / UCHAR_MAX;
            sumOfSquaredDifferences += difference * difference;
        }              
        
        //we're done with the image -> unlock the pixel buffer
        CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
        
        double standardDeviation = sqrt( sumOfSquaredDifferences / (totalBytes - 1) );
        averageLuminance /= UCHAR_MAX; 
        
        if (   (averageLuminance <= kPantsPocketDetectorLuminanceThreshold)
            && (standardDeviation <= kPantsPocketDetectorLuminanceStandardDeviationThreshold)) {
            
            [self didReceiveEvent:BecameDark];
        }
    }
}


@end
