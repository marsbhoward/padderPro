//
//  JoystickController.m
//  PadderPro
//
//  Created by Sam McCall on 4/05/09.
//

#import "CoreFoundation/CoreFoundation.h"

@implementation JoystickController

@synthesize joysticks, runningTargets, selectedAction, frontWindowOnly;

-(id) init {
	if(self=[super init]) {
		joysticks = [[NSMutableArray alloc]init];
        runningTargets = [[NSMutableArray alloc]init];
        pendingTaps = [[NSMutableArray alloc]init];
		programmaticallySelecting = NO;
        mouseLoc.x = mouseLoc.y = 0;
	}
	return self;
}

-(void) dealloc {
	for(int i=0; i<[joysticks count]; i++) {
		[[joysticks objectAtIndex:i] invalidate];
	}
	IOHIDManagerClose(hidManager, kIOHIDOptionsTypeNone);
	CFRelease(hidManager);
	[super dealloc];
}

static NSMutableDictionary* create_criterion( UInt32 inUsagePage, UInt32 inUsage )
{
	NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
	[dict setObject: [NSNumber numberWithInt: inUsagePage] forKey: (NSString*)CFSTR(kIOHIDDeviceUsagePageKey)];
	[dict setObject: [NSNumber numberWithInt: inUsage] forKey: (NSString*)CFSTR(kIOHIDDeviceUsageKey)];
	return dict;
} 

-(void) expandRecursive: (id) handler {
	if([handler base])
		[self expandRecursive: [handler base]];
	[outlineView expandItem: handler];
}

BOOL objInArray(NSMutableArray *array, id object) {
    for (id o in array) {
        if (o == object)
            return true;
    }
    return false;
}

void timer_callback(CFRunLoopTimerRef timer, void *ctx) {
    JoystickController *jc = (JoystickController *)ctx;
    jc->mouseLoc = [NSEvent mouseLocation];
    [jc processPendingTaps];
    for (Target *target in [jc runningTargets]) {
        [target update: jc];
    }
}

-(void) applyTarget:(id)target forSubaction:(id)subaction mainAction:(id)mainAction value:(IOHIDValueRef)value {
    if (!target)
        return;
    if ([target running] != [subaction active]) {
        if ([subaction active]) {
            [target trigger: self];
        } else {
            [target untrigger: self];
        }
        [target setRunning: [subaction active]];
    }

    if ([mainAction isKindOfClass: [JSActionAnalog class]]) {
        double realValue = [(JSActionAnalog*)mainAction getRealValue: IOHIDValueGetIntegerValue(value)];
        [target setInputValue: realValue];
    } else if ([mainAction isKindOfClass: [JSActionStick class]]) {
        NSUInteger idx = [[mainAction subActions] indexOfObject:subaction];
        if (idx != NSNotFound) {
            double analogVal = [(JSActionStick *)mainAction analogValueForSubActionIndex:idx];
            [target setInputValue: analogVal];
        }
    }
    // Add any continuous target (including stick subactions) to the update loop
    if ([target isContinuous] && [target running]) {
        if (!objInArray([self runningTargets], target)) {
            [[self runningTargets] addObject: target];
        }
    }
}

-(void) forceUntrigger:(Target*)t {
    if (t && [t running]) {
        [t untrigger:self];
        [t setRunning:NO];
        if (objInArray([self runningTargets], t))
            [[self runningTargets] removeObject:t];
    }
}

// ---- Deferred combo-member individual mappings ------------------------------
// When a button that belongs to a combo is pressed, we don't fire its own mapping
// immediately. We wait a short window: if the combo completes, the press is consumed
// by the combo; otherwise the individual mapping fires (and can then hold normally).

static const double kComboMemberWindow = 0.12; // seconds

-(NSMutableDictionary*) pendingFor:(id)sub {
    for (NSMutableDictionary *e in pendingTaps)
        if (e[@"sub"] == sub) return e;
    return nil;
}
-(void) addPendingFor:(id)sub joystick:(Joystick*)js {
    if ([self pendingFor:sub]) return;
    [pendingTaps addObject:[@{@"sub":sub, @"js":js,
                              @"t":@(CFAbsoluteTimeGetCurrent())} mutableCopy]];
}
-(void) removePendingFor:(id)sub {
    NSMutableDictionary *e = [self pendingFor:sub];
    if (e) [pendingTaps removeObject:e];
}

