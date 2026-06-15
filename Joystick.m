//
//  Joystick.m
//  PadderPro
//
//  Created by Sam McCall on 4/05/09.
//

@implementation Joystick


@synthesize	vendorId, productId, productName, name, index, device, children, combos;

// Friendly labels for a standard Xbox-style controller. `number` is the 1-based
// index shown in the UI (e.g. "Button 1"). Returns nil to keep the default name.
static NSString* friendlyButtonName(int number) {
    switch (number) {
        case 1:  return @"A Button";
        case 2:  return @"B Button";
        case 4:  return @"X Button";
        case 5:  return @"Y Button";
        case 7:  return @"LB Button";
        case 8:  return @"RB Button";
        case 11: return @"Select Button";
        case 12: return @"Start Button";
        case 13: return @"Xbox Button";
        case 14: return @"L3 Button";
        case 15: return @"R3 Button";
        case 16: return @"Share Button";
        default: return nil;
    }
}
static NSString* friendlyTriggerName(int number) {
    switch (number) {
        case 1:  return @"Left Trigger";
        case 2:  return @"Right Trigger";
        default: return nil;
    }
}
static NSString* friendlyStickName(int number) {
    switch (number) {
        case 1:  return @"Left Stick";
        case 2:  return @"Right Stick";
        default: return nil;
    }
}
// Xbox HID reports 16 button slots but only 12 are wired; 3/6/9/10 are padding
// with no physical button — hide them from the UI.
static BOOL isUnusedButtonNumber(int number) {
    switch (number) {
        case 3: case 6: case 9: case 10: return YES;
        default: return NO;
    }
}

-(id)initWithDevice: (IOHIDDeviceRef) newDevice {
	if(self=[super init]) {
		children = [[NSMutableArray alloc]init];
		combos   = [[NSMutableArray alloc]init];

		device = newDevice;
		productName = (NSString*)IOHIDDeviceGetProperty( device, CFSTR(kIOHIDProductKey) );
		vendorId = [(NSNumber*)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey)) intValue];
		productId = [(NSNumber*)IOHIDDeviceGetProperty(device, CFSTR(kIOHIDVendorIDKey)) intValue];
		
		name = productName;
	}
	return self;
}

-(void) setIndex: (int) newIndex {
	index = newIndex;
	name = [[NSString alloc] initWithFormat: @"%@ #%d", productName, (index+1)];
}
-(int) index {
	return index;
}

-(void) invalidate {
	IOHIDDeviceClose(device, kIOHIDOptionsTypeNone);
	NSLog(@"Removed a device: %@", [self name]);
}

-(id) base {
	return NULL;
}

