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

#import "SoundDetector.h"
#import <Accelerate/Accelerate.h>
#import "SecondViewController.h"
#import "AlertSoundPlayer.h"
#import "Settings.h"

//if defined, records all FFT results and possible detections
#define SOUND_DEBUG

const float kSoundDetectorSamplingRate = 44100.0;
// the size of each audio buffer, which must be a power of 2 due to FFT
const int kBufferSize = 256;//512;
const int kFadingDuration = 16;
const int kNumberOfBuffers = 10;
const float kFFTbinWidth = kSoundDetectorSamplingRate / kBufferSize;

//specifies the emission pattern in amplitudes (in [0, 1]) per buffer to play
const float amplitude = 1;
const float  kPattern[] = {amplitude, amplitude, amplitude, amplitude, 0, 0, amplitude, amplitude, 0, 0, 0, 0};// {1, 1, 0, 1, 0, 0};
const int kPatternDuration = sizeof(kPattern) / sizeof(kPattern[0]);

//the window size with which to correlate
const int kDetectionSmallWindowSize = kPatternDuration;
//the required numbers of small windows per (big) window
const int kSmallWindowsPerBigWindow = 2;
//the number of FFT results to use for detection (sliding window)
const int kBigWindowSize = kDetectionSmallWindowSize * kSmallWindowsPerBigWindow;

const int kMovingAverageBufferSize = 16;
const int kProximateMovingAverageBufferSize = 8;

//detection thresholds
const float kMovingAverageThreshold = 0.46;
const float kHighCorrelationThreshold = 0.46;
const float kBothAveragesThreshold = 0.32;

//the noise channel is the one with number kNumChannel
const unsigned char kChannelToBinOffset = 105;
const unsigned char kChannelFactor = 3;

/*
 Bin  | frequency
 ================
 209	18001,76
 210	18087,89
 211	18174,02
 212	18260,16
 213	18346,29
 214	18432,42
 215	18518,55
 216	18604,69
 217	18690,82
 218	18776,95
 219	18863,09
 220	18949,22
 221	19035,35
 222	19121,48
 223	19207,62
 224	19293,75
 225	19379,88
 226	19466,02
 227	19552,15
 228	19638,28
 229	19724,41
 230	19810,55
 231	19896,68
 232	19982,81
 233	20068,95
 */
//const unsigned char  kFrequencyBin = 105;//209;
//const unsigned char kNoiseFrequencyBin = 108;//215;

const double kFrequencyDeltaFactor = 2 * M_PI / kSoundDetectorSamplingRate;


@interface SoundDetector ()

-(void)audioQueueFinished:(AudioQueueRef)queue;

-(void)setupRecordingQueue;
-(void)setupPlaybackQueue;

-(void)analyzeFFTresults;

-(audioChannel)channelForFFTbin:(unsigned char)bin;
-(unsigned char)fftBinForChannel:(audioChannel)channel;

//buffer callbacks
- (void)didRecordNewAudioBuffer:(AudioQueueBufferRef)buffer;
- (void)fillNewPlaybackBuffer:(AudioQueueBufferRef)buffer;

@end

static void recordingCallback (
							   void                                 *inUserData,
							   AudioQueueRef						inAudioQueue,
							   AudioQueueBufferRef					inBuffer,
							   const AudioTimeStamp                 *inStartTime,
							   UInt32								inNumPackets,
							   const AudioStreamPacketDescription	*inPacketDesc
                               ) {
	
    // This callback, being outside the implementation block, needs a reference to the 
	//	SoundDetector object -- which it gets via the inUserData parameter.
	SoundDetector *soundDetector = (SoundDetector *) inUserData;
    
    [soundDetector didRecordNewAudioBuffer:inBuffer];
}

static void playbackCallback (
                              void                 *inUserData,
                              AudioQueueRef        inAQ,
                              AudioQueueBufferRef  inBuffer
                              ) {
    
    // This callback, being outside the implementation block, needs a reference to the 
	//	SoundDetector object -- which it gets via the inUserData parameter.
	SoundDetector *soundDetector = (SoundDetector *) inUserData;
    
    //do nothing as we only play kEmissionLengthInBuffers buffers, which have already been enqueued
    [soundDetector fillNewPlaybackBuffer:inBuffer];
}

