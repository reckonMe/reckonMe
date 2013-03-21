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
#import <GameKit/GameKit.h>
#import "PacketEncoderDecoder.h"
#import "PDRExchange.h"
#import "SoundDetector.h"

@interface P2PestimateExchange : NSObject <GKSessionDelegate, UIAlertViewDelegate, SoundDetectorDelegate> {
	
	GKSession *p2pSession;
    SoundDetector *soundDetector;
    NSString *ownUniquePeerID;
    
    ConnectionState connectionState;
    
    NSMutableDictionary *displayNamesForUniquePeerIDs;
    NSMutableDictionary *exchangesPendingACKACK;
    NSMutableSet *exchangesPendingACK;
    
    NSMutableDictionary *timestampsOfLastSuccessfulExchanges;
    
    BOOL isStarted;
    BOOL shouldNagToTurnBluetoothOn;
    
    NSInteger soundHistogram[kNumChannels];
    double soundVolumes[kNumChannels];
    
    BOOL isBeacon;
    BOOL isWalker;
    audioChannel channel;
}

@property (assign) id<PDRControllerProtocol> delegate;

@property (nonatomic) BOOL proximityDetectionMode;
@property(nonatomic, retain) AbsoluteLocationEntry *beaconPosition;

//singleton
+ (P2PestimateExchange *) sharedInstance;

-(void)startBeaconModeAtPosition:(AbsoluteLocationEntry *)position;
-(void)startWalkerModeOnChannel:(audioChannel)channel;

-(void)stop;

-(NSString *)displayNameForUniquePeerID:(NSString *)peerID;

@end
