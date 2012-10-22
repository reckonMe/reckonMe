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

#import "AlertSoundPlayer.h"
#import <AudioToolbox/AudioToolbox.h>


NSString* const startingSound = @"starting.aiff";
NSString* const pausingSound = @"pausing.aiff";
NSString* const calibrateSound = @"calibrate.aiff";
NSString* const exchangedPositionsSound = @"exchanged.aiff";
NSString* const goodbyeSound = @"goodbye.aiff";
NSString* const cymbalsSound = @"cymbalsShort.aiff";
//ATTENTION: When adding sound file names here, make sure to add
//them to the fileNames array in init


static AlertSoundPlayer *sharedSingleton;

@implementation AlertSoundPlayer

+ (void)initialize
{
	//is necessary, because +initialize may be called directly
    static BOOL initialized = NO;
    
	if(!initialized)
    {
        initialized = YES;
        sharedSingleton = [[AlertSoundPlayer alloc] init];
    }
}

+(AlertSoundPlayer*)sharedInstance {
    
    return sharedSingleton;
}

-(id)init {
    
    if (self = [super init]) {
        
        NSArray *fileNames = [NSArray arrayWithObjects:
                              startingSound,
                              pausingSound, 
                              calibrateSound,
                              exchangedPositionsSound,
                              goodbyeSound,
                              cymbalsSound,
                              nil];

        soundURLs = [[NSMutableArray alloc] init];
        soundIDs = [[NSMutableDictionary alloc] init];
        
        for (NSString *fileName in fileNames) {
            
            NSURL *soundURL = [[NSBundle mainBundle] URLForResource:fileName
                                                      withExtension:nil];
            
            //file found?
            if (soundURL) {
                
                //retain the URLs in the array, because AudioServices doesn't
                [soundURLs addObject:soundURL];
                
                SystemSoundID soundID;
                OSStatus error = 0;
                error = AudioServicesCreateSystemSoundID (
                                                          (CFURLRef) soundURL,
                                                          &soundID
                                                          );
                
                if (!error) {
                    
                    [soundIDs setValue:[NSNumber numberWithUnsignedInt:soundID]
                                forKey:fileName];   
                }
            }
        }
    }
    return self;
}

    
-(void)dealloc {
    
    for (NSNumber *soundID in soundIDs) {
        
        AudioServicesDisposeSystemSoundID([soundID unsignedIntValue]);
    }
    
    [soundIDs release];
    [soundURLs release];
    
    [super dealloc];
}

-(void)playSound:(NSString *)name vibrating:(BOOL)vibrating {
    
    if (name == nil && vibrating) {
        
        AudioServicesPlaySystemSound (kSystemSoundID_Vibrate);
    
    } else {
        
        SystemSoundID soundID = [[soundIDs objectForKey:name] unsignedIntValue];
        
        if (soundID) {
            
            if (vibrating) {
                
                AudioServicesPlayAlertSound(soundID);
                
            } else {
                
                AudioServicesPlaySystemSound(soundID);
            }
        }
    }
}

@end
