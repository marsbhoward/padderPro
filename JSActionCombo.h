//
//  JSActionCombo.h
//  PadderPro
//
//  A virtual "button" that is active only when all of its member buttons are
//  held simultaneously. Created by the user (record-by-holding), shared across
//  configurations, with a per-config target like any other action.
//

#import "JSAction.h"

@interface JSActionCombo : JSAction {
    NSArray *members;          // JSAction members (buttons and/or triggers) that must all be held
    BOOL     wasActive;        // previous evaluation state (to detect break edge)
    BOOL     prevTriggerHeld;  // were all trigger members held at the previous evaluation
    BOOL     prevButtonsHeld;  // were all non-trigger members held at the previous evaluation
    double   tTrigger;         // time the trigger set last became fully held
    double   tButtons;         // time the non-trigger members last became fully held
}

@property(readonly) NSArray *members;
@property(readwrite) BOOL wasActive;

// `memberActions` are JSAction instances (buttons/triggers); `js` is the owning Joystick.
- (id)initWithMembers:(NSArray *)memberActions base:(id)js;

// Member tokens (strings) for persistence — "cookie" for buttons/triggers,
// "cookie.index" for hat directions.
- (NSArray *)memberTokens;

// Sub-actions that should be suppressed when this combo is active (flattened
// across members — a button is itself; a trigger is its "Pressed" sub-action).
- (NSArray *)suppressedSubactions;

// YES if a member is a trigger (JSActionAnalog) with the given index (0=left, 1=right).
- (BOOL)containsTriggerIndex:(int)idx;

// Evaluate whether the combo should be active this event, applying the rule that a
// trigger only counts if it was freshly pressed to complete the combo (an already-held
// trigger does not pull buttons into a combo). Has side effects (updates internal state);
// call exactly once per input event per combo.
- (BOOL)evaluateActiveState;

@end
