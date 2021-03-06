//
//  SMUnifiedLocalFolder.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/6/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "SMUserAccountDataObject.h"
#import "SMAbstractLocalFolder.h"

@protocol SMAbstractAccount;

@class SMUnifiedAccount;
@class SMLocalFolder;

@interface SMUnifiedLocalFolder : SMUserAccountDataObject<SMAbstractLocalFolder>

- (id)initWithUserAccount:(SMUnifiedAccount*)account localFolderName:(NSString*)localFolderName kind:(SMFolderKind)kind;
- (void)attachLocalFolder:(SMLocalFolder*)localFolder;
- (void)detachLocalFolder:(SMLocalFolder*)localFolder;
- (SMLocalFolder*)attachedLocalFolderForAccount:(SMUserAccount*)account;
- (BOOL)hasLocalFolderAttached:(SMLocalFolder*)localFolder;

@end