// Fire a target as a momentary tap (down then up).
-(void) fireTapTarget:(Target*)t {
    if (!t) return;
    [t trigger:self];
    [t untrigger:self];
    [t setRunning:NO];
}
// Begin holding a target (down; stays down until released).
-(void) startTarget:(Target*)t {
    if (!t || [t running]) return;
    [t trigger:self];
    [t setRunning:YES];
    if ([t isContinuous] && !objInArray([self runningTargets], t))
        [[self runningTargets] addObject:t];
}

// Called from the timer: resolve pending combo-member presses whose window elapsed.
-(void) processPendingTaps {
    if ([pendingTaps count] == 0) return;
    double now = CFAbsoluteTimeGetCurrent();
    Config *cfg = [self->configsController currentConfig];
    NSArray *snapshot = [pendingTaps copy];
    for (NSMutableDictionary *e in snapshot) {
        id sub = e[@"sub"];
        Joystick *js = e[@"js"];
        if ([js subactionClaimedByActiveCombo:sub]) {
            [pendingTaps removeObject:e]; // combo consumed it
            continue;
        }
        if (now - [e[@"t"] doubleValue] >= kComboMemberWindow) {
            // No combo formed in time: fire the individual mapping (held).
            [self startTarget:[cfg getTargetForAction:sub]];
            [self startTarget:[cfg getSecondaryTargetForAction:sub]];
            [pendingTaps removeObject:e];
        }
    }
}

// Drive a combo's target from the gated active flag (not [combo active]).
-(void) applyComboTarget:(Target*)t active:(BOOL)active {
    if (!t) return;
    if ([t running] != active) {
        if (active) [t trigger:self];
        else        [t untrigger:self];
        [t setRunning:active];
    }
    if ([t isContinuous] && [t running] && !objInArray([self runningTargets], t))
        [[self runningTargets] addObject:t];
}

// Evaluate this joystick's combos. Applies each combo's own target (active when
// all its member buttons are held) and returns the set of member buttons that are
// suppressed because they belong to an active combo (so their individual mappings
// don't fire). Resumes individual mappings for members whose combo just broke.
-(NSSet*) evaluateCombos:(Joystick*)js value:(IOHIDValueRef)value {
    Config *cfg = [self->configsController currentConfig];
    NSMutableSet *suppressed = [NSMutableSet set];        // sub-actions claimed by active combos

    for (JSActionCombo *combo in [js combos]) {
        BOOL nowActive = [combo evaluateActiveState];
        Target *t = [cfg getTargetForAction:combo];
        Target *s = [cfg getSecondaryTargetForAction:combo];
        [self applyComboTarget:t active:nowActive];
        [self applyComboTarget:s active:nowActive];

        if (nowActive)
            [suppressed addObjectsFromArray:[combo suppressedSubactions]];
        [combo setWasActive:nowActive];
    }

    // Sub-actions claimed by an active combo: cancel any pending tap and force the
    // individual mapping off.
    for (id sub in suppressed) {
        [self removePendingFor:sub];
        [self forceUntrigger:[cfg getTargetForAction:sub]];
        [self forceUntrigger:[cfg getSecondaryTargetForAction:sub]];
    }

    return suppressed;
}

