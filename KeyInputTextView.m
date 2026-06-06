//
//  KeyInputTextField.m
//  PadderPro
//

@implementation KeyInputTextView

@synthesize descr, hasKey, vkCodes;

- (void)clear {
    [self setString:@""];
    vkCodes = @[];
    hasKey  = NO;
    descr   = nil;
}

- (void)setVkCodes:(NSArray *)codes descr:(NSString *)d {
    vkCodes = [codes copy];
    descr   = [d copy];
    hasKey  = codes.count > 0;
    [self setString:descr ?: @""];
}

- (BOOL)acceptsFirstResponder { return enabled; }

- (BOOL)becomeFirstResponder {
    [self setBackgroundColor:[NSColor selectedTextBackgroundColor]];
    if (enabled) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!picker) {
                picker = [[KeyboardPickerWindowController alloc] init];
                picker.delegate = self;
            }
            if (!picker.window.isVisible)
                [picker showWithInitialCodes:vkCodes ?: @[]];
        });
    }
    return YES;
}

- (BOOL)resignFirstResponder {
    [self setBackgroundColor:[NSColor textBackgroundColor]];
    return YES;
}

// KeyboardPickerDelegate
- (void)keyboardPickerDidFinishWithCodes:(NSArray *)codes descr:(NSString *)d {
    [self setVkCodes:codes descr:d];
    [[self window] makeFirstResponder:nil];
    [targetController keyChanged];
}

- (void)setEnabled:(BOOL)newEnabled {
    enabled = newEnabled;
    if (!newEnabled && [window firstResponder] == self)
        [window makeFirstResponder:nil];

    NSColor *bg = enabled ? [NSColor textBackgroundColor] : [NSColor textBackgroundColor];
    if (enabled && [window firstResponder] == self)
        bg = [NSColor selectedTextBackgroundColor];
    [self setBackgroundColor:bg];
}

- (BOOL)enabled { return enabled; }

@end
