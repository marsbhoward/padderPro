//
//  ApplicationController.m
//  PadderPro
//
//  Created by Sam McCall on 4/05/09.
//

#import <ApplicationServices/ApplicationServices.h>

@implementation ApplicationController

@synthesize jsController, targetController, configsController;

static BOOL active;

void onUncaughtException(NSException *exception) {
    NSLog(@"Uncaught exception: %@", exception.description);
}

static void sigtermHandler(int sig) {
    // Save configs then let the default handler terminate
    [[[[NSApplication sharedApplication] delegate] configsController] save];
    signal(SIGTERM, SIG_DFL);
    raise(SIGTERM);
}

-(void) applicationDidFinishLaunching: (NSNotification*) notification {
    // Debug: print exceptions
    NSSetUncaughtExceptionHandler(&onUncaughtException);
    signal(SIGTERM, sigtermHandler);

    // Prompt for Accessibility permission (required to synthesize keyboard/mouse events)
    NSDictionary *axOpts = @{(__bridge id)kAXTrustedCheckOptionPrompt: @YES};
    BOOL trusted = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)axOpts);
    NSLog(@"[PadderPro] Accessibility trusted: %d", trusted);

	[jsController setup];
	[targetController setEnabled: false];
	[self setActive: NO];
	[configsController load];

    [[[NSWorkspace sharedWorkspace] notificationCenter]
        addObserver:self
        selector:@selector(activeApplicationChanged:)
        name:NSWorkspaceDidActivateApplicationNotification
        object:nil];
}

-(void) activeApplicationChanged:(NSNotification *)notification {
    NSRunningApplication *app = [notification.userInfo objectForKey:NSWorkspaceApplicationKey];
    pid_t pid = app.processIdentifier;
    [configsController applicationSwitchedTo:app.localizedName withPid:pid];
}

-(void) awakeFromNib {
    if ([[NSProcessInfo processInfo] respondsToSelector:@selector(beginActivityWithOptions:reason:)]) {
        self.activity = [[NSProcessInfo processInfo] beginActivityWithOptions:0x00FFFFFF reason:@"Let joystick commands fire in the background"];
    }
}

-(void) applicationWillTerminate: (NSNotification *)aNotification {
	[configsController save];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication
					 hasVisibleWindows:(BOOL)flag
{	
	[mainWindow makeKeyAndOrderFront:self];
	return YES;
}


-(BOOL) active {
	return active;
}

-(void) setActive: (BOOL) newActive {
	[activeButton setLabel: (newActive ? @"Stop" : @"Start")];
	[activeButton setImage: [NSImage imageNamed: (newActive ? @"NSStopProgressFreestandingTemplate" : @"NSGoRightTemplate" )]];
	[activeMenuItem setState: (newActive ? 1 : 0)];
	active = newActive;
}

-(IBAction) toggleActivity: (id)sender {
	[self setActive: ![self active]];
}

-(void) configsListChanged {
    // Update configs list in File menu
	while([dockMenuBase numberOfItems] > 2)
		[dockMenuBase removeItemAtIndex: ([dockMenuBase numberOfItems] - 1)];

	for(Config* config in [configsController configs]) {
		[dockMenuBase addItemWithTitle:[config name] action:@selector(chooseConfig:) keyEquivalent:@""];
	}
	[self configChanged];
}
-(void) configChanged {
	Config* current = [configsController currentConfig];
	NSArray* configs = [configsController configs];
    if ([dockMenuBase numberOfItems] - 2 != [configs count]) {
        NSLog(@"dockMenuBase has wrong number of items!");
    }
	for(int i=0; i<[configs count]; i++) {
		[[dockMenuBase itemAtIndex: (2+i)] setState: (([configs objectAtIndex:i] == current) ? YES : NO)];
    }
}

-(void) chooseConfig: (id) sender {
	[configsController activateConfig: [[configsController configs] objectAtIndex: ([dockMenuBase indexOfItem: sender]-2)] forPid: 0];
}
@end
