//
//  KeyboardPickerWindowController.m
//  PadderPro
//

#import "KeyboardPickerWindowController.h"

// Key definition: keyCode (CGKeyCode), display label, width in units (1 unit = 42px).
// keyCode -1 = spacer (no button).
typedef struct { int code; const char *label; float w; } KD;

static KD kFn[] = {
    {0x35,"Esc",1},{-1,"",0.5},
    {0x7A,"F1",1},{0x78,"F2",1},{0x63,"F3",1},{0x76,"F4",1},{-1,"",0.5},
    {0x60,"F5",1},{0x61,"F6",1},{0x62,"F7",1},{0x64,"F8",1},{-1,"",0.5},
    {0x65,"F9",1},{0x6D,"F10",1},{0x67,"F11",1},{0x6F,"F12",1},
    {0,NULL,0}};

static KD kNum[] = {
    {0x32,"`",1},{0x12,"1",1},{0x13,"2",1},{0x14,"3",1},{0x15,"4",1},{0x17,"5",1},
    {0x16,"6",1},{0x1A,"7",1},{0x1C,"8",1},{0x19,"9",1},{0x1D,"0",1},
    {0x1B,"-",1},{0x18,"=",1},{0x33,"⌫",2},
    {0,NULL,0}};

static KD kTab[] = {
    {0x30,"Tab",1.5},{0x0C,"Q",1},{0x0D,"W",1},{0x0E,"E",1},{0x0F,"R",1},{0x11,"T",1},
    {0x10,"Y",1},{0x20,"U",1},{0x22,"I",1},{0x1F,"O",1},{0x23,"P",1},
    {0x21,"[",1},{0x1E,"]",1},{0x2A,"\\",1.5},
    {0,NULL,0}};

static KD kCaps[] = {
    {0x39,"Caps",1.75},{0x00,"A",1},{0x01,"S",1},{0x02,"D",1},{0x03,"F",1},{0x05,"G",1},
    {0x04,"H",1},{0x26,"J",1},{0x28,"K",1},{0x25,"L",1},{0x29,";",1},{0x27,"'",1},
    {0x24,"Return",2.25},
    {0,NULL,0}};

static KD kShift[] = {
    {0x38,"Shift",2.25},{0x06,"Z",1},{0x07,"X",1},{0x08,"C",1},{0x09,"V",1},
    {0x0B,"B",1},{0x2D,"N",1},{0x2E,"M",1},{0x2B,",",1},{0x2F,".",1},{0x2C,"/",1},
    {0x3C,"Shift",2.75},
    {0,NULL,0}};

static KD kBot[] = {
    {0x3F,"Fn",1},{0x3B,"Ctrl",1.25},{0x3A,"Opt",1.25},{0x37,"Cmd",1.5},
    {0x31,"Space",5.75},
    {0x36,"Cmd",1.5},{0x3D,"Opt",1.25},{0x3E,"Ctrl",1.5},
    {0,NULL,0}};

static KD kNav[] = {
    {0x75,"Del",1.5},{0x73,"Home",1.5},{0x77,"End",1.5},
    {0x74,"PgUp",1.5},{0x79,"PgDn",1.5},{-1,"",1.5},{-1,"",1},
    {0x7E,"↑",1},{-1,"",1},{-1,"",1},{-1,"",1},
    {0,NULL,0}};

static KD kArrows[] = {
    {-1,"",9},{0x7B,"←",1},{0x7D,"↓",1},{0x7C,"→",1},{-1,"",1},{-1,"",1},
    {0,NULL,0}};

@implementation KeyboardPickerWindowController {
    NSMutableSet        *_selected;   // NSNumber (CGKeyCode)
    NSMutableDictionary *_buttons;    // NSNumber -> NSButton
    NSTextField         *_selLabel;
}

@synthesize delegate;

