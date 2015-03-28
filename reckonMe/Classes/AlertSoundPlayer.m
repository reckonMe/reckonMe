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
        
        synthesizer = [[AVSpeechSynthesizer alloc] init];
    }
    return self;
}

    
-(void)dealloc {
    
    [synthesizer release];
    
    [super dealloc];
}

-(void)vibrate {
    
    AudioServicesPlaySystemSound (kSystemSoundID_Vibrate);
}

-(void)say:(NSString *)textToSay interruptOngoingSpeech:(BOOL)interrupt vibrate:(BOOL)vibrate {
    
    if (interrupt && synthesizer.isSpeaking) {
        
        [synthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    }
    
    AVSpeechUtterance *utterance = [[AVSpeechUtterance alloc] initWithString:textToSay];
    utterance.voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"en-US"];
    utterance.rate = MAX(AVSpeechUtteranceDefaultSpeechRate / 4, AVSpeechUtteranceMinimumSpeechRate);
    
    [synthesizer speakUtterance:utterance];
    [utterance release];
    
    if (vibrate) {
        
        [self vibrate];
    }
}

@end