void input_callback(void* inContext, IOReturn inResult, void* inSender, IOHIDValueRef value) {
	JoystickController* self = (JoystickController*)inContext;
	IOHIDDeviceRef device = (IOHIDDeviceRef) inSender;
	
	Joystick* js = [self findJoystickByRef: device];

	// Combo recording mode: accumulate any held buttons/triggers/hat-directions.
	if (self->recordingCombo) {
		JSAction *a = [js actionForEvent: value];
		if (a) {
			[a notifyEvent: value];
			if ([a isKindOfClass:[JSActionHat class]]) {
				for (SubAction *sub in [a subActions])
					if ([sub active]) [self->recordedButtons addObject:sub];
			} else if ([a isHeld]) {
				[self->recordedButtons addObject:a];
			}
		}
		return;
	}

    ApplicationController *app_controller = [[NSApplication sharedApplication] delegate];
	if([app_controller active]) {
		// for reals
		JSAction* mainAction = [js actionForEvent: value];
		if(!mainAction)
			return;

		[mainAction notifyEvent: value];

		// Evaluate combos first; their members are suppressed while a combo is active.
		NSSet *suppressed = [self evaluateCombos:js value:value];

		Config *cfg = [self->configsController currentConfig];
		NSArray* subactions = [mainAction subActions];
		if(!subactions)
			subactions = [NSArray arrayWithObject:mainAction];
		for(id subaction in subactions) {
			if ([suppressed containsObject:subaction])
				continue; // claimed by an active combo (pending already cancelled)

			Target* target = [cfg getTargetForAction:subaction];
			Target* secondary = [cfg getSecondaryTargetForAction:subaction];
			if(!target && !secondary)
				continue;

			// Combo members: defer the individual mapping so a forming combo can claim it.
			if ([js isComboMemberSubaction:subaction]) {
				if ([subaction active]) {
					// Pressed: start the combo-vs-individual window (unless already pending/holding).
					if (![self pendingFor:subaction] && ![target running] && ![secondary running])
						[self addPendingFor:subaction joystick:js];
				} else {
					// Released
					if ([self pendingFor:subaction]) {
						// No combo formed within the window → it was an individual tap.
						[self fireTapTarget:target];
						[self fireTapTarget:secondary];
						[self removePendingFor:subaction];
					} else {
						// Individual was already holding → release it.
						[self forceUntrigger:target];
						[self forceUntrigger:secondary];
					}
				}
				continue;
			}

			// If a mouse-move has a concurrent secondary, delay its movement slightly
			// so the secondary key/button is pressed first.
			if ([target isKindOfClass:[TargetMouseMove class]])
				[(TargetMouseMove*)target setLeadDelay:(secondary != nil)];
			/* target application? doesn't seem to be any need since we are only active when it's in front */
			[self applyTarget:target forSubaction:subaction mainAction:mainAction value:value];
			[self applyTarget:secondary forSubaction:subaction mainAction:mainAction value:value];
		}
	} else if([[NSApplication sharedApplication] isActive] && [[[NSApplication sharedApplication]mainWindow]isVisible]) {
		// joysticks not active, use it to select stuff
		id handler = [js handlerForEvent: value];
		if(!handler)
			return;


		[self expandRecursive: handler];
		self->programmaticallySelecting = YES;
		[self->outlineView selectRowIndexes: [NSIndexSet indexSetWithIndex: [self->outlineView rowForItem: handler]] byExtendingSelection: NO];
	}
}

int findAvailableIndex(id list, Joystick* js) {
	BOOL available;
	Joystick* js2;
	for(int index=0;;index++) {
		available = YES;
		for(int i=0; i<[list count]; i++) {
			js2 = [list objectAtIndex: i];
			if([js2 vendorId] == [js vendorId] && [js2 productId] == [js productId] && [js index] == index) {
				available = NO;
				break;
			}
		}
		if(available)
			return index;
	}
}

void add_callback(void* inContext, IOReturn inResult, void* inSender, IOHIDDeviceRef device) {
	JoystickController* self = (JoystickController*)inContext;
	
	IOHIDDeviceOpen(device, kIOHIDOptionsTypeNone);
	IOHIDDeviceRegisterInputValueCallback(device, input_callback, (void*) self);
	
	Joystick *js = [[Joystick alloc] initWithDevice: device];
	[js setIndex: findAvailableIndex([self joysticks], js)];
	
	[js populateActions];

	[[self joysticks] addObject: js];
	[self->outlineView reloadData];
}
	
-(Joystick*) findJoystickByRef: (IOHIDDeviceRef) device {
	for(int i=0; i<[joysticks count]; i++)
		if([[joysticks objectAtIndex:i] device] == device)
			return [joysticks objectAtIndex:i];
	return NULL;
}	

void remove_callback(void* inContext, IOReturn inResult, void* inSender, IOHIDDeviceRef device) {
	JoystickController* self = (JoystickController*)inContext;
	
	Joystick* match = [self findJoystickByRef: device];
	if(!match)
		return;
				
	[[self joysticks] removeObject: match];

	[match invalidate];
	[self->outlineView reloadData];
}