-(void) populateActions {
    NSArray *elements = (NSArray *)IOHIDDeviceCopyMatchingElements(device, NULL, kIOHIDOptionsTypeNone);

    int buttons = 0, triggerCount = 0;
    // Buffer bipolar (stick) axes for pairing; triggers are added directly
    NSMutableArray *stickAxisData = [[NSMutableArray alloc] init];
    // Two-pass: first collect stick data, then create sticks.
    // Triggers are created immediately (like buttons) to avoid cookie roundtrip.
    NSMutableArray *triggerActions = [[NSMutableArray alloc] init];

    for (int i = 0; i < [elements count]; i++) {
        IOHIDElementRef element = (IOHIDElementRef)[elements objectAtIndex:i];
        int type      = IOHIDElementGetType(element);
        int usage     = IOHIDElementGetUsage(element);
        int usagePage = IOHIDElementGetUsagePage(element);
        // Use physical min/max for trigger-vs-stick CLASSIFICATION (sticks have negative physical min)
        // Use logical min/max for VALUE NORMALIZATION (IOHIDValueGetIntegerValue returns logical values)
        int physMin   = (int)IOHIDElementGetPhysicalMin(element);
        int physMax   = (int)IOHIDElementGetPhysicalMax(element);
        int logMin    = (int)IOHIDElementGetLogicalMin(element);
        int logMax    = (int)IOHIDElementGetLogicalMax(element);
        CFStringRef elName = IOHIDElementGetName(element);

        // Use logical range for button/size checks (matches actual reported values)
        int rangeSize = logMax - logMin;

        if (!(type == kIOHIDElementTypeInput_Misc || type == kIOHIDElementTypeInput_Axis ||
              type == kIOHIDElementTypeInput_Button))
            continue;

        if ((rangeSize == 1) || usagePage == kHIDPage_Button || type == kIOHIDElementTypeInput_Button) {
            JSActionButton *action = [[JSActionButton alloc] initWithIndex:buttons++ andName:(NSString *)elName];
            [action setMax:logMax];
            [action setBase:self];
            [action setUsage:usage];
            [action setCookie:IOHIDElementGetCookie(element)];
            int number = [action index] + 1;
            NSString *bn = friendlyButtonName(number);
            if (bn) [action setName:bn];
            // Skip unused padding buttons (keeps numbering intact for the rest)
            if (!isUnusedButtonNumber(number))
                [children addObject:action];
        } else if (usage == 0x39 && usagePage == kHIDPage_GenericDesktop) {
            JSActionHat *action = [[JSActionHat alloc] init];
            [action setBase:self];
            [action setUsage:usage];
            [action setCookie:IOHIDElementGetCookie(element)];
            [children addObject:action];
        } else if (rangeSize > 1) {
            // Classify trigger vs stick by usage page + usage code:
            //   Page 0x02 (Simulation Controls) → always trigger (Xbox LT/RT = Brake 0xC5 / Accel 0xC4)
            //   Page 0x01 (Generic Desktop), X/Y/Rx/Ry → always stick
            //   Page 0x01 (Generic Desktop), Z/Rz (0x32/0x35) → trigger if unipolar (logMin==0)
            //   Anything else on page 0x01 → stick
            BOOL likelyTrigger;
            if (usagePage == 0x02) {
                likelyTrigger = YES;
            } else if (usagePage == kHIDPage_GenericDesktop) {
                // Z (0x32) and Rz (0x35) can be triggers on GD page (older controllers)
                // but are also used for right-stick Y on Xbox (Rz, logMax=65535).
                // Distinguish: triggers have small range (logMax <= 4096), sticks have large range.
                BOOL isTriggerUsage = (usage == 0x32 || usage == 0x35);
                likelyTrigger = isTriggerUsage && (logMin == 0) && (logMax <= 4096);
            } else {
                likelyTrigger = NO;
            }

            NSLog(@"[PadderPro] Axis: page=0x%X usage=0x%X physMin=%d logMin=%d logMax=%d cookie=%u → %@",
                  usagePage, usage, physMin, logMin, logMax,
                  (unsigned)IOHIDElementGetCookie(element),
                  likelyTrigger ? @"TRIGGER" : @"stick");

            if (likelyTrigger) {
                JSActionAnalog *action = [[JSActionAnalog alloc] initAsTriggerWithIndex:triggerCount++];
                [action setMax:(double)logMax];
                [action setMin:(double)logMin];
                [action setCookie:IOHIDElementGetCookie(element)];
                [action setBase:self];
                NSString *tn = friendlyTriggerName([action index] + 1);
                if (tn) [action setName:tn];
                [triggerActions addObject:action];
            } else {
                [stickAxisData addObject:@{
                    @"cookie": @((NSUInteger)(uintptr_t)IOHIDElementGetCookie(element)),
                    @"min":    @((double)logMin),
                    @"max":    @((double)logMax),
                    @"usage":  @(usage)
                }];
            }
        }
    }

    // Pair bipolar stick axes into 2D sticks (two at a time)
    int stickIndex = 0;
    for (int i = 0; i + 1 < (int)[stickAxisData count]; i += 2) {
        NSDictionary *xd = stickAxisData[i];
        NSDictionary *yd = stickAxisData[i + 1];
        BOOL rotated = NO;
        NSString *stickName = friendlyStickName(stickIndex + 1);
        if (!stickName)
            stickName = [[NSString alloc] initWithFormat:@"Stick %d", stickIndex + 1];

        JSActionStick *stick = [[JSActionStick alloc]
            initWithIndex:stickIndex
                     name:stickName
                  xCookie:(void *)(uintptr_t)[xd[@"cookie"] unsignedIntegerValue]
                     xMin:[xd[@"min"] doubleValue]
                     xMax:[xd[@"max"] doubleValue]
                  yCookie:(void *)(uintptr_t)[yd[@"cookie"] unsignedIntegerValue]
                     yMin:[yd[@"min"] doubleValue]
                     yMax:[yd[@"max"] doubleValue]
                  rotated:rotated];
        [stick setBase:self];
        [children addObject:stick];
        stickIndex++;
    }

    // Any leftover unpaired stick axis
    if ([stickAxisData count] % 2 != 0) {
        NSDictionary *d = [stickAxisData lastObject];
        JSActionAnalog *action = [[JSActionAnalog alloc] initWithIndex:stickIndex usage:[d[@"usage"] intValue]];
        [action setMax:[d[@"max"] doubleValue]];
        [action setMin:[d[@"min"] doubleValue]];
        [action setCookie:(void *)(uintptr_t)[d[@"cookie"] unsignedIntegerValue]];
        [action setBase:self];
        [children addObject:action];
    }

    // Add trigger actions (already created above)
    for (JSActionAnalog *t in triggerActions)
        [children addObject:t];

    // Recreate any user-defined combos saved for this controller
    [self loadCombos];
}