static void audioQueueFinishedCallback (
                                        void                  *inUserData,
                                        AudioQueueRef         inAQ,
                                        AudioQueuePropertyID  inID
                                        ) {
    
    if (inID == kAudioQueueProperty_IsRunning) {
        
        UInt32 isRunning = 0;
        UInt32 size = sizeof(isRunning);
        AudioQueueGetProperty(inAQ,
                              kAudioQueueProperty_IsRunning,
                              &isRunning,
                              &size);
        
        if (!isRunning) {
            
            // This callback, being outside the implementation block, needs a reference to the 
            //	SoundDetector object -- which it gets via the inUserData parameter.
            SoundDetector *soundDetector = (SoundDetector *) inUserData;
            
            [soundDetector audioQueueFinished:inAQ];
        }
    }
}


@implementation SoundDetector {

@private
    
    AudioStreamBasicDescription playbackFormat;
    AudioQueueRef recordingQueue;
    AudioQueueRef playbackQueue;
    
    //oscillator phase in radians
    double phaseLow;
    double frequencyDelta;
    
    FFTSetup precalculatedFFTsetup;
    
    //stores the last kNumberFFTbuffers FFT results
    float *fftBuffers[kBigWindowSize];
    NSUInteger currentFFTBuffer;
    BOOL enoughDataForAnalysis;
    
    float movingAverageBuffer[kNumChannels][kMovingAverageBufferSize];
    int movingAverageBufferIndex;
    BOOL enoughValuesInMovingAverageBuffer;
    
    float proximateMovingAverageBuffer[kNumChannels][kProximateMovingAverageBufferSize];
    int proximateMovingAverageBufferIndex;
    BOOL enoughValuesInProximateMovingAverageBuffer;
    
    AudioQueueBufferRef recordingBuffers[kNumberOfBuffers];
    AudioQueueBufferRef playbackBuffers[kNumberOfBuffers];
    
    NSUInteger playbackBufferCounter;
    
    //we are calling our delegate asynchronously to prevent
    //blocking of our analysis and recording thread
    dispatch_queue_t delegateCallingQueue;
    
    BOOL listenToChannels[kNumChannels];
    
#ifdef SOUND_DEBUG
    FILE *audioLog;
    FILE *audioAnalysisLog;
#endif
#ifdef SOUND_TESTS
    FILE *detectionLog;
    FILE *volumeLog;
#endif
}

@synthesize delegate;
@synthesize emitting, detecting;
@synthesize audioFileName;

static SoundDetector *sharedSingleton;

+(SoundDetector *)sharedInstance {
    
    return sharedSingleton;
}

//Is called by the runtime in a thread-safe manner exactly once, before the first use of the class.
//This makes it the ideal place to set up the singleton.
+ (void)initialize
{
	//is necessary, because +initialize may be called directly
    static BOOL initialized = NO;
    
	if(!initialized)
    {
        initialized = YES;
        sharedSingleton = [[SoundDetector alloc] init];
    }
}

