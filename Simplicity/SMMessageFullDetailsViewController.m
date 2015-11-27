//
//  SMMessageFullDetailsViewController.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/2/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMTokenField.h"
#import "SMAddressListElement.h"
#import "SMMessage.h"
#import "SMMessageDetailsViewController.h"
#import "SMMessageFullDetailsView.h"
#import "SMMessageFullDetailsViewController.h"

//static const NSUInteger CONTACT_IMAGE_SIZE = 45;

@implementation SMMessageFullDetailsViewController {
    NSButton *_fromButton;
	NSTextField *_fromLabel;
	NSTokenField *_fromAddress;
	NSTextField *_toLabel;
	NSTokenField *_toAddresses;
	NSTextField *_ccLabel;
	NSTokenField *_ccAddresses;
	NSLayoutConstraint *_toBottomConstraint;
	NSMutableArray *_ccConstraints;
	Boolean _ccCreated;
	Boolean _addressListsFramesValid;
    SMAddressListElement __weak *_addressWithMenu;
    SMMessageThreadCellViewController __weak *_enclosingThreadCell;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	
	if(self) {
		_addressListsFramesValid = NO;
        
		SMMessageFullDetailsView *view = [[SMMessageFullDetailsView alloc] init];
		view.translatesAutoresizingMaskIntoConstraints = NO;

		[view setViewController:self];
		[self setView:view];
		[self createSubviews];
	}
	
	return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setEnclosingThreadCell:(SMMessageThreadCellViewController *)enclosingThreadCell {
    _enclosingThreadCell = enclosingThreadCell;
}

#define V_GAP 10
#define V_GAP_HALF (V_GAP/2)

#define H_GAP 3

- (void)createSubviews {
	NSView *view = [self view];

    // init 'from' button
/*
 
 TODO
 
    _fromButton = [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, CONTACT_IMAGE_SIZE, CONTACT_IMAGE_SIZE)];
    _fromButton.image = [NSImage imageNamed:NSImageNameUserGuest];
    _fromButton.title = @"";
    _fromButton.bezelStyle = NSRegularSquareBezelStyle; // Also works: NSTexturedSquareBezelStyle
    
    [view addSubview:_fromButton];
 
    [view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_fromButton attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_fromButton attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
 */

	// init 'from' label
	
	_fromLabel = [SMMessageDetailsViewController createLabel:@"From:" bold:NO];
	_fromLabel.textColor = [NSColor blackColor];
	
	[view addSubview:_fromLabel];
	
    [view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_fromLabel attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]]; //TODO: -CONTACT_IMAGE_SIZE
	
	[view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_fromLabel attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
	
	// init 'from' address
	
	_fromAddress = [[SMTokenField alloc] init];
	_fromAddress.delegate = self; // TODO: reference loop here?
	_fromAddress.tokenStyle = NSPlainTextTokenStyle;
	_fromAddress.translatesAutoresizingMaskIntoConstraints = NO;
	[_fromAddress setBordered:NO];
	[_fromAddress setDrawsBackground:NO];
    [_fromAddress setEditable:NO];
    [_fromAddress setSelectable:YES];

	[view addSubview:_fromAddress];
	
	[view addConstraint:[NSLayoutConstraint constraintWithItem:_fromLabel attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_fromAddress attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
	
	[view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:_fromAddress attribute:NSLayoutAttributeTop multiplier:1.0 constant:0]];
	
	[view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:_fromAddress attribute:NSLayoutAttributeWidth multiplier:1.0 constant:_fromLabel.frame.size.width]];

	// init 'to' label

	_toLabel = [SMMessageDetailsViewController createLabel:@"To:" bold:NO];
	_toLabel.textColor = [NSColor blackColor];
	
	[view addSubview:_toLabel];
	
    [view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_toLabel attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]]; //TODO: -CONTACT_IMAGE_SIZE
	
	[view addConstraint:[NSLayoutConstraint constraintWithItem:_fromAddress attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_toLabel attribute:NSLayoutAttributeTop multiplier:1.0 constant:-V_GAP_HALF]];
	
	// init 'to' address list
	
	_toAddresses = [[SMTokenField alloc] init];
	_toAddresses.delegate = self; // TODO: reference loop here?
	_toAddresses.tokenStyle = NSPlainTextTokenStyle;
	_toAddresses.translatesAutoresizingMaskIntoConstraints = NO;
	[_toAddresses setBordered:NO];
	[_toAddresses setDrawsBackground:NO];
    [_toAddresses setEditable:NO];
    [_toAddresses setSelectable:YES];

	[view addSubview:_toAddresses];
	
	[view addConstraint:[NSLayoutConstraint constraintWithItem:_toLabel attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_toAddresses attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
	
	[view addConstraint:[NSLayoutConstraint constraintWithItem:_fromAddress attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_toAddresses attribute:NSLayoutAttributeTop multiplier:1.0 constant:-V_GAP_HALF]];
	
	[view addConstraint:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:_toAddresses attribute:NSLayoutAttributeWidth multiplier:1.0 constant:_toLabel.frame.size.width]];
	
	_toBottomConstraint = [NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_toAddresses attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0];

	[view addConstraint:_toBottomConstraint];
}

- (void)createCc {
	if(_ccCreated)
		return;
	
	NSView *view = [self view];

	if(_ccLabel == nil) {
		NSAssert(_ccAddresses == nil, @"cc addresses already created");
		NSAssert(_ccConstraints == nil, @"cc constraints already created");

		// init 'cc' label
		
		_ccLabel = [SMMessageDetailsViewController createLabel:@"Cc:" bold:NO];
		_ccLabel.textColor = [NSColor blackColor];
		
		_ccConstraints = [NSMutableArray array];

		[_ccConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:_ccLabel attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];
		
		[_ccConstraints addObject:[NSLayoutConstraint constraintWithItem:_toAddresses attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_ccLabel attribute:NSLayoutAttributeTop multiplier:1.0 constant:-V_GAP_HALF]];

		// init 'cc' address list
		
		_ccAddresses = [[SMTokenField alloc] init];
		_ccAddresses.delegate = self; // TODO: reference loop here?
		_ccAddresses.tokenStyle = NSPlainTextTokenStyle;
		_ccAddresses.translatesAutoresizingMaskIntoConstraints = NO;
		[_ccAddresses setBordered:NO];
		[_ccAddresses setDrawsBackground:NO];
        [_ccAddresses setEditable:NO];
        [_ccAddresses setSelectable:YES];
		
		[_ccConstraints addObject:[NSLayoutConstraint constraintWithItem:_ccLabel attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:_ccAddresses attribute:NSLayoutAttributeLeft multiplier:1.0 constant:0]];

		[_ccConstraints addObject:[NSLayoutConstraint constraintWithItem:_toAddresses attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_ccAddresses attribute:NSLayoutAttributeTop multiplier:1.0 constant:-V_GAP_HALF]];
		
		[_ccConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:_ccAddresses attribute:NSLayoutAttributeWidth multiplier:1.0 constant:_ccLabel.frame.size.width]];

		[_ccConstraints addObject:[NSLayoutConstraint constraintWithItem:view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:_ccAddresses attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0]];
	}
    else {
		NSAssert(_ccAddresses != nil, @"cc addresses not created");
		NSAssert(_ccConstraints != nil, @"cc constraints not created");
	}
	
	NSAssert(_toBottomConstraint != nil, @"bottom constaint not created");
	[view removeConstraint:_toBottomConstraint];

	[view addSubview:_ccLabel];
	[view addSubview:_ccAddresses];
	[view addConstraints:_ccConstraints];
	
	_ccCreated = YES;
}

