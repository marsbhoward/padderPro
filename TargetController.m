//
//  TargetController.m
//  PadderPro
//
//  Created by Sam McCall on 5/05/09.
//

@implementation TargetController

-(void) awakeFromNib {
    // Find the horizontal mouse direction control by tag (42) and wire its action
    mouseHorizDirSelect = (NSSegmentedControl *)[[mouseDirSelect superview] viewWithTag:42];
    [mouseHorizDirSelect setTarget:self];
    [mouseHorizDirSelect setAction:@selector(mhorizChanged:)];

    // Add speed label + slider below the scroll dir control (y=84) in the right column
    NSView *panel = [mouseDirSelect superview];

    speedLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(227, 62, 50, 17)];
    [speedLabel setStringValue:@"Speed:"];
    [speedLabel setBezeled:NO];
    [speedLabel setDrawsBackground:NO];
    [speedLabel setEditable:NO];
    [speedLabel setSelectable:NO];
    [speedLabel setFont:[NSFont systemFontOfSize:11]];
    [panel addSubview:speedLabel];

    speedSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(278, 59, 129, 20)];
    [speedSlider setMinValue:1];
    [speedSlider setMaxValue:10];
    [speedSlider setIntValue:3];
    [speedSlider setNumberOfTickMarks:10];
    [speedSlider setAllowsTickMarkValuesOnly:YES];
    [speedSlider setTarget:self];
    [speedSlider setAction:@selector(speedChanged:)];
    [panel addSubview:speedSlider];

    // Concurrent key press: fires alongside whatever primary target is selected above.
    secondaryKeyCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(227, 36, 150, 18)];
    [secondaryKeyCheckbox setButtonType:NSSwitchButton];
    [secondaryKeyCheckbox setTitle:@"Also press key"];
    [secondaryKeyCheckbox setTarget:self];
    [secondaryKeyCheckbox setAction:@selector(secondaryKeyToggled:)];
    [panel addSubview:secondaryKeyCheckbox];

    secondaryKeyButton = [[NSButton alloc] initWithFrame:NSMakeRect(247, 10, 160, 24)];
    [secondaryKeyButton setBezelStyle:NSBezelStyleRounded];
    [secondaryKeyButton setTitle:@"Choose key…"];
    [secondaryKeyButton setTarget:self];
    [secondaryKeyButton setAction:@selector(chooseSecondaryKey:)];
    [secondaryKeyButton setEnabled:NO];
    [panel addSubview:secondaryKeyButton];
}

-(IBAction)secondaryKeyToggled:(id)sender {
    BOOL on = ([secondaryKeyCheckbox state] == NSOnState);
    [secondaryKeyButton setEnabled:on];
    if (on && (!secondaryVkCodes || [secondaryVkCodes count] == 0)) {
        // No key chosen yet — open the picker right away
        [self chooseSecondaryKey:sender];
    } else {
        [self commit];
    }
}

-(IBAction)chooseSecondaryKey:(id)sender {
    if (!secondaryPicker) {
        secondaryPicker = [[KeyboardPickerWindowController alloc] init];
        secondaryPicker.delegate = self;
    }
    [secondaryPicker showWithInitialCodes:secondaryVkCodes ?: @[]];
}

// KeyboardPickerDelegate (for the secondary/concurrent key)
-(void)keyboardPickerDidFinishWithCodes:(NSArray *)codes descr:(NSString *)d {
    secondaryVkCodes = [codes copy];
    secondaryDescr   = [d copy];
    [secondaryKeyButton setTitle:(d.length ? d : @"Choose key…")];
    [secondaryKeyCheckbox setState:NSOnState];
    [secondaryKeyButton setEnabled:YES];
    [self commit];
}

-(void) keyChanged {
	[radioButtons setState: 1 atRow: 1 column: 0 ];
	[self commit];
}
-(IBAction)radioChanged:(id)sender {
	[[[NSApplication sharedApplication] mainWindow] makeFirstResponder: sender];
	[self commit];
}
-(IBAction)mdirChanged:(id)sender {
    [radioButtons setState: 1 atRow: 3 column: 0];
	[[[NSApplication sharedApplication] mainWindow] makeFirstResponder: sender];
	[self commit];
}
-(IBAction)speedChanged:(id)sender {
    [self commit];
}

