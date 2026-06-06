//
//  JSActionAnalog.m
//  PadderPro
//

@implementation JSActionAnalog

- (id) initWithIndex:(int)newIndex usage:(int)usage {
    if (self = [super init]) {
        NSString *lowName, *highName;
        switch (usage) {
            case 0x30: case 0x33: case 0x35: lowName = @"Left";  highName = @"Right"; break;
            case 0x31: case 0x34:            lowName = @"Up";    highName = @"Down";  break;
            case 0x32:                       lowName = @"Down";  highName = @"Up";    break;
            default:                         lowName = @"Low";   highName = @"High";  break;
        }
        subActions = [NSArray arrayWithObjects:
            [[SubAction alloc] initWithIndex:0 name:lowName  base:self],
            [[SubAction alloc] initWithIndex:1 name:highName base:self],
            [[SubAction alloc] initWithIndex:2 name:@"Analog" base:self],
            nil];
        [subActions retain];
        index = newIndex;
        name = [[NSString alloc] initWithFormat:@"Axis %d", (index + 1)];
        analogThreshold    = 0.1;
        discreteThreshold  = 0.3;
        isTrigger = NO;
    }
    return self;
}

- (id) initAsTriggerWithIndex:(int)newIndex {
    if (self = [super init]) {
        subActions = [NSArray arrayWithObjects:
            [[SubAction alloc] initWithIndex:0 name:@"Pressed" base:self],
            nil];
        [subActions retain];
        index = newIndex;
        name = [[NSString alloc] initWithFormat:@"Trigger %d", (newIndex + 1)];
        analogThreshold   = 0.1;
        discreteThreshold = 0.3;
        isTrigger = YES;
    }
    return self;
}

- (id) findSubActionForValue:(IOHIDValueRef)value {
    int raw = IOHIDValueGetIntegerValue(value);
    double parsed = [self getRealValue:raw];

    if (isTrigger) {
        // Trigger rests at -1.0; fire "Pressed" when >30% depressed
        if (parsed > -1.0 + 2.0 * discreteThreshold)
            return [subActions objectAtIndex:0];
        return NULL;
    }

    if ([[subActions objectAtIndex:2] active])
        return (fabs(parsed) < analogThreshold) ? NULL : [subActions objectAtIndex:2];

    if (parsed < -discreteThreshold) return [subActions objectAtIndex:0];
    if (parsed >  discreteThreshold) return [subActions objectAtIndex:1];
    return NULL;
}

- (void) notifyEvent:(IOHIDValueRef)value {
    int raw = IOHIDValueGetIntegerValue(value);
    double parsed = [self getRealValue:raw];

    if (isTrigger) {
        BOOL pressed = (parsed > -1.0 + 2.0 * discreteThreshold);
        [[subActions objectAtIndex:0] setActive:pressed];
        return;
    }

    [[subActions objectAtIndex:2] setActive:(fabs(parsed) > analogThreshold)];
    [[subActions objectAtIndex:0] setActive:(parsed < -discreteThreshold)];
    [[subActions objectAtIndex:1] setActive:(parsed > discreteThreshold)];
}

- (double) getRealValue:(int)value {
    return -1.0 + 2.0 * (value - min - 0.5) / (max - min);
}

@synthesize min, max, discreteThreshold, analogThreshold;

@end
