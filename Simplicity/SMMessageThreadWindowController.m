//
//  SMMessageThreadWindowController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 8/15/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMAppDelegate.h"
#import "SMAppController.h"
#import "SMFlippedView.h"
#import "SMMessageThread.h"
#import "SMMessageThreadViewController.h"
#import "SMMessageThreadWindowController.h"

@implementation SMMessageThreadWindowController

- (void)windowWillLoad {
    [super windowWillLoad];
    
    [self setShouldCascadeWindows:YES];
}

- (void)windowDidLoad {
    [super windowDidLoad];

    // Delegate setup

    [[self window] setDelegate:self];
    
    NSView *view = [[SMFlippedView alloc] initWithFrame:[[self window] frame]];
    view.translatesAutoresizingMaskIntoConstraints = YES;
    [[self window] setContentView:view];
    
    _messageThreadViewController = [[SMMessageThreadViewController alloc] initWithNibName:nil bundle:nil];
    NSAssert(_messageThreadViewController, @"_messageThreadViewController");
    
    NSView *messageThreadView = [_messageThreadViewController view];
    NSAssert(messageThreadView, @"messageThreadView");
    
    messageThreadView.translatesAutoresizingMaskIntoConstraints = YES;

    [view addSubview:messageThreadView];
    
    messageThreadView.frame = view.frame;
    messageThreadView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    NSAssert(_messageThread != nil, @"_messageThread is nil");
    NSAssert(_localFolder != nil, @"_localFolder is nil");
    
    [_messageThreadViewController setMessageThread:_messageThread selectedThreadsCount:1 localFolder:_localFolder];
}

- (void)windowWillClose:(NSNotification *)notification {
    [_messageThreadViewController messageThreadViewWillClose];

    SMAppDelegate *appDelegate = (SMAppDelegate *)[[NSApplication sharedApplication] delegate];
    SMAppController *appController = appDelegate.appController;
    
    [appController unregisterMessageThreadWindow:self];
}

@end