// ---- Combos -------------------------------------------------------------

-(NSString*) comboDefaultsKey {
    return [NSString stringWithFormat:@"combos~%d~%d", vendorId, productId];
}

// A valid combo member is a button or a trigger (JSActionAnalog), matched by cookie.
-(JSAction*) comboMemberWithCookie:(void*)cookie {
    for (JSAction *action in children)
        if (action.cookie == cookie &&
            ([action isKindOfClass:[JSActionButton class]] ||
             [action isKindOfClass:[JSActionAnalog class]]))
            return action;
    return nil;
}

// Resolve a persisted member token: "cookie" → button/trigger;
// "cookie.index" → the hat's direction sub-action.
-(id) comboMemberForToken:(NSString*)token {
    NSRange dot = [token rangeOfString:@"."];
    if (dot.location != NSNotFound) {
        int cookie = [[token substringToIndex:dot.location] intValue];
        int idx    = [[token substringFromIndex:dot.location + 1] intValue];
        for (JSAction *action in children) {
            if ([action isKindOfClass:[JSActionHat class]] &&
                action.cookie == (void*)(intptr_t)cookie) {
                NSArray *subs = [action subActions];
                if (idx >= 0 && idx < (int)[subs count])
                    return [subs objectAtIndex:idx];
            }
        }
        return nil;
    }
    return [self comboMemberWithCookie:(void*)(intptr_t)[token intValue]];
}

-(JSActionCombo*) addComboWithMembers:(NSArray*)members {
    if ([members count] < 2)
        return nil;
    JSActionCombo *combo = [[JSActionCombo alloc] initWithMembers:members base:self];
    // Avoid duplicates (same member set → same stringify)
    for (JSActionCombo *existing in combos)
        if ([[existing stringify] isEqualToString:[combo stringify]])
            return existing;
    [combos addObject:combo];
    [self rebuildCombosTree];
    [self saveCombos];
    return combo;
}

-(void) removeCombo:(JSActionCombo*)combo {
    [combos removeObject:combo];
    [self rebuildCombosTree];
    [self saveCombos];
}