-(void) setup {
    [outlineView setBackgroundColor:[NSColor controlBackgroundColor]];
    [self addRecordComboButton];

    // Right-click menu for removing a combo
    NSMenu *comboMenu = [[NSMenu alloc] init];
    NSMenuItem *rm = [comboMenu addItemWithTitle:@"Remove Combo"
                                          action:@selector(removeComboPressed:)
                                   keyEquivalent:@""];
    [rm setTarget:self];
    [outlineView setMenu:comboMenu];
    hidManager = IOHIDManagerCreate( kCFAllocatorDefault, kIOHIDOptionsTypeNone);
	NSArray *criteria = [NSArray arrayWithObjects: 
		 create_criterion(kHIDPage_GenericDesktop, kHIDUsage_GD_Joystick),
		 create_criterion(kHIDPage_GenericDesktop, kHIDUsage_GD_GamePad),
         create_criterion(kHIDPage_GenericDesktop, kHIDUsage_GD_MultiAxisController),
         //create_criterion(kHIDPage_GenericDesktop, kHIDUsage_GD_Keyboard),
	nil];
	
	IOHIDManagerSetDeviceMatchingMultiple(hidManager, (CFArrayRef)criteria);
    
	IOHIDManagerScheduleWithRunLoop( hidManager, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode );
	IOReturn tIOReturn = IOHIDManagerOpen( hidManager, kIOHIDOptionsTypeNone );
	(void)tIOReturn;
	
	IOHIDManagerRegisterDeviceMatchingCallback( hidManager, add_callback, (void*)self );
	IOHIDManagerRegisterDeviceRemovalCallback(hidManager, remove_callback, (void*) self);
//	IOHIDManagerRegisterInputValueCallback(hidManager, input_callback, (void*)self);
// register individually so we can find the device more easily
    
    
	
    // Setup timer for continuous targets
    CFRunLoopTimerContext ctx = {
        0, (void*)self, NULL, NULL, NULL
    };
    CFRunLoopTimerRef timer = CFRunLoopTimerCreate(kCFAllocatorDefault,
                                                   CFAbsoluteTimeGetCurrent(), 1.0/80.0,
                                                   0, 0, timer_callback, &ctx);
    CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, kCFRunLoopDefaultMode);
}

-(void) addRecordComboButton {
    // Carve a small strip off the bottom of the controller outline for the button.
    NSScrollView *sv = [outlineView enclosingScrollView];
    NSView *parent = [sv superview];
    if (!sv || !parent) return;
    NSRect f = [sv frame];
    CGFloat barH = 28;
    [sv setFrame:NSMakeRect(f.origin.x, f.origin.y + barH, f.size.width, f.size.height - barH)];

    recordComboButton = [[NSButton alloc] initWithFrame:NSMakeRect(f.origin.x + 2, f.origin.y + 2, 160, 24)];
    [recordComboButton setBezelStyle:NSBezelStyleRounded];
    [recordComboButton setFont:[NSFont systemFontOfSize:11]];
    [recordComboButton setTitle:@"Record Combo"];
    [recordComboButton setTarget:self];
    [recordComboButton setAction:@selector(recordComboPressed:)];
    [recordComboButton setAutoresizingMask:(NSViewMaxXMargin | NSViewMaxYMargin)];
    [parent addSubview:recordComboButton];
}

-(IBAction) recordComboPressed:(id)sender {
    if (!recordingCombo) {
        recordingCombo = YES;
        recordedButtons = [[NSMutableSet alloc] init];
        [recordComboButton setTitle:@"Stop (hold buttons…)"];
        return;
    }

    recordingCombo = NO;
    [recordComboButton setTitle:@"Record Combo"];

    if ([recordedButtons count] >= 2) {
        // Resolve the owning joystick (a hat direction's base is the hat, not the joystick).
        id b = [recordedButtons anyObject];
        while (b && ![b isKindOfClass:[Joystick class]])
            b = [b base];
        Joystick *js = (Joystick*)b;
        NSArray *ordered = [[recordedButtons allObjects] sortedArrayUsingComparator:
            ^NSComparisonResult(id a, id c) {
                return [[a name] compare:[c name]];
            }];
        JSActionCombo *combo = js ? [js addComboWithMembers:ordered] : nil;
        [outlineView reloadData];
        if (combo)
            [self revealComboInOutline:combo joystick:js];
    } else {
        NSAlert *a = [[NSAlert alloc] init];
        [a setMessageText:@"Hold at least two buttons, then click again to record the combo."];
        [a runModal];
    }
    recordedButtons = nil;
}

