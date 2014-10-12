//
//  SMMessageDetailsViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 5/11/14.
//  Copyright (c) 2014 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMMessage;

@interface SMMessageDetailsViewController : NSViewController<NSTokenFieldDelegate>

- (void)setMessageDetails:(SMMessage*)message;
- (NSSize)intrinsicContentViewSize;
- (void)invalidateIntrinsicContentViewSize;

@end
