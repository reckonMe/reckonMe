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
#import "CouchDBController.h"

@interface Ble : NSObject

@property(nonatomic, assign) CouchDBController *couch;

- (id) init;

@end
