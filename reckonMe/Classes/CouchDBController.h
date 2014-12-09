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
#import "CouchbaseLite.h"
#import "PDRController.h"

//@class PDRController;

@interface CouchDBController : NSObject

+ (CouchDBController *)sharedInstance;

@property (nonatomic, strong) CBLDatabase *database;
@property (nonatomic, strong) CBLReplication *push;
@property (nonatomic, strong) CBLReplication *pull;
@property (strong, nonatomic) NSURL *remoteURL;
@property (nonatomic, assign) CBLLiveQuery* query;
@property (nonatomic, strong) IBOutlet CBLUITableSource* dataSource;
@property (nonatomic, assign) PDRController *pdr;
@property (nonatomic) BOOL notyet;

- (void)pushStepWithSource:(NSString*)macAddress location:(CLLocationCoordinate2D)location timestamp:(NSString*)timestamp;

- (void)pushBluetoothDataDocument:(NSDictionary*)dictionary;

@end