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
}

- (id)initWithRemoteFolder:(NSString*)remoteFolderName {
    self = [super initWithKind:kIMAPChangeOpKind];
    
    if(self) {
        _remoteFolderName = remoteFolderName;
    }
    
    return self;
}

- (void)start {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    MCOIMAPSession *session = [[appDelegate model] imapSession];
    NSAssert(session, @"session lost");
    
    MCOIMAPOperation *op = [session expungeOperation:_remoteFolderName];
    
    self.currentOp = op;
    
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
            
            [self fail];
        }
    }];
}

- (NSString*)name {
    return @"Expunge folder";
}

- (NSString*)details {
    return [NSString stringWithFormat:@"Expunging folder %@", _remoteFolderName];
}

@end
