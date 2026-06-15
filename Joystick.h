//
//  Joystick.h
//  PadderPro
//
//  Created by Sam McCall on 4/05/09.
//  Copyright 2009 University of Otago. All rights reserved.
//

#import <Cocoa/Cocoa.h>
@class JSAction;
@class JSActionButton;
@class JSActionCombo;
@class JSGroup;

@interface Joystick : NSObject {
	int vendorId;
	int productId;
	int index;
	NSString* productName;
	IOHIDDeviceRef device;
	NSMutableArray* children;
	NSMutableArray* combos;
	JSGroup* combosRoot;
	NSSet* comboMemberSubs;
	NSString* name;
}

@property(readwrite) int vendorId;
@property(readwrite) int productId;
@property(readwrite) int index;
@property(readwrite, copy) NSString* productName;
@property(readwrite) IOHIDDeviceRef device;
@property(readonly) NSArray* children;
@property(readonly) NSArray* combos;
@property(readonly) NSString* name;

-(void) populateActions;
-(void) invalidate;
-(id) handlerForEvent: (IOHIDValueRef) value;
-(id)initWithDevice: (IOHIDDeviceRef) newDevice;
-(JSAction*) actionForEvent: (IOHIDValueRef) value;

-(JSAction*) comboMemberWithCookie: (void*) cookie;
-(id) comboMemberForToken: (NSString*) token;
-(JSActionCombo*) addComboWithMembers: (NSArray*) members;
-(void) removeCombo: (JSActionCombo*) combo;

// Outline children = real actions plus a "Combos" group node when combos exist.
-(NSArray*) outlineChildren;
-(JSGroup*) combosRoot;

// Combo membership helpers (for deferring members' individual mappings).
-(BOOL) isComboMemberSubaction:(id)sub;
-(BOOL) subactionClaimedByActiveCombo:(id)sub;

@end
