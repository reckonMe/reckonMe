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

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVAudioSession.h>
#import <Accelerate/Accelerate.h>

typedef unsigned char audioChannel;

#define kNumChannels 6

@class SoundDetector;
@protocol SoundDetectorDelegate

-(void)soundDetector:(SoundDetector *)detector didDetectSoundOnChannel:(audioChannel)channel withAverageVolume:(float)avgVolume;

@end

@interface SoundDetector : NSObject <AVAudioSessionDelegate> {
    

}

//singleton
+(SoundDetector *)sharedInstance;

@property(nonatomic, assign) id<SoundDetectorDelegate>delegate;

@property(nonatomic, getter = isDetecting) BOOL detecting;
@property(nonatomic, getter = isEmitting) BOOL emitting;

@property(nonatomic, retain) NSString *audioFileName;

-(BOOL)isDetectionAvailable;

//Emission and detection are mutually exclusive!
-(void)startEmissionOnChannel:(audioChannel)channel;
-(void)stopEmission;

-(void)startDetection;
-(void)listenForChannel:(audioChannel)channel;
-(void)stopListeningForChannel:(audioChannel)channel;
-(void)stopDetection;

//stops both
-(void)stop;

@end