-(IBAction)mhorizChanged:(id)sender {
    mouseHorizDirSelect = (NSSegmentedControl *)sender;
    [radioButtons setState: 1 atRow: 4 column: 0];
	[[[NSApplication sharedApplication] mainWindow] makeFirstResponder: sender];
	[self commit];
}
-(IBAction)mbtnChanged:(id)sender {
    [radioButtons setState: 1 atRow: 5 column: 0];
	[[[NSApplication sharedApplication] mainWindow] makeFirstResponder: sender];
	[self commit];
}
-(IBAction)sdirChanged:(id)sender {
    [radioButtons setState: 1 atRow: 6 column: 0];
	[[[NSApplication sharedApplication] mainWindow] makeFirstResponder: sender];
	[self commit];
}


-(Target*) state {
	switch([radioButtons selectedRow]) {
		case 0: // none
			return NULL;
		case 1: // key
			if([keyInput hasKey]) {
				TargetKeyboard* k = [[TargetKeyboard alloc] init];
				[k setVkCodes: [keyInput vkCodes]];
				[k setDescr: [keyInput descr]];
				return k;
			}
			break;
		case 2:
		{
			TargetConfig* c = [[TargetConfig alloc] init];
			[c setConfig: [[configsController configs] objectAtIndex: [configPopup indexOfSelectedItem]]];
			return c;
		}
        case 3: {
            TargetMouseMove *mm = [[TargetMouseMove alloc] init];
            [mm setDir: [mouseDirSelect selectedSegment]];
            [mm setSpeed: [speedSlider intValue]];
            return mm;
        }
        case 4: {
            TargetMouseMove *mm = [[TargetMouseMove alloc] init];
            [mm setDir: ([mouseHorizDirSelect selectedSegment] == 0 ? 2 : 3)];
            [mm setSpeed: [speedSlider intValue]];
            return mm;
        }
        case 5: {
            // mouse button
            TargetMouseBtn *mb = [[TargetMouseBtn alloc] init];
            if ([mouseBtnSelect selectedSegment] == 0) {
                [mb setWhich: kCGMouseButtonLeft];
            }
            else {
                [mb setWhich: kCGMouseButtonRight];
            }
            return mb;
        }
        case 6: {
            // scroll
            TargetMouseScroll *ms = [[TargetMouseScroll alloc] init];
            if ([scrollDirSelect selectedSegment] == 0) {
                [ms setHowMuch: -1];
            }
            else {
                [ms setHowMuch: 1];
            }
            return ms;
        }
        case 7: {
            // toggle mouse scope
            TargetToggleMouseScope *tms = [[TargetToggleMouseScope alloc] init];
            return tms;
        }
	}
	return NULL;
}

-(void)configChosen:(id)sender {
	[radioButtons setState: 1 atRow: 2 column: 0];
	[self commit];
}

-(void) commit {
	id action = [joystickController selectedAction];
	if(action) {
		Target* target = [self state];
		[[configsController currentConfig] setTarget: target forAction: action];

        // Concurrent "Also press key" target
        Target *secondary = NULL;
        if ([secondaryKeyCheckbox state] == NSOnState &&
            secondaryVkCodes && [secondaryVkCodes count] > 0) {
            TargetKeyboard *k = [[TargetKeyboard alloc] init];
            [k setVkCodes:secondaryVkCodes];
            [k setDescr:secondaryDescr];
            secondary = k;
        }
        [[configsController currentConfig] setSecondaryTarget:secondary forAction:action];
	}
}

-(void) reset {
	[keyInput clear];
	[radioButtons setState: 1 atRow: 0 column: 0];
    [mouseDirSelect setSelectedSegment: 0];
    [mouseHorizDirSelect setSelectedSegment: 0];
    [speedSlider setIntValue: 3];
    [mouseBtnSelect setSelectedSegment: 0];
    [scrollDirSelect setSelectedSegment: 0];
    secondaryVkCodes = nil;
    secondaryDescr = nil;
    [secondaryKeyCheckbox setState: NSOffState];
    [secondaryKeyButton setTitle: @"Choose key…"];
    [secondaryKeyButton setEnabled: NO];
	[self refreshConfigsPreservingSelection: NO];
}

