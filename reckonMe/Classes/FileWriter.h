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
#import "PDRExchange.h"

#define PRODUCT_NAME @"reckonMe"

extern NSString* const kAccelerometerFileAppendix;
extern NSString* const kGyroscopeFileAppendix;
extern NSString* const kCompassFileAppendix;
extern NSString* const kGpsFileAppendix;

extern NSString *const kPdrPositionFileAppendix;
extern NSString *const kPdrCollaborativeTraceFileAppendix;
extern NSString *const kPdrManualPositionCorrectionFileAppendix;
extern NSString *const kPdrCollaborativePositionCorrectionUpdateFileAppendix;
extern NSString *const kPdrConnectionQueryFileAppendix;

@interface FileWriter : NSObject <SensorListener, PDRLogger> {
    
    BOOL isRecording;

    //indicate whether the created files have actually been used
    BOOL usedAccelerometer;
	BOOL usedGPS;
	BOOL usedGyro;
	BOOL usedSound;
	BOOL usedCompass;
    
    NSInteger completePathCounter;
    
    NSFileManager *fileManager;
	
    //text files
	FILE *accelerometerFile;
	FILE *gpsFile;
	FILE *gyroFile;
	FILE *compassFile;
    
    FILE *pdrPositionFile;
    FILE *pdrCollaborativeTraceFile;
    FILE *pdrManualPositionCorrectionFile;
    FILE *pdrManualHeadingCorrectionFile;
    FILE *pdrCollaborativePositionCorrectionUpdateFile;
    FILE *pdrConnectionQueryFile;
    
    NSString *currentFilePrefix;
    NSString *currentRecordingDirectory;
	NSString *accelerometerFileName;
	NSString *gpsFileName;
	NSString *gyroFileName;
	NSString *compassFileName;
    
    NSString *pdrPositionFileName;
    NSString *pdrCollaborativeTraceFileName;
    NSString *pdrManualPositionCorrectionFileName;
    NSString *pdrCollaborativePositionCorrectionUpdateFileName;
    NSString *pdrConnectionQueryFileName;
    
}

@property(nonatomic, readonly) BOOL isRecording;
@property(nonatomic, retain) NSString *currentFilePrefix;

-(void)startRecording;
-(void)stopRecording;


@end
