//
//  SMOperation.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 6/1/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMOperationExecutor.h"
#import "SMOperation.h"

@implementation SMOperation

- (id)initWithKind:(SMOpKind)kind {
    self = [super init];
    
    if(self) {
        _kind = kind;
        _timeCreated = [NSDate dateWithTimeIntervalSinceNow:0];
    }
    
    return self;
}

- (void)start {
    NSAssert(false, @"start not implemented");
}

- (void)cancel {
    NSAssert(_currentOp != nil, @"no current op");

    [_currentOp cancel];
    _currentOp = nil;
    
    // TODO
}

- (void)fail {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate appController] operationExecutor] failedOperation:self];
}

- (void)complete {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate appController] operationExecutor] completeOperation:self];
}

- (void)enqueue {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate appController] operationExecutor] enqueueOperation:self];
}

- (void)replaceWith:(SMOperation*)op {
    SMAppDelegate *appDelegate = [[NSApplication sharedApplication] delegate];
    [[[appDelegate appController] operationExecutor] replaceOperation:self with:op];
}

- (NSString*)name {
    NSAssert(false, @"not implemented");
    return nil;
}

- (NSString*)details {
    NSAssert(false, @"not implemented");
    return nil;
}

@end
