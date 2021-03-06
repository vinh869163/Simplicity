//
//  SMToken.h
//  CustomTokenField
//
//  Created by Evgeny Baskakov on 2/11/16.
//  Copyright © 2016 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SMTokenEditView;
@class SMTokenFieldViewController;

@interface SMTokenView : NSView

@property (readonly) NSString *tokenName;
@property (readonly) NSString *contentsText;
@property (readonly) NSObject *representedObject;
@property (readonly) id target;
@property (readonly) SEL action;
@property (readonly) SEL editedAction;
@property (readonly) SEL deletedAction;

@property (nonatomic) BOOL selected;
@property (nonatomic) SMTokenEditView *editorView;

+ (SMTokenView*)createToken:(NSString*)tokenName contentsText:(NSString*)contentsText representedObject:(NSObject*)representedObject target:(id)target action:(SEL)action editedAction:(SEL)editedAction deletedAction:(SEL)deletedAction viewController:(SMTokenFieldViewController*)viewController;

- (void)triggerEditedAction;
- (void)triggerDeletedAction;

@end
