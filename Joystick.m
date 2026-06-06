//
//  Joystick.m
//  PadderPro
//
//  Created by Sam McCall on 4/05/09.
//

@implementation Joystick


@synthesize	vendorId, productId, productName, name, index, device, children;

-(id)initWithDevice: (IOHIDDeviceRef) newDevice {
	if(self=[super init]) {
		children = [[NSMutableArray alloc]init];
		
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
        NSString *stickName = [[NSString alloc] initWithFormat:@"Stick %d", stickIndex + 1];

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