- (instancetype)init {
    NSPanel *panel = [[NSPanel alloc]
        initWithContentRect:NSMakeRect(0,0,900,510)
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskNonactivatingPanel
        backing:NSBackingStoreBuffered
        defer:NO];
    panel.title = @"Select Keys";
    panel.floatingPanel = YES;
    panel.level = NSFloatingWindowLevel;

    self = [super initWithWindow:panel];
    if (!self) return nil;

    _selected = [[NSMutableSet alloc] init];
    _buttons  = [[NSMutableDictionary alloc] init];

    [self buildUI];
    return self;
}

- (void)buildUI {
    NSView *cv = self.window.contentView;
    float unitW = 42.0, keyH = 38.0, rowGap = 4.0;
    float mx = 10.0;
    float y = 380.0; // build top-down, we'll flip: use flipped coords via bottom-up approach

    // Instruction label at top
    NSTextField *hint = [NSTextField labelWithString:
        @"Click to toggle keys. Multiple keys fire in order when the input activates."];
    hint.frame = NSMakeRect(mx, 480, 880, 20);
    hint.font = [NSFont systemFontOfSize:11];
    hint.textColor = [NSColor secondaryLabelColor];
    [cv addSubview:hint];

    // Build rows bottom-up (macOS y=0 is bottom)
    KD *rows[] = {kArrows, kNav, kBot, kShift, kCaps, kTab, kNum, kFn};
    float rowY = 10.0;
    for (int r = 0; r < 8; r++) {
        [self buildRow:rows[r] atY:rowY unitW:unitW keyH:keyH inView:cv leftMargin:mx];
        rowY += keyH + rowGap;
    }

    // Numeric keypad block (right side). Keypad keys have distinct keycodes from the
    // main number row, so they're separate buttons.
    float npX = 700.0;
    KD np1[] = {{0x52,"Num 0",2},{0x41,"Num .",2},{0,NULL,0}};
    KD np2[] = {{0x53,"Num 1",1},{0x54,"Num 2",1},{0x55,"Num 3",1},{0x4C,"Enter",1},{0,NULL,0}};
    KD np3[] = {{0x56,"Num 4",1},{0x57,"Num 5",1},{0x58,"Num 6",1},{0x51,"=",1},{0,NULL,0}};
    KD np4[] = {{0x59,"Num 7",1},{0x5B,"Num 8",1},{0x5C,"Num 9",1},{0x45,"+",1},{0,NULL,0}};
    KD np5[] = {{0x47,"Clear",1},{0x4B,"/",1},{0x43,"*",1},{0x4E,"-",1},{0,NULL,0}};
    KD *npRows[] = {np1, np2, np3, np4, np5};
    float npY = 10.0;
    for (int r = 0; r < 5; r++) {
        [self buildRow:npRows[r] atY:npY unitW:unitW keyH:keyH inView:cv leftMargin:npX];
        npY += keyH + rowGap;
    }
    NSTextField *npLbl = [NSTextField labelWithString:@"Numeric Keypad"];
    npLbl.frame = NSMakeRect(npX, npY + 2, 200, 16);
    npLbl.font = [NSFont systemFontOfSize:10];
    npLbl.textColor = [NSColor secondaryLabelColor];
    [cv addSubview:npLbl];

    // Mouse buttons section label
    NSTextField *mouseLbl = [NSTextField labelWithString:@"Mouse Buttons"];
    mouseLbl.frame = NSMakeRect(mx, rowY + 4, 200, 16);
    mouseLbl.font = [NSFont systemFontOfSize:10];
    mouseLbl.textColor = [NSColor secondaryLabelColor];
    [cv addSubview:mouseLbl];
    rowY += 22;

    // Mouse button row
    KD mouseRow[] = {
        {256, "Left Click",   2.0},
        {257, "Right Click",  2.0},
        {258, "Middle Click", 2.0},
        {259, "Back",         1.5},
        {260, "Forward",      1.5},
        {0, NULL, 0}
    };
    [self buildRow:mouseRow atY:rowY unitW:unitW keyH:keyH inView:cv leftMargin:mx];
    rowY += keyH + rowGap + 6;

    // Selection summary label
    _selLabel = [NSTextField labelWithString:@"No keys selected"];
    _selLabel.frame = NSMakeRect(mx, rowY + 6, 600, 22);
    _selLabel.font = [NSFont systemFontOfSize:13];
    _selLabel.textColor = [NSColor labelColor];
    [cv addSubview:_selLabel];

    // Clear button
    NSButton *clearBtn = [NSButton buttonWithTitle:@"Clear"
        target:self action:@selector(clearPressed:)];
    clearBtn.frame = NSMakeRect(720, rowY + 4, 70, 26);
    [cv addSubview:clearBtn];

    // Done button
    NSButton *doneBtn = [NSButton buttonWithTitle:@"Done"
        target:self action:@selector(donePressed:)];
    doneBtn.frame = NSMakeRect(800, rowY + 4, 80, 26);
    doneBtn.keyEquivalent = @"\r";
    [cv addSubview:doneBtn];
}