-(id)init {
    
    if (self = [super init]) {
        
        emitting = NO;
        detecting = NO;
        
        phaseLow = 0.0;
        
        //precalculate data for faster FFT computation
        precalculatedFFTsetup = vDSP_create_fftsetup(log2f(kBufferSize),
                                                     kFFTRadix2);
        
        //allocate the magnitude buffers
        for (int i = 0; i < kBigWindowSize; i++) {
            
            float *buffer;
            
            buffer = (float *)malloc((kBufferSize / 2) * sizeof(float));
            
            fftBuffers[i] = buffer;
        }
        
        //initialize the audio session
        AudioSessionInitialize ( NULL, NULL, NULL, self);
        
        //listen for audio session interruptions
        [[AVAudioSession sharedInstance] setDelegate:self];
        
        OSStatus error = 0;
        
        //set audio session mode for measurement, which prevents automatic gain adjustment
        UInt32 sessionMode = kAudioSessionMode_Measurement;
        AudioSessionSetProperty (
                                 kAudioSessionProperty_Mode,
                                 sizeof (sessionMode),
                                 &sessionMode
                                 );
        
        //specify the recording format.
        AudioStreamBasicDescription	recordingFormat;
        recordingFormat.mFormatID			= kAudioFormatLinearPCM;
        recordingFormat.mSampleRate = kSoundDetectorSamplingRate;
        recordingFormat.mChannelsPerFrame	= 1;
        
        if (recordingFormat.mFormatID == kAudioFormatLinearPCM) {
            
            recordingFormat.mFormatFlags		= kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
            recordingFormat.mFramesPerPacket	= 1;
            recordingFormat.mBitsPerChannel		= sizeof(float) * 8;
            recordingFormat.mBytesPerPacket		= sizeof(float);
            recordingFormat.mBytesPerFrame		= sizeof(float);
        }
        
        //set up the recording queue
        error = AudioQueueNewInput (
                                    &recordingFormat,
                                    recordingCallback,
                                    self,					// userData
                                    NULL,					// run loop
                                    NULL,					// run loop mode
                                    0,						// flags
                                    &recordingQueue
                                    );
        
        if (error) {
            
            NSLog(@"error creating recording queue: %ld", error);
        }
        
        //listen for starting/stopping of the queue
        error = AudioQueueAddPropertyListener(recordingQueue,
                                              kAudioQueueProperty_IsRunning,
                                              audioQueueFinishedCallback,
                                              self);
        if (error) {
            
            NSLog(@"error setting finish callback for recording queue: %ld", error);
        }
        
        //allocate and buffers
        for (int bufferIndex = 0; bufferIndex < kNumberOfBuffers; ++bufferIndex) {
            
            AudioQueueBufferRef buffer;
            
            error = AudioQueueAllocateBuffer (
                                              recordingQueue,
                                              kBufferSize * recordingFormat.mBytesPerFrame,
                                              &buffer
                                              );
            
            if (error) {
                
                NSLog(@"error allocating buffer: %ld", error);
            }
            
            recordingBuffers[bufferIndex] = buffer;
        }
        
        //specify the playback format.
        playbackFormat.mFormatID         = kAudioFormatLinearPCM;
        playbackFormat.mSampleRate       = kSoundDetectorSamplingRate;
        playbackFormat.mChannelsPerFrame = 1;
        
        if (playbackFormat.mFormatID == kAudioFormatLinearPCM) {
            
            playbackFormat.mFormatFlags		= kAudioFormatFlagIsSignedInteger 
            | kAudioFormatFlagIsPacked;
            playbackFormat.mFramesPerPacket	= 1;
            playbackFormat.mBitsPerChannel	= 16;
            playbackFormat.mBytesPerPacket	= sizeof(SInt16);
            playbackFormat.mBytesPerFrame	= sizeof(SInt16);
        }
        
        //set up the playback queue
        AudioQueueNewOutput(
                            &playbackFormat,
                            playbackCallback,
                            self,					// userData
                            NULL,					// run loop
                            NULL,					// run loop mode
                            0,						// flags
                            &playbackQueue
                            );
        
        //listen for starting/stopping of the queue
        AudioQueueAddPropertyListener(playbackQueue,
                                      kAudioQueueProperty_IsRunning,
                                      audioQueueFinishedCallback,
                                      self);
        
        // allocate buffers
        for (int bufferIndex = 0; bufferIndex < kNumberOfBuffers; ++bufferIndex) {
            
            AudioQueueBufferRef buffer;
            
            AudioQueueAllocateBuffer (
                                      playbackQueue,
                                      kBufferSize * playbackFormat.mBytesPerFrame,
                                      &buffer
                                      );
            
            playbackBuffers[bufferIndex] = buffer;
        }
        
        self.audioFileName = @"audioFile";
        
        delegateCallingQueue = dispatch_queue_create("delegate calling queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

-(void)dealloc {
    
    [[AVAudioSession sharedInstance] setDelegate:nil];
    
    [self stopDetection];
    [self stopEmission];
    
    //dispose the queue, also frees the audio buffers
    AudioQueueDispose (
                       recordingQueue,
                       FALSE
                       );
    
    //dispose the queue, also frees the audio buffers
    AudioQueueDispose (
                       playbackQueue,
                       FALSE
                       );
    
    vDSP_destroy_fftsetup(precalculatedFFTsetup);
    
    for (int i = 0; i < kBigWindowSize; i++) {
        
        free(fftBuffers[i]);
    }
    
    self.delegate = nil;
    
    self.audioFileName = nil;
    
    dispatch_release(delegateCallingQueue);
    
    [super dealloc];
}

-(audioChannel)numChannels {
    
    return kNumChannels;
}

-(audioChannel)channelForFFTbin:(unsigned char)bin {
    
    return (bin - kChannelToBinOffset) / kChannelFactor;
}

-(unsigned char)fftBinForChannel:(audioChannel)channel {
    
    return kChannelToBinOffset + (channel * kChannelFactor);
}

-(BOOL)isDetectionAvailable {
    
    return [[AVAudioSession sharedInstance] inputIsAvailable];
}

//called by the property listener callback
-(void)audioQueueFinished:(AudioQueueRef)queue {
    
    if (queue == recordingQueue) {
        
#ifdef SOUND_DEBUG
        //close the log files
        fclose(audioLog);
        fclose(audioAnalysisLog);
#endif
#ifdef SOUND_TESTS
        fclose(detectionLog);
        fclose(volumeLog);
#endif
    }
    
    if (queue == playbackQueue) {
        
        //ToDo
    }
}

//MARK: - Logic
-(void)startDetection {
dispatch_async(dispatch_get_main_queue(), ^(void) {
    if (!self.isDetecting && !self.isEmitting) {
        
        detecting = YES;
        enoughDataForAnalysis = NO;
        enoughValuesInMovingAverageBuffer = NO;
        enoughValuesInProximateMovingAverageBuffer = NO;
        currentFFTBuffer = -1;
        movingAverageBufferIndex = -1;
        proximateMovingAverageBufferIndex = -1;
        
        [self setupRecordingQueue];
        
        OSStatus error = 0;
        
        error = AudioSessionSetActive (true);
        
        if (error) {
            
            NSLog(@"error activating session: %ld", error);
        }
        
        error = AudioQueueStart (
                                 recordingQueue,
                                 NULL			// start time. NULL means as soon as possible.
                                 );
        
        if (error) {
            
            NSLog(@"error starting recordingQueue: %ld", error);
        }
        
        [[SecondViewController sharedInstance] addToLog:@"Detecting sound..."];
        
#ifdef SOUND_DEBUG
        NSArray  *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSMutableString *documentsDirectory = [paths objectAtIndex:0];
        
        //create the debugging FFT results file with a consecutive number appended (persistent due to NSUserDefaults)
        NSString *audioCounterPrefKey = @"audioCounter";
        NSInteger audioCount = [[NSUserDefaults standardUserDefaults] integerForKey:audioCounterPrefKey];
        NSString *fileName = [NSString stringWithFormat:@"%04d-%@FFT.txt", audioCount, self.audioFileName];
        NSString *analysisFileName = [NSString stringWithFormat:@"%04d-%@.txt", audioCount, self.audioFileName];        
        [[NSUserDefaults standardUserDefaults] setInteger:++audioCount
                                                   forKey:audioCounterPrefKey];
        
        NSString *completeFilePath = [documentsDirectory stringByAppendingPathComponent:fileName];
        NSString *completeAnalysisFilePath = [documentsDirectory stringByAppendingPathComponent:analysisFileName];
        
        audioLog = fopen([completeFilePath cStringUsingEncoding: [NSString defaultCStringEncoding]], "w");
        audioAnalysisLog = fopen([completeAnalysisFilePath cStringUsingEncoding: [NSString defaultCStringEncoding]], "w");
        
        fprintf(audioAnalysisLog, "%% patternLength=%d buffers, bufferDuration=%fs, movingAverageBufferSize=%d, proximateMovingAverageBufferSize=%d, kMovingAverageThreshold=%f, kHighCorrelationThreshold=%f, kBothAveragesThreshold=%f\n",
                kPatternDuration,
                1 / (kSoundDetectorSamplingRate / kBufferSize),
                kMovingAverageBufferSize,
                kProximateMovingAverageBufferSize,
                kMovingAverageThreshold,
                kHighCorrelationThreshold,
                kBothAveragesThreshold);
        fprintf(audioAnalysisLog, "%%columns: individualThresholdsExceeded, commonThresholdExceeded, average, highCorrAverage\n");
#endif
#ifdef SOUND_TESTS
        NSArray  *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSMutableString *documentsDirectory = [paths objectAtIndex:0];
        
        //create the debugging FFT results file with a consecutive number appended (persistent due to NSUserDefaults)
        NSString *audioCounterPrefKey = @"audioVolumeFileCounter";
        NSInteger audioCount = [[NSUserDefaults standardUserDefaults] integerForKey:audioCounterPrefKey];
        NSString *detectionsFileName = [NSString stringWithFormat:@"%04d-detections.txt", audioCount];
        NSString *volumeFileName = [NSString stringWithFormat:@"%04d-volume.txt", audioCount];        
        [[NSUserDefaults standardUserDefaults] setInteger:++audioCount
                                                   forKey:audioCounterPrefKey];
        
        NSString *completeDetectionsFilePath = [documentsDirectory stringByAppendingPathComponent:detectionsFileName];
        NSString *completeVolumeFilePath = [documentsDirectory stringByAppendingPathComponent:volumeFileName];
        
        detectionLog = fopen([completeDetectionsFilePath cStringUsingEncoding: [NSString defaultCStringEncoding]], "w");
        volumeLog = fopen([completeVolumeFilePath cStringUsingEncoding: [NSString defaultCStringEncoding]], "w");
#endif
    }
});
}

-(void)stopDetection {
dispatch_async(dispatch_get_main_queue(), ^(void) {
    if (self.isDetecting) {
        
        detecting = NO;
        
        OSStatus error = 0;
        
        error = AudioQueueStop(recordingQueue,
                               true);//true = stop immediately
        if (error) {
            
            NSLog(@"error stopping recording queue: %ld", error);
        }
        
        error = AudioSessionSetActive(false);
        
        if (error) {
            
            NSLog(@"error deactivting audio session after stopping recording queue: %ld", error);
        }
        
        [[SecondViewController sharedInstance] addToLog:@"Stopped detection."];
        
        for (int channel = 0; channel < kNumChannels; channel++) {
            
            listenToChannels[channel] = NO;
        }
    }
});
}

-(void)listenForChannel:(audioChannel)channel {
    
    if (channel < kNumChannels) {
        
        listenToChannels[channel] = YES;
        [[SecondViewController sharedInstance] addToLog:[NSString stringWithFormat:@"Listening on channel: %d", channel]];
    }
}

-(void)stopListeningForChannel:(audioChannel)channel {
    
    if (channel < kNumChannels) {
        
        listenToChannels[channel] = NO;
        [[SecondViewController sharedInstance] addToLog:[NSString stringWithFormat:@"Stop listening for: %d", channel]];
    }
}

-(void)startEmissionOnChannel:(audioChannel)channel {
dispatch_async(dispatch_get_main_queue(), ^(void) {    
    if (!self.isEmitting && !self.isDetecting) {
        
        emitting = YES;
        
        phaseLow = 0.0;
        //amount by which phase is incremented in each sample
        frequencyDelta = [self fftBinForChannel:channel] * kFFTbinWidth * kFrequencyDeltaFactor;
        
        AudioSessionSetActive (true);
        
        [self setupPlaybackQueue];
        
        AudioQueueStart (
                         playbackQueue,
                         NULL			// start time. NULL means as soon as possible.
                         );
        
        [[SecondViewController sharedInstance] addToLog:[NSString stringWithFormat:@"Emitting on channel: %d", channel]];
    }
});
}

-(void)stopEmission {
dispatch_async(dispatch_get_main_queue(), ^(void) {
    if (self.isEmitting) {
        
        emitting = NO;
        
        AudioQueueStop(playbackQueue,
                       true);//true = stop immediately
        
        AudioSessionSetActive(false);
        
        [[SecondViewController sharedInstance] addToLog:@"Stopped emission."];
    }
});
}

-(void)stop {
    
    [self stopDetection];
    [self stopEmission];
}

//MARK: - setting audio properties
-(void)setupRecordingQueue {
    
    OSStatus error = 0;
    
    //define intentions: record audio, mute any playback
    UInt32 sessionCategory = kAudioSessionCategory_PlayAndRecord;
    error = AudioSessionSetProperty (
                                     kAudioSessionProperty_AudioCategory,
                                     sizeof (sessionCategory),
                                     &sessionCategory
                                     );
    if (error) {
        
        NSLog(@"error setting audio session category: %ld", error);
    }
    
    //disallow mixing with other sounds (system sounds, other apps)
    UInt32 allowMixing = YES;
    error = AudioSessionSetProperty (
                                     kAudioSessionProperty_OverrideCategoryMixWithOthers,
                                     sizeof (allowMixing),
                                     &allowMixing
                                     );
    
    if (error) {
        
        NSLog(@"error setting mixing: %ld", error);
    }
    
    //set highest input gain
    Float32 gain = 1.0;
    error = AudioSessionSetProperty (
                                     kAudioSessionProperty_InputGainScalar,
                                     sizeof (gain),
                                     &gain
                                     );
    
    if (error) {
        
        NSLog(@"error setting input gain: %ld", error);
    }
    
    //(dis)allow Bluetooth devices as input
    UInt32 allowBluetoothInput = FALSE;
    error = AudioSessionSetProperty (
                                     kAudioSessionProperty_OverrideCategoryEnableBluetoothInput,
                                     sizeof (allowBluetoothInput),
                                     &allowBluetoothInput
                                     );
    
    if (error) {
        
        NSLog(@"error setting bluetooth: %ld", error);
    }
    
    for (int i = 0; i < kNumberOfBuffers; i++) {
        
        error = AudioQueueEnqueueBuffer(recordingQueue,
                                        recordingBuffers[i],
                                        0,
                                        NULL);
        if (error) {
            
            NSLog(@"error enqueueing buffer: %ld", error);
        }
    }
}

-(void)setupPlaybackQueue {
    
    //define intentions: chose media playback, as this category is "loudest"
    UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
    AudioSessionSetProperty (
                             kAudioSessionProperty_AudioCategory,
                             sizeof (sessionCategory),
                             &sessionCategory
                             );
    
    //allow mixing with other sounds (system sounds, other apps)
    UInt32 allowMixing = TRUE;
    AudioSessionSetProperty (
                             kAudioSessionProperty_OverrideCategoryMixWithOthers,
                             sizeof (allowMixing),
                             &allowMixing
                             );
    
    AudioQueueParameterValue volume = 1.0;
    AudioQueueSetParameter(playbackQueue,
                           kAudioQueueParam_Volume,
                           volume);
    
    for (int i = 0; i < kNumberOfBuffers; i++) {
        
        AudioQueueBufferRef buffer = playbackBuffers[i];
        
        [self fillNewPlaybackBuffer:buffer];
    }
}

//MARK: - managing interruptions

//called, when the audio session is interrupted (e.g. by a phone call)
- (void) beginInterruption {
    
    OSStatus error = 0;
    
    if (self.isEmitting) {
        
        error = AudioQueuePause(playbackQueue);
        
    }
    
    if (self.isDetecting) {
        
        error = AudioQueuePause(recordingQueue);
    }
    
    if (error) {
        
        NSLog(@"error pausing queue: %ld", error);
    }
}

//called, when the interruption ends
- (void) endInterruptionWithFlags:(NSUInteger)flags {
    
    OSStatus error = 0;
    
    // Test if the interruption that has just ended was one from which this app 
    // should resume recording.
    if (flags & AVAudioSessionInterruptionFlags_ShouldResume) {
        
        if (self.isEmitting) {
            
            //start the paused audio queue again
            error = AudioQueueStart (playbackQueue,
                                     NULL			// start time. NULL means as soon as possible.
                                     );
        }
        
        if (self.isDetecting) {
            
            //start the paused audio queue again
            error = AudioQueueStart (recordingQueue,
                                     NULL			// start time. NULL means as soon as possible.
                                     );
        }
    }
    
    if (error) {
        
        NSLog(@"error resuming audio queue = ");
    }
}

//MARK: - raw audio handling

-(void)fillNewPlaybackBuffer:(AudioQueueBufferRef)buffer {
    
    SInt16 *rawBuffer = buffer->mAudioData;
    UInt32 bufferByteSize = kBufferSize * playbackFormat.mBytesPerFrame;
    
    float amplitudeLookAhead = kPattern[(playbackBufferCounter + 1) % kPatternDuration];
    float amplitudeLookBack = kPattern[(playbackBufferCounter == 0) ? (kPatternDuration - 1) : (playbackBufferCounter - 1)];
    
    float currentAmplitude = kPattern[playbackBufferCounter];
    BOOL fadeIn = amplitudeLookBack < currentAmplitude;
    BOOL fadeOut = amplitudeLookAhead < currentAmplitude;
    
    float fadeInDeltaAmplitude = (currentAmplitude - amplitudeLookBack) / kFadingDuration;
    float fadeOutDeltaAmplitude = (amplitudeLookAhead - currentAmplitude) / kFadingDuration;
    
    if (fadeIn) {
        
        currentAmplitude = amplitudeLookBack;
    }
    
    //generate the sine wave
    for (int i = 0; i < kBufferSize; i++) {
        
        if (fadeIn && (i < kFadingDuration)) {
            
            currentAmplitude += fadeInDeltaAmplitude;
        }
        
        if (fadeOut && (i >= (kBufferSize - kFadingDuration))) {
            
            currentAmplitude += fadeOutDeltaAmplitude;
        }
        
        rawBuffer[i] = (SInt16) ( currentAmplitude * sin(phaseLow)  * (INT16_MAX - 1));
        
        //increment phase
        phaseLow += frequencyDelta;
        
        //prevent overflow
        if (phaseLow > 2.0 * M_PI) {
            
            phaseLow -= 2.0 * M_PI;
        }
    }
    
    //tell the buffer how much bytes we filled in
    buffer->mAudioDataByteSize = bufferByteSize;
    
    if (self.isEmitting) {
        
        AudioQueueEnqueueBuffer(playbackQueue,
                                buffer,
                                0,
                                NULL);
    }
    
    playbackBufferCounter++;
    if (playbackBufferCounter == kPatternDuration) playbackBufferCounter = 0;
}

-(float)correlationOfA:(float *)a B:(float *)b length:(const int)len {
    
    float meanA = 0;
    vDSP_meanv(a,
               1,
               &meanA,
               len);
    
    float meanB = 0;
    vDSP_meanv(b,
               1,
               &meanB,
               len);
    
    float aMinusMean[len];
    float minusMeanA = -meanA;
    vDSP_vsadd(a,
               1,
               &minusMeanA,
               aMinusMean,
               1,
               len);
    
    float bMinusMean[len];
    float minusMeanB = -meanB;
    vDSP_vsadd(b,
               1,
               &minusMeanB,
               bMinusMean,
               1,
               len);
    
    float product[len];
    vDSP_vmul(aMinusMean,
              1,
              bMinusMean,
              1,
              product,
              1,
              len);
    
    float sum = 0;
    for (int i = 0; i < len; i++) {
        
        sum += product[i];
    }
    
    float aMinusMeanSquared[len];
    vDSP_vsq(aMinusMean,
             1,
             aMinusMeanSquared,
             1,
             len);
    
    float bMinusMeanSquared[len];
    vDSP_vsq(bMinusMean,
             1,
             bMinusMeanSquared,
             1,
             len);
    
    float aMinusMeanSquaredSum = 0;
    for (int i = 0; i < len; i++) {
        
        aMinusMeanSquaredSum += aMinusMeanSquared[i];
    }
    
    float bMinusMeanSquaredSum = 0;
    for (int i = 0; i < len; i++) {
        
        bMinusMeanSquaredSum += bMinusMeanSquared[i];
    }
    
    float result = sum / sqrtf(aMinusMeanSquaredSum * bMinusMeanSquaredSum);
    
    return result;
}

-(void)didRecordNewAudioBuffer:(AudioQueueBufferRef)buffer {
    
    currentFFTBuffer = ++currentFFTBuffer % kBigWindowSize;
    
    //allocate memory for the FFT result
    COMPLEX_SPLIT fftResult;
    float real[kBufferSize / 2];
    float imag[kBufferSize / 2];
    fftResult.realp = real;
    fftResult.imagp = imag;
    
    //copy the audio buffer into the DSPSplitComplex buffer
    // 1. masquerades n real numbers as n/2 complex numbers = {2+1i, 4+3i, ...}
    // 2. splits to 
    //   A.realP = {2,4,...} (n/2 elts)
    //   A.compP = {1,3,...} (n/2 elts)
    vDSP_ctoz(
              (COMPLEX *)buffer->mAudioData, 
              2,                        //stride 2, as each complex number is 2 floats
              &fftResult, 
              1,                        //stride 1 in fftBuffer.realP & .compP
              kBufferSize / 2);
    
    //perform the FFT
    vDSP_fft_zrip(precalculatedFFTsetup,
                  &fftResult,
                  1,                    //stride 1 = every value
                  log2f(kBufferSize),
                  FFT_FORWARD);
    
    /*
     * Compute the square root of the sum of the squares of corresponding elements of realp and imagp,
     * which is the complex vector's distance.
     * The result is magnitude / 2, but multiplying by 2 is omitted as our analysis relies on
     * relative instead of absolute values anyway.
     */
    vDSP_vdist(fftResult.realp,
               1,
               fftResult.imagp,
               1,
               fftBuffers[currentFFTBuffer],
               1,
               kBufferSize / 2);
    
    if (self.isDetecting) {
        
        OSStatus error = 0;
        error = AudioQueueEnqueueBuffer(recordingQueue,
                                        buffer,
                                        0,
                                        NULL);
        if (error) {
            
            NSLog(@"error enqueueing buffer: %ld", error);
        }
    }
    
    //is the window already full?
    if (!enoughDataForAnalysis && (currentFFTBuffer + 1 == kBigWindowSize)) {
        
        enoughDataForAnalysis = YES;
    }
    
    if (enoughDataForAnalysis && ((currentFFTBuffer + 1) % kDetectionSmallWindowSize) == 0) {
        
        //analyze the FFT data and notify the delegate of any results
        [self analyzeFFTresults];
    }
}

-(void)analyzeFFTresults {
    
#ifdef SOUND_DEBUG
    //write to file
    for (int i = 0; i < kDetectionSmallWindowSize; i++) {
        
        //start with the oldest buffer (=current + 1) and end with the newest (=current)
        int fftIndex = (currentFFTBuffer + i + 1) % kBigWindowSize;
        
        for (int bin = 0; bin < kBufferSize / 2; bin++) {
            
            fprintf(audioLog, "%f\t", fftBuffers[fftIndex][bin]);
        }
        fprintf(audioLog, "\n");
    }
#endif
    
    //kNumChannel is our noise channel, hence +1
    int numChannelsForAutoCorr = kNumChannels + 1;
    int kNoiseChannel = kNumChannels;
    
    float toCorrelate[numChannelsForAutoCorr][kBigWindowSize];
    float autoCorrelationResults[numChannelsForAutoCorr];
    float averageLoudness[numChannelsForAutoCorr];
    
    //correlate the signal of numChannelsForAutoCorr with theirself kDetectionSmallWindowSize values before
    for (int channel = 0; channel < numChannelsForAutoCorr; channel++) {
        
        //bring the FFT buffer data into the right temporal order and copy it
        for (int i = 0; i < kBigWindowSize; i++) {
            
            //start with the oldest buffer (=current + 1) and end with the newest (=current)
            int fftIndex = (currentFFTBuffer + i + 1) % kBigWindowSize;
            int binIndex = [self fftBinForChannel:channel];
            
            toCorrelate[channel][i] = fftBuffers[fftIndex][binIndex];
        }
        
        autoCorrelationResults[channel] = [self correlationOfA:toCorrelate[channel]
                                                             B:toCorrelate[channel] + kDetectionSmallWindowSize
                                                        length:kDetectionSmallWindowSize];
        
        //compute average loudness for last kDetectionSmallWindowSize values
        vDSP_meanv(toCorrelate[channel] + kDetectionSmallWindowSize,
                   1,
                   &averageLoudness[channel],
                   kDetectionSmallWindowSize);
    }
    
    
    movingAverageBufferIndex = ++movingAverageBufferIndex % kMovingAverageBufferSize;
    proximateMovingAverageBufferIndex = ++proximateMovingAverageBufferIndex % kProximateMovingAverageBufferSize;
    
    for (int channel = 0; channel < kNumChannels; channel++) {        
        
        float signalCorrMinusNoiseCorr = autoCorrelationResults[channel] - autoCorrelationResults[kNoiseChannel];
        
        movingAverageBuffer[channel][movingAverageBufferIndex] = signalCorrMinusNoiseCorr;
        proximateMovingAverageBuffer[channel][proximateMovingAverageBufferIndex] = autoCorrelationResults[channel];
    }
    
    //is the window already full?
    if (!enoughValuesInProximateMovingAverageBuffer && (proximateMovingAverageBufferIndex + 1 == kProximateMovingAverageBufferSize)) {
        
        enoughValuesInProximateMovingAverageBuffer = YES;
    }
    
    
    //is the window already full?
    if (!enoughValuesInMovingAverageBuffer && (movingAverageBufferIndex + 1 == kMovingAverageBufferSize)) {
        
        enoughValuesInMovingAverageBuffer = YES;
    }
    
#ifdef SOUND_TESTS
    NSDate *date = [[NSDate alloc] init];
    NSTimeInterval currentTime = [date timeIntervalSince1970];
    [date release];
    fprintf(volumeLog, "%f\t", currentTime);
    fprintf(detectionLog, "%f\t", currentTime);
#endif
    
    //check for occurences
    for (int channel = 0; channel < kNumChannels; channel++) {
        
        if (listenToChannels[channel]) {
            
            BOOL individualThresholdsExceeded = NO;
            BOOL commonThresholdExceeded = NO;
            
            float average = 0;
            if (enoughValuesInMovingAverageBuffer) {
                
                vDSP_meanv(movingAverageBuffer[channel],
                           1,
                           &average,
                           kMovingAverageBufferSize);
            }
            
            float highCorrAverage = 0;
            if (enoughValuesInProximateMovingAverageBuffer) {
                
                vDSP_meanv(proximateMovingAverageBuffer[channel],
                           1,
                           &highCorrAverage,
                           kProximateMovingAverageBufferSize);
            }
            
            if (           (average > kMovingAverageThreshold)
                || (highCorrAverage > kHighCorrelationThreshold)) {
                
                individualThresholdsExceeded = YES;
            }
            
            if (           (average > kBothAveragesThreshold)
                && (highCorrAverage > kBothAveragesThreshold)) {
                
                commonThresholdExceeded = YES;
            }
            
            BOOL detected = individualThresholdsExceeded || commonThresholdExceeded;
            float averageVolume = averageLoudness[channel];
            
#ifdef SOUND_DEBUG
            fprintf(audioAnalysisLog, "%d\t%d\t%f\t%f\n", individualThresholdsExceeded, commonThresholdExceeded, average, highCorrAverage);
#endif
#ifdef SOUND_TESTS
            fprintf(detectionLog, "%d\t", detected);
            fprintf(volumeLog, "%f\t", averageVolume);
#endif
            
            if (detected) {
                                
                dispatch_async(delegateCallingQueue, ^(void) {
                    
                    //@autoreleasepool {
                        
                        [self.delegate soundDetector:self
                             didDetectSoundOnChannel:channel
                                   withAverageVolume:averageVolume];
                    //}
                });
            }
        }
    }
#ifdef SOUND_TESTS
    fprintf(detectionLog, "\n");
    fprintf(volumeLog, "\n");
#endif
}

@end
