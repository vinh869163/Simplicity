//
//  SMAttachmentsPanelItemView.m
//  Simplicity
//
//  Created by Evgeny Baskakov on 1/24/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import "SMLog.h"
#import "SMAttachmentItem.h"
#import "SMAttachmentsPanelView.h"
#import "SMAttachmentsPanelViewController.h"
#import "SMAttachmentsPanelItemViewController.h"

@implementation SMAttachmentsPanelItemViewController {
	NSTrackingArea *_trackingArea;
	Boolean _hasMouseOver;
}

- (NSColor*)selectedColor {
	return [NSColor selectedControlColor];
}

- (NSColor*)unselectedColor {
	return [NSColor windowBackgroundColor];
}

- (NSColor*)selectedColorWithMouseOver {
	return [[NSColor grayColor] blendedColorWithFraction:0.5 ofColor:[self selectedColor]];
}

- (NSColor*)unselectedWithMouseOverColor {
	return [NSColor grayColor];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	
	if(self) {
		// nothing yet
	}
	
	return self;
}

- (void)viewDidLoad {
	_trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:(NSTrackingInVisibleRect | NSTrackingActiveAlways | NSTrackingMouseEnteredAndExited) owner:self userInfo:nil];
	
	[_box addTrackingArea:_trackingArea];
    
    self.collectionView.minItemSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);
    self.collectionView.maxItemSize = NSMakeSize(self.view.frame.size.width, self.view.frame.size.height);
}

- (SMAttachmentsPanelViewController*)collectionViewController {
    SMAttachmentsPanelView *collectionView = (SMAttachmentsPanelView *)self.collectionView;
    NSAssert([collectionView isKindOfClass:[SMAttachmentsPanelView class]], @"bad collection view type: %@", collectionView.class);

    return collectionView.attachmentsPanelViewController;
}

- (void)setSelected:(BOOL)flag {
	[super setSelected:flag];
 
	NSAssert(_box != nil, @"no box set");

	NSColor *fillColor = flag? (_hasMouseOver? [self selectedColorWithMouseOver] : [self selectedColor]) : (_hasMouseOver? [self unselectedWithMouseOverColor] : [self unselectedColor]);
 
	[_box setFillColor:fillColor];
}

- (void)mouseEntered:(NSEvent *)theEvent {
	NSColor *fillColor = [self isSelected]? [self selectedColorWithMouseOver] : [self unselectedWithMouseOverColor];
 
	[_box setFillColor:fillColor];
	
	_hasMouseOver = YES;
}

- (void)mouseExited:(NSEvent *)theEvent {
	NSColor *fillColor = [self isSelected]? [self selectedColor] : [self unselectedColor];
 
	[_box setFillColor:fillColor];
	
	_hasMouseOver = NO;
}

-(void)mouseDown:(NSEvent *)theEvent {
	[super mouseDown:theEvent];

	if([theEvent clickCount] == 2) {
		SM_LOG_DEBUG(@"double click");
		//[NSApp sendAction:@selector(collectionItemViewDoubleClick:) to:nil from:[self object]];

        SMAttachmentsPanelViewController *panelViewController = [self collectionViewController];
        [panelViewController openAttachment:self.representedObject];
	}
}

- (void)rightMouseDown:(NSEvent *)theEvent {
	[super rightMouseDown:theEvent];
	
    NSMenu *theMenu = [[NSMenu alloc] initWithTitle:@"Contextual Menu"];
    
    if(self.collectionView.selectionIndexes.count > 1) {
        
    }
    else {
        [theMenu insertItemWithTitle:@"Open Attachment" action:@selector(openAttachment) keyEquivalent:@"" atIndex:0];
        [theMenu insertItemWithTitle:@"Save To Downloads" action:@selector(saveAttachmentToDownloads) keyEquivalent:@"" atIndex:1];
        [theMenu insertItemWithTitle:@"Save To..." action:@selector(saveAttachment) keyEquivalent:@"" atIndex:2];
    }

    [NSMenu popUpContextMenu:theMenu withEvent:theEvent forView:self.view];
}

- (void)rightMouseUp:(NSEvent *)theEvent {
	[super rightMouseUp:theEvent];
}

#pragma mark Menu actions

- (void)openAttachment {
    SMAttachmentsPanelViewController *panelViewController = [self collectionViewController];
    [panelViewController openAttachment:self.representedObject];
}

- (void)saveAttachment {
    SMAttachmentsPanelViewController *panelViewController = [self collectionViewController];
    [panelViewController saveAttachment:self.representedObject];
}

- (void)saveAttachmentToDownloads {
    SMAttachmentsPanelViewController *panelViewController = [self collectionViewController];
    [panelViewController saveAttachmentToDownloads:self.representedObject];
}

@end
