//
//  SMAddressFieldViewController.h
//  Simplicity
//
//  Created by Evgeny Baskakov on 3/28/15.
//  Copyright (c) 2015 Evgeny Baskakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SMSuggestionProvider.h"
#import "SMLabeledTokenFieldBoxView.h"

@class SMTokenField;

@interface SMAddressFieldViewController : NSViewController<NSTokenFieldDelegate>

@property (strong) IBOutlet SMLabeledTokenFieldBoxView *mainView;

@property IBOutlet NSTextField *label;
@property IBOutlet NSScrollView *scrollView;
@property IBOutlet NSLayoutConstraint *topTokenFieldContraint;
@property IBOutlet NSLayoutConstraint *bottomTokenFieldContraint;

@property (readonly) SMTokenField *tokenField;
@property (readonly) NSButton *controlSwitch;

@property (weak) id<SMSuggestionProvider> suggestionProvider;

@property (readonly, nonatomic) CGFloat contentViewHeight;

- (void)invalidateIntrinsicContentViewSize;
- (void)addControlSwitch:(NSInteger)state target:(id)target action:(SEL)action;

@end