// Group combos under a "Combos" node, with Left/Right/Dual Trigger subgroups for
// combos that involve triggers. Subgroups only appear when non-empty.
-(void) rebuildCombosTree {
    if (!combosRoot)
        combosRoot = [JSGroup groupNamed:@"Combos"];
    [[combosRoot children] removeAllObjects];

    JSGroup *left = [JSGroup groupNamed:@"Left Trigger"];
    JSGroup *right = [JSGroup groupNamed:@"Right Trigger"];
    JSGroup *dual = [JSGroup groupNamed:@"Dual Trigger"];
    NSMutableArray *ungrouped = [NSMutableArray array]; // no trigger → top level

    for (JSActionCombo *combo in combos) {
        BOOL hasL = [combo containsTriggerIndex:0];
        BOOL hasR = [combo containsTriggerIndex:1];
        if (hasL && hasR)      [[dual children] addObject:combo];
        else if (hasL)         [[left children] addObject:combo];
        else if (hasR)         [[right children] addObject:combo];
        else                   [ungrouped addObject:combo];
    }

    // Sort each bucket alphabetically by name (names lead with the trigger, so this
    // orders by what follows it, e.g. "... + L3 Button" before "... + X Button").
    NSComparator byName = ^NSComparisonResult(id a, id b) {
        return [[a name] localizedCaseInsensitiveCompare:[b name]];
    };
    [ungrouped sortUsingComparator:byName];
    [[left children] sortUsingComparator:byName];
    [[right children] sortUsingComparator:byName];
    [[dual children] sortUsingComparator:byName];

    [[combosRoot children] addObjectsFromArray:ungrouped];
    for (JSGroup *g in @[left, right, dual])
        if ([[g children] count] > 0)
            [[combosRoot children] addObject:g];

    // Cache the set of sub-actions that belong to any combo.
    NSMutableSet *m = [NSMutableSet set];
    for (JSActionCombo *c in combos)
        [m addObjectsFromArray:[c suppressedSubactions]];
    comboMemberSubs = [m copy];
}

-(BOOL) isComboMemberSubaction:(id)sub {
    return [comboMemberSubs containsObject:sub];
}

-(BOOL) subactionClaimedByActiveCombo:(id)sub {
    for (JSActionCombo *c in combos)
        if ([c wasActive] && [[c suppressedSubactions] containsObject:sub])
            return YES;
    return NO;
}

-(JSGroup*) combosRoot { return combosRoot; }

-(NSArray*) outlineChildren {
    if ([combos count] == 0)
        return children;
    return [children arrayByAddingObject:combosRoot];
}

-(void) saveCombos {
    // Persist each combo as an array of its member tokens (strings).
    NSMutableArray *defs = [NSMutableArray array];
    for (JSActionCombo *combo in combos)
        [defs addObject:[combo memberTokens]];
    [[NSUserDefaults standardUserDefaults] setObject:defs forKey:[self comboDefaultsKey]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(void) loadCombos {
    NSArray *defs = [[NSUserDefaults standardUserDefaults] objectForKey:[self comboDefaultsKey]];
    for (NSArray *tokens in defs) {
        NSMutableArray *memberActions = [NSMutableArray array];
        for (id tok in tokens) {
            // Accept both new string tokens and legacy NSNumber cookies.
            NSString *token = [tok isKindOfClass:[NSString class]] ? tok : [tok stringValue];
            id m = [self comboMemberForToken:token];
            if (m) [memberActions addObject:m];
        }
        if ([memberActions count] >= 2) {
            JSActionCombo *combo = [[JSActionCombo alloc] initWithMembers:memberActions base:self];
            [combos addObject:combo];
        }
    }
    [self rebuildCombosTree];
}

- (JSAction*) findActionByCookie: (void*) cookie {
    for (JSAction *action in children) {
        if (action.cookie == cookie)
            return action;
        if ([action isKindOfClass:[JSActionStick class]] &&
            [(JSActionStick *)action secondaryCookie] == cookie)
            return action;
    }
    return NULL;
}

-(NSString*) stringify {
	return [[NSString alloc] initWithFormat: @"%d~%d~%d", vendorId, productId, index];
}

-(id) handlerForEvent: (IOHIDValueRef) value {
	JSAction* mainAction = [self actionForEvent: value];
	if(!mainAction)
		return NULL;
	return [mainAction findSubActionForValue: value];
}
-(JSAction*) actionForEvent: (IOHIDValueRef) value {
	IOHIDElementRef elt = IOHIDValueGetElement(value);
	void* cookie = IOHIDElementGetCookie(elt);
	return [self findActionByCookie: cookie];
}

@end