- (void)buildRow:(KD *)keys atY:(float)y unitW:(float)unitW keyH:(float)keyH
          inView:(NSView *)view leftMargin:(float)mx {
    float x = mx;
    for (int i = 0; keys[i].label != NULL; i++) {
        float btnW = keys[i].w * unitW - 2;
        if (keys[i].code == -1) { x += keys[i].w * unitW; continue; } // spacer
        NSButton *btn = [NSButton buttonWithTitle:@(keys[i].label)
                                          target:self action:@selector(keyPressed:)];
        btn.frame = NSMakeRect(x, y, btnW, keyH);
        btn.buttonType = NSButtonTypePushOnPushOff;
        btn.bezelStyle = NSBezelStyleSmallSquare;
        btn.font = [NSFont systemFontOfSize:11];
        btn.tag  = keys[i].code;
        [view addSubview:btn];
        _buttons[@(keys[i].code)] = btn;
        x += keys[i].w * unitW;
    }
}

- (void)showWithInitialCodes:(NSArray *)codes {
    [_selected removeAllObjects];
    for (NSNumber *c in codes) [_selected addObject:c];

    // Sync button states
    for (NSNumber *code in _buttons) {
        NSButton *btn = _buttons[code];
        btn.state = [_selected containsObject:code]
            ? NSControlStateValueOn : NSControlStateValueOff;
    }
    [self updateSelectionLabel];
    [self.window center];
    [self.window orderFront:nil];
}

- (void)keyPressed:(NSButton *)btn {
    NSNumber *code = @((CGKeyCode)btn.tag);
    if (btn.state == NSControlStateValueOn)
        [_selected addObject:code];
    else
        [_selected removeObject:code];
    [self updateSelectionLabel];
}

- (void)updateSelectionLabel {
    if (_selected.count == 0) {
        _selLabel.stringValue = @"No keys selected";
        return;
    }
    // Sort by button position (left-to-right, top-to-bottom) via tag scan order
    NSMutableArray *ordered = [NSMutableArray array];
    for (NSNumber *code in _buttons) {
        if ([_selected containsObject:code])
            [ordered addObject:code];
    }
    NSMutableArray *labels = [NSMutableArray array];
    for (NSNumber *code in ordered)
        [labels addObject:[(NSButton *)_buttons[code] title]];
    _selLabel.stringValue = [NSString stringWithFormat:@"Selected: %@",
        [labels componentsJoinedByString:@" + "]];
}

- (void)clearPressed:(id)sender {
    [_selected removeAllObjects];
    for (NSNumber *code in _buttons)
        ((NSButton *)_buttons[code]).state = NSControlStateValueOff;
    [self updateSelectionLabel];
}

- (void)donePressed:(id)sender {
    NSMutableArray *codes  = [NSMutableArray array];
    NSMutableArray *labels = [NSMutableArray array];
    // Preserve insertion order by iterating button layout order
    for (NSNumber *code in _buttons) {
        if ([_selected containsObject:code]) {
            [codes  addObject:code];
            [labels addObject:[(NSButton *)_buttons[code] title]];
        }
    }
    NSString *descr = codes.count ? [labels componentsJoinedByString:@" + "] : @"";
    [self close];
    [self.delegate keyboardPickerDidFinishWithCodes:codes descr:descr];
}

@end
