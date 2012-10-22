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

#import "AbstractSensor.h"


@implementation AbstractSensor

@synthesize isActive;
@synthesize isAvailable;

-(id)init {
	
    self = [super init];
	
    if (self != nil) {
        
        listeners = [[NSMutableSet alloc] initWithCapacity:3];
        listenersSemaphore = dispatch_semaphore_create(1);
        
        beginningOfEpoch = [[NSDate alloc] initWithTimeIntervalSince1970:0.0];
        isActive = NO;
        isAvailable = NO;
        shouldRestartIfListenersAvailable = NO;
    }
    
	return self;
}

-(void)dealloc {
    
	[listeners release];
	[beginningOfEpoch release];
    dispatch_release(listenersSemaphore);
	[super dealloc];
}

-(void)addListener:(id <SensorListener>)listener {
    
    /*
     * Perform the operation now if the call comes from the main thread,
     * schedule it there otherwise.
     * This allows sensor subclasses working on the main thread to ommit using the listenersSemaphore.
     */
    if ([NSThread isMainThread]) {
        
        //mutex to allow listener adding/removing while sensors are running
        dispatch_semaphore_wait(listenersSemaphore, DISPATCH_TIME_FOREVER);
        
            [listeners addObject:listener];
            NSUInteger listenerCount = [listeners count];
    	
        dispatch_semaphore_signal(listenersSemaphore);
        
        
        if (shouldRestartIfListenersAvailable && (listenerCount > 0)) {
            
            [self actuallyStart];
            shouldRestartIfListenersAvailable = NO;
            NSLog(@"(Re)started %@ because %@ has been added.", NSStringFromClass([self class]), NSStringFromClass([(NSObject *)listener class]));
        }
    
    } else {
        
        //block the calling thread and call from the main thread
        dispatch_sync(dispatch_get_main_queue(), ^(void) {
            
            [self addListener:listener];
        });
    }
}

-(void)removeListener:(id<SensorListener>)listener {
    
    /*
     * Perform the operation now if the call comes from the main thread,
     * schedule it there otherwise.
     * This allows sensor subclasses working on the main thread to ommit using the listenersSemaphore.
     */
    if ([NSThread isMainThread]) {
        
        dispatch_semaphore_wait(listenersSemaphore, DISPATCH_TIME_FOREVER);
        
            [listeners removeObject:listener];
            NSUInteger listenerCount = [listeners count];
        
        dispatch_semaphore_signal(listenersSemaphore);
        
        
        //we use the inActive property here, allowing subclasses to override it
        if (listenerCount == 0 && self.isActive) {
            
            shouldRestartIfListenersAvailable = YES;
            [self actuallyStop];
            NSLog(@"Stopped %@ because nobody is listening.", NSStringFromClass([self class]));
        }   
    
    } else {
        
        dispatch_sync(dispatch_get_main_queue(), ^(void) {
            
            [self removeListener:listener];
        });
    }
}

-(void)removeAllListeners {
    
    /*
     * Perform the operation now if the call comes from the main thread,
     * schedule it there otherwise.
     * This allows sensor subclasses working on the main thread to ommit using the listenersSemaphore.
     */
    if ([NSThread isMainThread]) {
        
        dispatch_semaphore_wait(listenersSemaphore, DISPATCH_TIME_FOREVER);
        
            [listeners removeAllObjects];
        
        dispatch_semaphore_signal(listenersSemaphore);
        
        //we use the property here, allowing subclasses to override it
        if (self.isActive) {
            
            shouldRestartIfListenersAvailable = YES;
            [self actuallyStop];
            NSLog(@"Stopped %@ because nobody is listening.", NSStringFromClass([self class]));
        }
    
    } else {
        
        dispatch_sync(dispatch_get_main_queue(), ^(void) {
            
            [self removeAllListeners];
        });
    }
}


-(NSTimeInterval)getTimestamp {
	
	NSTimeInterval timestamp = -[beginningOfEpoch timeIntervalSinceNow];
	return timestamp;
}


-(void)start {
    
    dispatch_semaphore_wait(listenersSemaphore, DISPATCH_TIME_FOREVER);
        
        NSUInteger listenerCount = [listeners count];
    
    dispatch_semaphore_signal(listenersSemaphore);
    

        if (listenerCount > 0) {
            
            shouldRestartIfListenersAvailable = NO;
            [self actuallyStart];
            
        } else {
            
            shouldRestartIfListenersAvailable = YES;
        }
}

-(void)stop {
    
    shouldRestartIfListenersAvailable = NO;
    [self actuallyStop];
}

//to be implemented by subclasses

- (void)actuallyStart {
    
    [NSException raise:NSInternalInconsistencyException 
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
}

- (void)actuallyStop {
    
    [NSException raise:NSInternalInconsistencyException 
                format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
}

@end
