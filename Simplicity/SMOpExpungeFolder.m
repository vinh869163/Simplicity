//
//  SMOpExpungeFolder.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/4/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMAppDelegate.h"
#import "SMMessageListController.h"
#import "SMOpExpungeFolder.h"

@implementation SMOpExpungeFolder {
    NSString *_remoteFolderName;
    MCOIMAPOperation *_currentOp;
}

- (id)initWithRemoteFolder:(NSString*)remoteFolderName {
    self = [super init];
    
    if(self) {
        _remoteFolderName = remoteFolderName;
    }
    
    return self;
}

- (void)start {
    [self startInternal];
}

- (void)cancel {
    [self cancelInternal];
}

- (void)startInternal {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    MCOIMAPSession *session = [[appDelegate model] imapSession];
    NSAssert(session, @"session lost");
    
    MCOIMAPOperation *op = [session expungeOperation:_remoteFolderName];
    
    _currentOp = op;
    
    [op start:^(NSError *error) {
        if(error == nil) {
            NSLog(@"%s: Remote folder %@ successfully expunged", __func__, _remoteFolderName);
            
            SMAppDelegate *appDelegate = [[ NSApplication sharedApplication ] delegate];
            SMMessageListController *messageListController = [[appDelegate model] messageListController];
            
            // TODO: should check if the current folder is the same as expunged one
            
            [messageListController scheduleMessageListUpdate:YES];
            
            [self complete];
        } else {
            NSLog(@"%s: Error expunging remote folder %@: %@", __func__, _remoteFolderName, error);
            
            [self startInternal]; // repeat (TODO)
        }
    }];
}

- (void)cancelInternal {
    [_currentOp cancel];
    _currentOp = nil;
}

@end