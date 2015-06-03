//
//  SMOperationQueue.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/2/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SMOperation;

@interface SMOperationQueue : NSObject

- (void)putOp:(SMOperation*)op;
- (void)popFirstOp;
- (void)replaceFirstOp:(SMOperation*)op;
- (SMOperation*)getFirstOp;
- (NSUInteger)getQueueSize;

@end
