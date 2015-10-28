//
//  SMOpAppendMessage.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/9/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <MailCore/MailCore.h>

#import "SMLog.h"
#import "SMAppDelegate.h"
#import "SMMessageBuilder.h"
#import "SMOpAppendMessage.h"

@implementation SMOpAppendMessage {
    SMMessageBuilder *_messageBuilder;
    NSString *_remoteFolderName;
    MCOMessageFlag _flags;
}

- (id)initWithMessageBuilder:(SMMessageBuilder*)messageBuilder remoteFolderName:(NSString*)remoteFolderName flags:(MCOMessageFlag)flags {
    self = [super initWithKind:kIMAPOpKind];

    if(self) {
        _messageBuilder = messageBuilder;
        _remoteFolderName = remoteFolderName;
        _flags = flags;
    }
    
    return self;
}

- (id)initWithCoder:(NSCoder*)coder {
    self = [super initWithCoder:coder];

    if (self) {
        _messageBuilder = [coder decodeObjectForKey:@"_messageBuilder"];
        _remoteFolderName = [coder decodeObjectForKey:@"_remoteFolderName"];
        _flags = (MCOMessageFlag)[coder decodeIntegerForKey:@"_flags"];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder*)coder {
    [super encodeWithCoder:coder];
    
    [coder encodeObject:_messageBuilder forKey:@"_messageBuilder"];
    [coder encodeObject:_remoteFolderName forKey:@"_remoteFolderName"];
    [coder encodeInteger:_flags forKey:@"_flags"];
}

- (void)start {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    MCOIMAPSession *session = [[appDelegate model] imapSession];
    NSAssert(session, @"session lost");
    
    MCOIMAPAppendMessageOperation *op = [session appendMessageOperationWithFolder:_remoteFolderName messageData:_messageBuilder.mcoMessageBuilder.data flags:_flags customFlags:nil];

    self.currentOp = op;
    
    [op start:^(NSError * error, uint32_t createdUID) {
        NSAssert(self.currentOp != nil, @"current op has disappeared");

        if(error == nil) {
            SM_LOG_DEBUG(@"Message appended to remote folder %@, new uid %u", _remoteFolderName, createdUID);

            if(self.postActionTarget) {
                NSDictionary *messageInfo = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:_messageBuilder.mcoMessageBuilder, [NSNumber numberWithUnsignedInteger:createdUID], nil] forKeys:[NSArray arrayWithObjects:@"Message", @"UID", nil]];
                
                [self.postActionTarget performSelector:self.postActionSelector withObject:messageInfo afterDelay:0];
            }

            [self complete];
        } else {
            SM_LOG_ERROR(@"Error updating flags for remote folder %@: %@", _remoteFolderName, error);
            
            [self fail];
        }
    }];
}

- (NSString*)name {
    return @"Append message";
}

- (NSString*)details {
    return [NSString stringWithFormat:@"Appending message to folder %@", _remoteFolderName];
}

@end
