//
//  Ble.h
//  rssi
//
//  Created by Hussein Aboelseoud on 5/10/13.
//  Copyright (c) 2013 Hussein Aboelseoud. All rights reserved.
//


#import <UIKit/UIKit.h>
#import <Couchbaselite/CouchbaseLite.h>
#import <CouchbaseLite/CBLJSON.h>

@interface Ble : NSObject

@property (nonatomic, strong) CBLDatabase *database;
@property (nonatomic, strong) CBLReplication *push;
@property (nonatomic, strong) CBLReplication *pull;
@property (strong, nonatomic) NSURL *remoteURL;

- (id) init;

@end
