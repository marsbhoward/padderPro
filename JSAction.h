//
//  JSAction.h
//  PadderPro
//
//  Created by Sam McCall on 4/05/09.
//  Copyright 2009 University of Otago. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <IOKit/hid/IOHIDLib.h>

@interface JSAction : NSObject {
	int usage, index;
	void* cookie;
	NSArray* subActions;
	id base;
	NSString* name;
}

@property(readwrite) int usage;
@property(readwrite) void* cookie;
@property(readonly) int index;
@property(readonly) NSArray* subActions;
@property(readwrite, retain) id base;
@property(readwrite, copy) NSString* name;
@property(readonly) BOOL active;

-(void) notifyEvent: (IOHIDValueRef) value;
-(NSString*) stringify;
-(NSArray*) subActions;
-(id) findSubActionForValue: (IOHIDValueRef) value;

// Combo support: whether this input is currently held, and which sub-actions
// (the things that carry per-config targets) should be suppressed when a combo
// containing this input is active.
-(BOOL) isHeld;
-(NSArray*) suppressibleSubactions;
// Compact identifier for combo persistence (a button/trigger is just its cookie).
-(NSString*) comboToken;

@end