-(void) revealComboInOutline:(JSActionCombo*)combo joystick:(Joystick*)js {
    [outlineView expandItem:js];
    JSGroup *root = [js combosRoot];
    if (root) {
        [outlineView expandItem:root];
        // The combo is either directly under the Combos root or inside a trigger subgroup.
        for (id child in [root children]) {
            if ([child isKindOfClass:[JSGroup class]] &&
                [[child children] containsObject:combo]) {
                [outlineView expandItem:child];
                break;
            }
        }
    }
    NSInteger row = [outlineView rowForItem:combo];
    if (row >= 0)
        [outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
                 byExtendingSelection:NO];
}

-(IBAction) removeComboPressed:(id)sender {
    NSInteger row = [outlineView clickedRow];
    if (row < 0) row = [outlineView selectedRow];
    if (row < 0) return;
    id item = [outlineView itemAtRow:row];
    if (![item isKindOfClass:[JSActionCombo class]]) return;

    JSActionCombo *combo = (JSActionCombo*)item;
    // Drop its per-config target mappings (primary + concurrent "Also press key").
    NSString *key = [combo stringify];
    NSString *secKey = [key stringByAppendingString:@"~~also"];
    for (Config *cfg in [configsController configs]) {
        [[cfg entries] removeObjectForKey:key];
        [[cfg entries] removeObjectForKey:secKey];
    }
    [[combo base] removeCombo:combo];
    [outlineView reloadData];
    [targetController reset];
}

-(BOOL) validateMenuItem:(NSMenuItem*)menuItem {
    if ([menuItem action] == @selector(removeComboPressed:)) {
        NSInteger row = [outlineView clickedRow];
        if (row < 0) return NO;
        return [[outlineView itemAtRow:row] isKindOfClass:[JSActionCombo class]];
    }
    return YES;
}

-(id) determineSelectedAction {
	id item = [outlineView itemAtRow: [outlineView selectedRow]];
	if(!item)
		return NULL;
	if([item isKindOfClass: [JSGroup class]])
		return NULL;
	if([item isKindOfClass: [JSAction class]] && [item subActions] != NULL)
		return NULL;
	if([item isKindOfClass: [Joystick class]])
		return NULL;
	return item;
}

/* outline view */

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
	if(item == nil)
		return [joysticks count];
	if([item isKindOfClass: [Joystick class]])
		return [[item outlineChildren] count];
	if([item isKindOfClass: [JSGroup class]])
		return [[item children] count];
	if([item isKindOfClass: [JSAction class]] && [item subActions] != NULL)
		return [[item subActions] count];
	return 0;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
	if(item == nil)
		return YES;
	if([item isKindOfClass: [Joystick class]])
		return YES;
	if([item isKindOfClass: [JSGroup class]])
		return YES;
	if([item isKindOfClass: [JSAction class]])
		return [item subActions]==NULL ? NO : YES;
	return NO;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item {
	if(item == nil)
		return [joysticks objectAtIndex: index];

	if([item isKindOfClass: [Joystick class]])
		return [[item outlineChildren] objectAtIndex: index];

	if([item isKindOfClass: [JSGroup class]])
		return [[item children] objectAtIndex: index];

	if([item isKindOfClass: [JSAction class]])
		return [[item subActions] objectAtIndex:index];

	return NULL;
}
- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item  {
	if(item == nil)
		return @"root";
	return [item name];
}

- (void)outlineView:(NSOutlineView *)ov willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)col item:(id)item {
    if ([cell respondsToSelector:@selector(setTextColor:)]) {
        [cell setTextColor:[NSColor labelColor]];
    }
}

- (void)outlineViewSelectionDidChange: (NSNotification*) notification {
	[targetController reset];
	selectedAction = [self determineSelectedAction];
	[targetController load];
	if (programmaticallySelecting) {
		Target *existing = [[configsController currentConfig] getTargetForAction:selectedAction];
		if (!existing)
			[targetController focusKey];
	}
	programmaticallySelecting = NO;
}
	
@end
