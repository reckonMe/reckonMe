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

#import "Settings.h"

const int kMinDistBetweenMeetings = 10;
const int kMaxDistBetweenMeetings = 200;
const int kDistBetweenMeetingsStepValue = 10;
const int kDefaultDistBetweenMeetings = 10;

const double kMinStepLength = 0.5;
const double kMaxStepLength = 1.0;
const double kStepLengthStepValue = 0.05;
const double kDefaultStepLength = 0.8;

const BOOL kDefaultExchangeEnabled = YES;
const BOOL kDefaultBeaconMode = NO;
const BOOL kDefaultShowSatelliteImagery = NO;
const NSInteger kDefaultRSSI = -70;

NSString* const kDistanceKey = @"distBetweenEx"; 
NSString* const kStepLengthKey = @"stepLength";
NSString* const kBeaconModeKey = @"beaconMode";
NSString* const kExchangeEnabledKey = @"exchangeEnabled";
NSString* const kRSSIKey = @"RSSI";
NSString* const kSatelliteImageryKey = @"satelliteImagery";

@implementation Settings

@dynamic stepLength;
@dynamic distanceBetweenConsecutiveMeetings;
@dynamic beaconMode;
@dynamic exchangeEnabled;
@dynamic rssi;
@dynamic showSatelliteImagery;

+(Settings *)sharedInstance {
    
    static Settings *sharedSingleton;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        sharedSingleton = [[Settings alloc] init];
    });
    
    return sharedSingleton;
}

-(id)init {
    
    if (self = [super init]) {
        
        NSDictionary *defaults = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSNumber numberWithInt:kDefaultDistBetweenMeetings], kDistanceKey, 
                                  [NSNumber numberWithDouble:kDefaultStepLength], kStepLengthKey,
                                  [NSNumber numberWithBool:kDefaultBeaconMode], kBeaconModeKey,
                                  [NSNumber numberWithBool:kDefaultExchangeEnabled], kExchangeEnabledKey,
                                  [NSNumber numberWithBool:kDefaultShowSatelliteImagery], kSatelliteImageryKey,
                                  [NSNumber numberWithInt:kDefaultRSSI], kRSSIKey,
                                  nil];
        
    	[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
        
    }
    
    return self;
}


-(double)stepLength {

    return [[NSUserDefaults standardUserDefaults] doubleForKey:kStepLengthKey];
}

-(void)setStepLength:(double)stepLength {
    
    if (   stepLength <= kMaxStepLength
        && stepLength >= kMinStepLength) {
        
        [[NSUserDefaults standardUserDefaults] setDouble:stepLength
                                                  forKey:kStepLengthKey];
    }
}

-(NSInteger)distanceBetweenConsecutiveMeetings {
    
    return [[NSUserDefaults standardUserDefaults] integerForKey:kDistanceKey];
}

-(void)setDistanceBetweenConsecutiveMeetings:(NSInteger)distanceBetweenConsecutiveMeetings {
    
    if (   distanceBetweenConsecutiveMeetings >= kMinDistBetweenMeetings
        && distanceBetweenConsecutiveMeetings <= kMaxDistBetweenMeetings) {
        
        [[NSUserDefaults standardUserDefaults] setInteger:distanceBetweenConsecutiveMeetings
                                                   forKey:kDistanceKey];
    }
}

-(void)setShowSatelliteImagery:(BOOL)showSatelliteImagery {
    
    [[NSUserDefaults standardUserDefaults] setBool:showSatelliteImagery
                                            forKey:kSatelliteImageryKey];
}

-(BOOL)showSatelliteImagery {
    
    return [[NSUserDefaults standardUserDefaults] boolForKey:kSatelliteImageryKey];
}

-(void)setBeaconMode:(BOOL)beaconMode {
    
    [[NSUserDefaults standardUserDefaults] setBool:beaconMode
                                            forKey:kBeaconModeKey];
}

-(BOOL)beaconMode {
    
    return [[NSUserDefaults standardUserDefaults] boolForKey:kBeaconModeKey];
}

-(void)setExchangeEnabled:(BOOL)exchangeEnabled {
    
    [[NSUserDefaults standardUserDefaults] setBool:exchangeEnabled
                                            forKey:kExchangeEnabledKey];
}

-(BOOL)exchangeEnabled {
    
    return [[NSUserDefaults standardUserDefaults] boolForKey:kExchangeEnabledKey];
}

-(void)setRssi:(NSInteger)rssi {
    
    [[NSUserDefaults standardUserDefaults] setInteger:rssi
                                               forKey:kRSSIKey];
}

-(NSInteger)rssi {
    
    return [[NSUserDefaults standardUserDefaults] integerForKey:kRSSIKey];
}

@end
