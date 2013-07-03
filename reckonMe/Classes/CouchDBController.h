//
//  CouchDBController.h
//  reckonMe
//
//  Created by Hussein Aboelseoud on 7/3/13.
//
//

#ifndef reckonMe_CouchDB_h
#define reckonMe_CouchDB_h
#endif

#import <UIKit/UIKit.h>
#import <Couchbaselite/CouchbaseLite.h>
#import <CouchbaseLite/CBLJSON.h>

@interface CouchDBController : NSObject

+ (CouchDBController *)sharedInstance;

@property (nonatomic, strong) CBLDatabase *database;
@property (nonatomic, strong) CBLReplication *push;
@property (nonatomic, strong) CBLReplication *pull;
@property (strong, nonatomic) NSURL *remoteURL;

- (void)pushStepWithSource:(NSString*)macAddress originX:(NSNumber*)x originY:(NSNumber*)y timestamp:(NSString*)timestamp x:(NSNumber*)xPosition y:(NSNumber*)yPosition;


@end