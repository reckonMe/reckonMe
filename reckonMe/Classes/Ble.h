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
#import <Couchbaselite/CBLUITableSource.h>
#import "PDRExchange.h"
#import "LocationEntry.h"
#import "PDRController.h"
#import "CouchDBController.h"

@interface Ble : NSObject

@property (nonatomic, strong) CBLDatabase *database;
@property (nonatomic, strong) CBLReplication *push;
@property (nonatomic, strong) CBLReplication *pull;
@property (strong, nonatomic) NSURL *remoteURL;
@property(nonatomic, assign) CBLLiveQuery* query;
@property(nonatomic, strong) IBOutlet CBLUITableSource* dataSource;
@property(nonatomic, assign) PDRController *pdr;
@property(nonatomic, assign) CouchDBController *couch;


- (id) init;

@end