- (void)setMessage:(SMMessage*)message {
	[_fromAddress setObjectValue:@[[[SMAddressListElement alloc] initWithMCOAddress:message.fromAddress]]];

    [_toAddresses setObjectValue:[SMAddressListElement mcoAddressesToAddressList:message.toAddressList]];

    if(message.ccAddressList != nil && message.ccAddressList.count != 0) {
        [self createCc];

        [_ccAddresses setObjectValue:[SMAddressListElement mcoAddressesToAddressList:message.ccAddressList]];
    }

	_addressListsFramesValid = NO;
}

- (void)viewDidAppear {
	if(!_addressListsFramesValid) {
		// this is critical because the frame height for each SMTokenField must be
		// recalculated after its width is known, which happens when it is drawn
		// for the first time
		
		[_toAddresses invalidateIntrinsicContentSize];
		[_ccAddresses invalidateIntrinsicContentSize];
		
		_addressListsFramesValid = YES;
	}
}

- (NSSize)intrinsicContentViewSize {
	if(_ccAddresses != nil) {
		return NSMakeSize(-1, [_toAddresses intrinsicContentSize].height + V_GAP_HALF + [_ccAddresses intrinsicContentSize].height);
	} else {
		return NSMakeSize(-1, [_toAddresses intrinsicContentSize].height);
	}
}

- (void)invalidateIntrinsicContentViewSize {
	[[self view] setNeedsUpdateConstraints:YES];
}

#pragma mark - NSTokenFieldDelegate

- (NSTokenStyle)tokenField:(NSTokenField *)tokenField styleForRepresentedObject:(id)representedObject {
	return NSRoundedTokenStyle;
}

- (BOOL)tokenField:(NSTokenField *)tokenField hasMenuForRepresentedObject:(id)representedObject {
	return YES;
}

- (NSMenu *)tokenField:(NSTokenField *)tokenField menuForRepresentedObject:(id)representedObject {
    NSMenu *menu = [[NSMenu alloc] init];

    [menu addItemWithTitle:@"Copy address" action:@selector(copyAddressAction:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Open in address book" action:@selector(openInAddressBookAction:) keyEquivalent:@""];
    [menu addItemWithTitle:@"New message" action:@selector(newMessageAction:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Reply" action:@selector(replyAction:) keyEquivalent:@""];
    
    _addressWithMenu = representedObject;
    
    return menu;
}

- (NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject {
    NSAssert([representedObject isKindOfClass:[SMAddressListElement class]], @"bad kind of object: %@", representedObject);
    
    SMAddressListElement *addressElem = representedObject;
    return [addressElem stringRepresentationDetailed];
}

- (void)copyAddressAction:(NSMenuItem*)menuItem {
    NSAssert(_addressWithMenu != nil, @"_addressWithMenu is nil");

    NSPasteboard *pasteBoard = [NSPasteboard generalPasteboard];
    
    [pasteBoard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [pasteBoard setString:_addressWithMenu.stringRepresentationDetailed forType:NSStringPboardType];
}

- (void)replyAction:(NSMenuItem*)menuItem {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ComposeMessageReply" object:nil userInfo:[NSDictionary dictionaryWithObjectsAndKeys:_enclosingThreadCell, @"ThreadCell", @"Reply", @"ReplyKind", nil]];
}

@end
