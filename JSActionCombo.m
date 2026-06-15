//
//  JSActionCombo.m
//  PadderPro
//

#import "JSActionCombo.h"

@implementation JSActionCombo

@synthesize members, wasActive;

- (id)initWithMembers:(NSArray *)memberActions base:(id)js {
    if (self = [super init]) {
        members = [memberActions copy];
        base = js;
        subActions = nil;
        wasActive = NO;
        prevTriggerHeld = NO;
        prevButtonsHeld = NO;
        tTrigger = 0;
        tButtons = 0;

        // Display name leads with triggers (left before right), then everything
        // else, e.g. "Right Trigger + A Button".
        NSMutableArray *triggerMembers = [NSMutableArray array];
        NSMutableArray *otherMembers = [NSMutableArray array];
        for (id m in members) {
            if ([m isKindOfClass:[JSActionAnalog class]] && [(JSActionAnalog *)m isTrigger])
                [triggerMembers addObject:m];
            else
                [otherMembers addObject:m];
        }
        [triggerMembers sortUsingComparator:^NSComparisonResult(id a, id b) {
            return [@([a index]) compare:@([b index])];
        }];
        NSArray *ordered = [triggerMembers arrayByAddingObjectsFromArray:otherMembers];

        NSMutableArray *names = [NSMutableArray array];
        for (id m in ordered) {
            NSString *label = [[m name] stringByTrimmingCharactersInSet:
                               [NSCharacterSet whitespaceCharacterSet]];
            if ([m isKindOfClass:[SubAction class]])
                label = [NSString stringWithFormat:@"D-pad %@", label]; // hat direction
            [names addObject:label];
        }
        name = [[names componentsJoinedByString:@" + "] copy]; // MRC: own the string
    }
    return self;
}

// Compact per-member tokens used for persistence and the combo's stable key.
- (NSArray *)memberTokens {
    NSMutableArray *tokens = [NSMutableArray array];
    for (id m in members)
        [tokens addObject:[m comboToken]];
    return tokens;
}

- (NSArray *)suppressedSubactions {
    NSMutableArray *subs = [NSMutableArray array];
    for (id m in members)
        [subs addObjectsFromArray:[m suppressibleSubactions]];
    return subs;
}

- (BOOL)containsTriggerIndex:(int)idx {
    for (id m in members)
        if ([m isKindOfClass:[JSActionAnalog class]] &&
            [(JSActionAnalog *)m isTrigger] && [m index] == idx)
            return YES;
    return NO;
}

// Active only when every member is currently held.
- (BOOL)active {
    if ([members count] == 0)
        return NO;
    for (id m in members)
        if (![m isHeld])
            return NO;
    return YES;
}

// Gated evaluation: a combo with trigger(s) only activates if the trigger was pressed
// at roughly the same time as, or after, the buttons were held — not if it was already
// held well beforehand. Uses timestamps (robust to a trigger's analog ramp) rather than
// per-event freshness. Once active, stays active until a member releases.
- (BOOL)evaluateActiveState {
    // How long a trigger may lead the buttons and still count as "together" rather than
    // "already held". Only applies when the trigger is pressed BEFORE the buttons; a
    // button held before the trigger has no time limit.
    static const double kTriggerLeadTolerance = 0.60; // seconds
    double now = CFAbsoluteTimeGetCurrent();

    BOOL hasTrigger = NO;
    BOOL triggerHeld = YES;   // vacuously true if no trigger members
    BOOL buttonsHeld = YES;   // vacuously true if no non-trigger members
    BOOL anyMembers = ([members count] > 0);

    for (id m in members) {
        BOOL isTrig = [m isKindOfClass:[JSActionAnalog class]] && [(JSActionAnalog *)m isTrigger];
        BOOL held = [m isHeld];
        if (isTrig) { hasTrigger = YES; if (!held) triggerHeld = NO; }
        else        { if (!held) buttonsHeld = NO; }
    }

    // Record when each group became fully held (rising edge).
    if (triggerHeld && !prevTriggerHeld) tTrigger = now;
    if (buttonsHeld && !prevButtonsHeld) tButtons = now;
    prevTriggerHeld = triggerHeld;
    prevButtonsHeld = buttonsHeld;

    if (!anyMembers || !triggerHeld || !buttonsHeld)
        return NO;

    // All held. Gating is one-directional and only on the activation edge:
    //   - Button(s) held first, then trigger pressed  -> always allowed (no time limit).
    //   - Trigger held first, then button(s) pressed  -> only allowed if the trigger
    //     became held within kTriggerLeadTolerance of the buttons; a trigger held longer
    //     than that is treated as "already held" and won't pull buttons into the combo.
    if (!wasActive && hasTrigger && (tTrigger < tButtons - kTriggerLeadTolerance))
        return NO;
    return YES;
}

// Combos are evaluated from member state, not driven directly by a single HID value.
- (void)notifyEvent:(IOHIDValueRef)value { }
- (id)findSubActionForValue:(IOHIDValueRef)value { return nil; }

// Stable, unique key: joystick key + sorted member tokens.
// (Button/trigger-only combos keep the same key as before, so existing target
// mappings still resolve; hat directions add "cookie.index" tokens.)
- (NSString *)stringify {
    NSArray *sorted = [[self memberTokens]
        sortedArrayUsingSelector:@selector(compare:)];
    return [[NSString alloc] initWithFormat:@"%@~combo~%@",
            [base stringify], [sorted componentsJoinedByString:@"-"]];
}

@end