-(void) setEnabled: (BOOL) enabled {
	[radioButtons setEnabled: enabled];
	[keyInput setEnabled: enabled];
	[configPopup setEnabled: enabled];
    [mouseDirSelect setEnabled: enabled];
    [mouseHorizDirSelect setEnabled: enabled];
    [mouseBtnSelect setEnabled: enabled];
    [scrollDirSelect setEnabled: enabled];
    [secondaryKeyCheckbox setEnabled: enabled];
    [secondaryKeyButton setEnabled: (enabled && [secondaryKeyCheckbox state] == NSOnState)];
}
-(BOOL) enabled {
	return [radioButtons isEnabled];
}

-(void) load {
	id jsaction = [joystickController selectedAction];
	currentJsaction = jsaction;
	if(!jsaction) {
		[self setEnabled: NO];
		[title setStringValue: @""];
		return;
	} else {
		[self setEnabled: YES];
	}
	Target* target = [[configsController currentConfig] getTargetForAction: jsaction];
	
	id act = jsaction;
	NSString* actFullName = [act name];
	while([act base]) {
		act = [act base];
		actFullName = [[NSString alloc] initWithFormat: @"%@ > %@", [act name], actFullName];
	}
	[title setStringValue: [[NSString alloc] initWithFormat: @"%@ > %@", [[configsController currentConfig] name], actFullName]];
	
	if(!target) {
		// already reset
	} else if([target isKindOfClass: [TargetKeyboard class]]) {
		[radioButtons setState:1 atRow: 1 column: 0];
		[keyInput setVkCodes:[(TargetKeyboard*)target vkCodes]
                       descr:[(TargetKeyboard*)target descr]];
	} else if([target isKindOfClass: [TargetConfig class]]) {
		[radioButtons setState:1 atRow: 2 column: 0];
		[configPopup selectItemAtIndex: [[configsController configs] indexOfObject: [(TargetConfig*)target config]]];
    }
    else if ([target isKindOfClass: [TargetMouseMove class]]) {
        int dir = [(TargetMouseMove *)target dir];
        [speedSlider setIntValue: [(TargetMouseMove *)target speed]];
        if (dir == 2 || dir == 3) {
            [radioButtons setState:1 atRow: 4 column: 0];
            [mouseHorizDirSelect setSelectedSegment: (dir == 2 ? 0 : 1)];
        } else {
            [radioButtons setState:1 atRow: 3 column: 0];
            [mouseDirSelect setSelectedSegment: dir];
        }
	}
    else if ([target isKindOfClass: [TargetMouseBtn class]]) {
        [radioButtons setState: 1 atRow: 5 column: 0];
        if ([(TargetMouseBtn *)target which] == kCGMouseButtonLeft)
            [mouseBtnSelect setSelectedSegment: 0];
        else
            [mouseBtnSelect setSelectedSegment: 1];
    }
    else if ([target isKindOfClass: [TargetMouseScroll class]]) {
        [radioButtons setState: 1 atRow: 6 column: 0];
        if ([(TargetMouseScroll *)target howMuch] < 0)
            [scrollDirSelect setSelectedSegment: 0];
        else
            [scrollDirSelect setSelectedSegment: 1];
    }
    else if ([target isKindOfClass: [TargetToggleMouseScope class]]) {
        [radioButtons setState: 1 atRow: 7 column: 0];
    } else {
		[NSException raise:@"Unknown target subclass" format:@"Unknown target subclass"];
	}

    // Restore the concurrent "Also press key" target, if any
    Target *sec = [[configsController currentConfig] getSecondaryTargetForAction:jsaction];
    if (sec && [sec isKindOfClass:[TargetKeyboard class]]) {
        secondaryVkCodes = [[(TargetKeyboard*)sec vkCodes] copy];
        secondaryDescr   = [[(TargetKeyboard*)sec descr] copy];
        [secondaryKeyCheckbox setState: NSOnState];
        [secondaryKeyButton setTitle:(secondaryDescr.length ? secondaryDescr : @"Choose key…")];
        [secondaryKeyButton setEnabled: YES];
    }
}

-(void) focusKey {
	[[[NSApplication sharedApplication] mainWindow] makeFirstResponder: keyInput];
}

-(void) refreshConfigsPreservingSelection: (BOOL) preserve  {
	int initialIndex = [configPopup indexOfSelectedItem];
	
	NSArray* configs = [configsController configs];
	[configPopup removeAllItems];
	for(int i=0; i<[configs count]; i++) {
		[configPopup addItemWithTitle: [[configs objectAtIndex:i]name]];
	}
	if(preserve)
		[configPopup selectItemAtIndex:initialIndex];
		
}

@end
