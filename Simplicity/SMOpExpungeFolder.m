//
//  SMOpExpungeFolder.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/4/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMSimplicityContainer.h"
#import "SMUserAccount.h"
#import "SMMessageListController.h"
#import "SMOperationExecutor.h"
#import "SMOpExpungeFolder.h"

@implementation SMOpExpungeFolder {
    NSString *_remoteFolderName;
}

- (id)initWithRemoteFolder:(NSString*)remoteFolderName operationExecutor:(SMOperationExecutor*)operationExecutor {
    self = [super initWithKind:kIMAPOpKind operationExecutor:operationExecutor];
    
    if(self) {
        _remoteFolderName = remoteFolderName;
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];

    if (self) {
        _remoteFolderName = [coder decodeObjectForKey:@"_remoteFolderName"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    
    [coder encodeObject:_remoteFolderName forKey:@"_remoteFolderName"];
}

- (void)start {
    MCOIMAPSession *session = [[_operationExecutor.account model] imapSession];
    NSAssert(session, @"session lost");
    
    MCOIMAPOperation *op = [session expungeOperation:_remoteFolderName];
    
    self.currentOp = op;
    
    [op start:^(NSError *error) {
        NSAssert(self.currentOp != nil, @"current op has disappeared");
        
        if(error == nil) {
            SM_LOG_DEBUG(@"Remote folder %@ successfully expunged", _remoteFolderName);
            
            SMMessageListController *messageListController = [[_operationExecutor.account model] messageListController];
            
            // TODO: should check if the current folder is the same as expunged one
            
            [messageListController scheduleMessageListUpdate:YES];
            
            [self complete];
        } else {
            SM_LOG_ERROR(@"Error expunging remote folder %@: %@", _remoteFolderName, error);
            
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
