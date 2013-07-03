//
//  CouchDBController.m
//  reckonMe
//
//  Created by Hussein Aboelseoud on 7/3/13.
//
//


#import "CouchDBController.h"

static CouchDBController *sharedSingleton;

@implementation CouchDBController

@synthesize database;
@synthesize pull;
@synthesize push;
@synthesize remoteURL;

+ (void)initialize {
    
	//is necessary, because +initialize may be called directly
    static BOOL initialized = NO;
    
	if(!initialized)
    {
        initialized = YES;
        sharedSingleton = [[CouchDBController alloc] init];
    }
}

- (id)init {
    
    self = [super init];
    if (self) {
        NSError* error;
        self.database = [[CBLManager sharedInstance] createDatabaseNamed: @"ble"
                                                                   error: &error];
    }
    
    return self;
}


+(CouchDBController *)sharedInstance {
    
    return sharedSingleton;
}

- (void)pushStepWithSource:(NSString*)macAddress originX:(NSNumber*)x originY:(NSNumber*)y timestamp:(NSString*)timestamp x:(NSNumber*)xPosition y:(NSNumber*)yPosition{
    
    CBLDocument* doc = [database untitledDocument];
    
    NSDictionary *origin = [NSDictionary dictionaryWithObjectsAndKeys:
                              x, @"x",
                              y, @"y",
                              nil];
    
    NSDictionary *position = [NSDictionary dictionaryWithObjectsAndKeys:
                              timestamp, @"timestamp",
                              xPosition, @"x",
                              yPosition, @"y",
                              nil];
        
    NSDictionary *location = [NSDictionary dictionaryWithObjectsAndKeys:
                              origin, @"origin",
                              position, @"position",
                              nil];
    
    NSDictionary *contents = [NSDictionary dictionaryWithObjectsAndKeys:
                              macAddress, @"source",
                              @"elvis", @"dest",
                              location, @"location",
                              nil];
    NSError *error;

    [doc putProperties: contents error: &error];
}

@end