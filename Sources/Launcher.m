// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import "GameProfile.h"
#import "GameAdapter.h"
#import "OverlaySettings.h"
#import "SelectionSettings.h"
#import "DemoHost.h"
#import "TrainerMaterial.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
static NSColor *CDAccent(void) {return [NSColor colorWithSRGBRed:1 green:0.43 blue:0.08 alpha:1];}
static NSTextField *CDText(NSString *text,CGFloat size,NSFontWeight weight,NSColor *color) {
    NSTextField *label=[NSTextField labelWithString:text];label.font=[NSFont systemFontOfSize:size weight:weight];label.textColor=color;return label;
}
static void CDAdd(NSView *parent,NSView *child) {child.translatesAutoresizingMaskIntoConstraints=NO;[parent addSubview:child];}
@interface CDLauncherBackground : NSView
@end
@implementation CDLauncherBackground
- (BOOL)isOpaque {return YES;}
- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSGradient *gradient=[[NSGradient alloc]initWithStartingColor:[NSColor colorWithSRGBRed:0.075 green:0.079 blue:0.09 alpha:1] endingColor:[NSColor colorWithSRGBRed:0.145 green:0.125 blue:0.115 alpha:1]];
    [gradient drawInRect:self.bounds angle:90];
    [[CDAccent() colorWithAlphaComponent:0.45] setFill];NSRectFill(NSMakeRect(24,self.bounds.size.height-1,self.bounds.size.width-48,1));
}
@end

@interface MTLauncher : NSObject <NSApplicationDelegate>
@property(nonatomic) NSWindow *window;
@property(nonatomic) NSDictionary *configuration;
@property(nonatomic) NSPopUpButton *profiles;
@property(nonatomic) NSTextField *status;
@property(nonatomic) NSTextField *installationPath;
@property(nonatomic) NSImageView *statusGlyph;
@property(nonatomic) NSButton *start;
@property(nonatomic) NSButton *showOverlay;
@property(nonatomic) NSButton *restoreCheats;
@property(nonatomic) NSTextField *restoreHint;
@property(nonatomic) NSRunningApplication *game;
@property(nonatomic,copy) NSString *session;
@property(nonatomic,copy) NSString *launchedProfileID;
@property(nonatomic) id settingsObserver;
@property(nonatomic) id selectionObserver;
@end
@implementation MTLauncher
- (NSDictionary *)profile {return self.configuration[@"profiles"][self.profiles.indexOfSelectedItem];}
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    NSError *error=nil;self.configuration=MTLoadConfiguration([NSBundle.mainBundle pathForResource:@"TrainerConfig" ofType:@"json"],&error);
    if(!self.configuration){NSAlert *a=[NSAlert new];a.messageText=error.localizedDescription;[a runModal];[NSApp terminate:nil];return;}
    self.window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,720,620) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable backing:NSBackingStoreBuffered defer:NO];self.window.releasedWhenClosed=NO;self.window.title=self.configuration[@"app"][@"name"];
    self.window.appearance=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    self.window.titlebarAppearsTransparent=NO;self.window.titleVisibility=NSWindowTitleVisible;
    self.window.opaque=YES;self.window.backgroundColor=[NSColor colorWithSRGBRed:0.09 green:0.09 blue:0.10 alpha:1];
    self.window.contentView=[[CDLauncherBackground alloc]initWithFrame:self.window.contentView.bounds];

    NSView *hero=[NSView new];
    NSImageView *icon=[NSImageView new];icon.image=[[NSImage alloc]initWithContentsOfFile:[NSBundle.mainBundle pathForResource:@"AppIcon" ofType:@"icns"]];icon.imageScaling=NSImageScaleProportionallyUpOrDown;icon.accessibilityLabel=@"Crimson Desert Trainer";
    NSTextField *brand=CDText(@"CRIMSON DESERT",25,NSFontWeightBold,CDAccent());
    NSTextField *title=CDText(@"TRAINER",21,NSFontWeightSemibold,NSColor.labelColor);
    NSTextField *subtitle=CDText(@"Plus 12 · Steam für macOS",13,NSFontWeightMedium,NSColor.secondaryLabelColor);
    NSTextField *features=CDText(@"Leben · Kampf · Inventar · Spielwelt",12,NSFontWeightRegular,NSColor.secondaryLabelColor);
    for(NSView *view in @[icon,brand,title,subtitle,features])CDAdd(hero,view);
    [NSLayoutConstraint activateConstraints:@[
        [hero.heightAnchor constraintEqualToConstant:132],
        [icon.leadingAnchor constraintEqualToAnchor:hero.leadingAnchor],
        [icon.topAnchor constraintEqualToAnchor:hero.topAnchor],
        [icon.widthAnchor constraintEqualToConstant:132],[icon.heightAnchor constraintEqualToConstant:132],
        [brand.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:24],[brand.topAnchor constraintEqualToAnchor:hero.topAnchor constant:15],
        [title.leadingAnchor constraintEqualToAnchor:brand.leadingAnchor],[title.topAnchor constraintEqualToAnchor:brand.bottomAnchor constant:2],
        [subtitle.leadingAnchor constraintEqualToAnchor:brand.leadingAnchor],[subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:9],
        [features.leadingAnchor constraintEqualToAnchor:brand.leadingAnchor],[features.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:5],
        [brand.trailingAnchor constraintLessThanOrEqualToAnchor:hero.trailingAnchor]]];

    self.profiles=[[NSPopUpButton alloc]initWithFrame:NSZeroRect pullsDown:NO];for(NSDictionary *p in self.configuration[@"profiles"])[self.profiles addItemWithTitle:p[@"name"]];self.profiles.target=self;self.profiles.action=@selector(refresh:);self.profiles.controlSize=NSControlSizeLarge;self.profiles.font=[NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
    NSTextField *section=CDText(@"SPIELPROFIL",10,NSFontWeightSemibold,NSColor.secondaryLabelColor);
    self.installationPath=CDText(@"",11,NSFontWeightRegular,NSColor.secondaryLabelColor);self.installationPath.lineBreakMode=NSLineBreakByTruncatingMiddle;self.installationPath.selectable=YES;
    [self.installationPath setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSButton *choose=[NSButton buttonWithTitle:@"Spiele-App ändern …" target:self action:@selector(choose:)];choose.font=[NSFont systemFontOfSize:11];choose.controlSize=NSControlSizeSmall;
    NSView *installation=[NSView new];CDAdd(installation,self.installationPath);CDAdd(installation,choose);
    [NSLayoutConstraint activateConstraints:@[[installation.heightAnchor constraintEqualToConstant:22],
        [self.installationPath.leadingAnchor constraintEqualToAnchor:installation.leadingAnchor],[self.installationPath.centerYAnchor constraintEqualToAnchor:installation.centerYAnchor],
        [self.installationPath.trailingAnchor constraintEqualToAnchor:choose.leadingAnchor constant:-12],
        [choose.trailingAnchor constraintEqualToAnchor:installation.trailingAnchor],[choose.centerYAnchor constraintEqualToAnchor:installation.centerYAnchor]]];
    self.start=[NSButton buttonWithTitle:@"Spiel mit Trainer starten" target:self action:@selector(startGame:)];
    self.start.bezelStyle=NSBezelStyleRounded;self.start.controlSize=NSControlSizeLarge;self.start.bezelColor=CDAccent();self.start.contentTintColor=NSColor.whiteColor;self.start.font=[NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];self.start.keyEquivalent=@"\r";
    self.showOverlay=[NSButton buttonWithTitle:@"Overlay einblenden" target:self action:@selector(showOverlay:)];self.showOverlay.enabled=NO;self.showOverlay.controlSize=NSControlSizeLarge;self.showOverlay.font=[NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
    NSStackView *actions=[NSStackView stackViewWithViews:@[self.start,self.showOverlay]];actions.orientation=NSUserInterfaceLayoutOrientationHorizontal;actions.spacing=12;actions.distribution=NSStackViewDistributionFillEqually;
    [actions.heightAnchor constraintEqualToConstant:42].active=YES;
    [self.start.heightAnchor constraintEqualToAnchor:actions.heightAnchor].active=YES;[self.showOverlay.heightAnchor constraintEqualToAnchor:actions.heightAnchor].active=YES;
    self.status=[NSTextField wrappingLabelWithString:@""];self.status.font=[NSFont systemFontOfSize:12];self.status.textColor=NSColor.secondaryLabelColor;
    self.statusGlyph=[NSImageView new];self.statusGlyph.imageScaling=NSImageScaleProportionallyDown;self.statusGlyph.accessibilityElement=NO;
    NSView *statusRow=[NSView new];CDAdd(statusRow,self.statusGlyph);CDAdd(statusRow,self.status);
    [NSLayoutConstraint activateConstraints:@[[statusRow.heightAnchor constraintEqualToConstant:32],
        [self.statusGlyph.leadingAnchor constraintEqualToAnchor:statusRow.leadingAnchor],[self.statusGlyph.topAnchor constraintEqualToAnchor:statusRow.topAnchor constant:1],
        [self.statusGlyph.widthAnchor constraintEqualToConstant:15],[self.statusGlyph.heightAnchor constraintEqualToConstant:15],
        [self.status.leadingAnchor constraintEqualToAnchor:self.statusGlyph.trailingAnchor constant:8],[self.status.topAnchor constraintEqualToAnchor:statusRow.topAnchor],
        [self.status.trailingAnchor constraintEqualToAnchor:statusRow.trailingAnchor]]];
    NSStackView *gameContent=[NSStackView stackViewWithViews:@[section,self.profiles,installation,actions,statusRow]];gameContent.orientation=NSUserInterfaceLayoutOrientationVertical;gameContent.alignment=NSLayoutAttributeLeading;gameContent.spacing=10;
    NSView *gameContainer=[NSView new];CDAdd(gameContainer,gameContent);
    MTTrainerMaterial *gameSurface=[[MTTrainerMaterial alloc]initWithContentView:gameContainer cornerRadius:16];
    [NSLayoutConstraint activateConstraints:@[[gameSurface.heightAnchor constraintEqualToConstant:222],
        [gameContent.leadingAnchor constraintEqualToAnchor:gameContainer.leadingAnchor constant:18],[gameContent.trailingAnchor constraintEqualToAnchor:gameContainer.trailingAnchor constant:-18],[gameContent.topAnchor constraintEqualToAnchor:gameContainer.topAnchor constant:16],
        [self.profiles.heightAnchor constraintEqualToConstant:30]]];
    for(NSView *view in @[self.profiles,installation,actions,statusRow])[view.widthAnchor constraintEqualToAnchor:gameContent.widthAnchor].active=YES;

    self.restoreCheats=[NSButton checkboxWithTitle:@"Cheat-Auswahl beim nächsten Start laden" target:self action:@selector(restoreChanged:)];self.restoreCheats.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    id savedRestore=[NSUserDefaults.standardUserDefaults objectForKey:MTSelectionRestorePreferencesKey];
    self.restoreCheats.state=(savedRestore==nil || [savedRestore boolValue]) ? NSControlStateValueOn : NSControlStateValueOff;
    self.restoreCheats.toolTip=@"Schalter und Zahlenwerte werden je Spielprofil gespeichert. Einmalaktionen laufen nie automatisch.";
    self.restoreHint=[NSTextField wrappingLabelWithString:@""];self.restoreHint.font=[NSFont systemFontOfSize:11];self.restoreHint.textColor=NSColor.secondaryLabelColor;
    NSView *settingsContent=[NSView new];CDAdd(settingsContent,self.restoreCheats);CDAdd(settingsContent,self.restoreHint);
    MTTrainerMaterial *settingsSurface=[[MTTrainerMaterial alloc]initWithContentView:settingsContent cornerRadius:16];
    [NSLayoutConstraint activateConstraints:@[[settingsSurface.heightAnchor constraintEqualToConstant:88],
        [self.restoreCheats.leadingAnchor constraintEqualToAnchor:settingsContent.leadingAnchor constant:18],[self.restoreCheats.topAnchor constraintEqualToAnchor:settingsContent.topAnchor constant:14],
        [self.restoreHint.leadingAnchor constraintEqualToAnchor:settingsContent.leadingAnchor constant:18],[self.restoreHint.trailingAnchor constraintEqualToAnchor:settingsContent.trailingAnchor constant:-18],[self.restoreHint.topAnchor constraintEqualToAnchor:self.restoreCheats.bottomAnchor constant:7]]];

    NSView *shortcuts=[NSView new];
    NSTextField *overlayKey=CDText(@"⌘  ^",17,NSFontWeightSemibold,CDAccent());
    NSTextField *overlayHint=CDText(@"Overlay & Maus",12,NSFontWeightMedium,NSColor.secondaryLabelColor);
    NSTextField *stopKey=CDText(@"⇧  F9",17,NSFontWeightSemibold,CDAccent());
    NSTextField *stopHint=CDText(@"Alle Schalter aus",12,NSFontWeightMedium,NSColor.secondaryLabelColor);
    for(NSView *view in @[overlayKey,overlayHint,stopKey,stopHint])CDAdd(shortcuts,view);
    [NSLayoutConstraint activateConstraints:@[[shortcuts.heightAnchor constraintEqualToConstant:54],
        [overlayKey.leadingAnchor constraintEqualToAnchor:shortcuts.leadingAnchor constant:18],[overlayKey.topAnchor constraintEqualToAnchor:shortcuts.topAnchor constant:4],
        [overlayHint.leadingAnchor constraintEqualToAnchor:overlayKey.leadingAnchor],[overlayHint.topAnchor constraintEqualToAnchor:overlayKey.bottomAnchor constant:2],
        [stopKey.leadingAnchor constraintEqualToAnchor:shortcuts.centerXAnchor constant:18],[stopKey.topAnchor constraintEqualToAnchor:overlayKey.topAnchor],
        [stopHint.leadingAnchor constraintEqualToAnchor:stopKey.leadingAnchor],[stopHint.topAnchor constraintEqualToAnchor:stopKey.bottomAnchor constant:2]]];
    NSView *footer=[NSView new];
    NSTextField *version=CDText([NSString stringWithFormat:@"TRAINER %@",self.configuration[@"app"][@"version"]],10,NSFontWeightMedium,NSColor.tertiaryLabelColor);
    NSButton *demo=[NSButton buttonWithTitle:@"Demo öffnen – ohne Spiel" target:self action:@selector(demo:)];demo.bordered=NO;demo.font=[NSFont systemFontOfSize:11];demo.contentTintColor=NSColor.secondaryLabelColor;
    CDAdd(footer,version);CDAdd(footer,demo);
    [NSLayoutConstraint activateConstraints:@[[footer.heightAnchor constraintEqualToConstant:20],
        [version.leadingAnchor constraintEqualToAnchor:footer.leadingAnchor],[version.centerYAnchor constraintEqualToAnchor:footer.centerYAnchor],
        [demo.trailingAnchor constraintEqualToAnchor:footer.trailingAnchor],[demo.centerYAnchor constraintEqualToAnchor:footer.centerYAnchor]]];
    NSStackView *stack=[NSStackView stackViewWithViews:@[hero,gameSurface,settingsSurface,shortcuts,footer]];stack.orientation=NSUserInterfaceLayoutOrientationVertical;stack.alignment=NSLayoutAttributeLeading;stack.spacing=14;stack.translatesAutoresizingMaskIntoConstraints=NO;
    [self.window.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[[stack.leadingAnchor constraintEqualToAnchor:self.window.contentView.leadingAnchor constant:24],[stack.trailingAnchor constraintEqualToAnchor:self.window.contentView.trailingAnchor constant:-24],[stack.topAnchor constraintEqualToAnchor:self.window.contentView.topAnchor constant:20],[stack.bottomAnchor constraintLessThanOrEqualToAnchor:self.window.contentView.bottomAnchor constant:-14]]];
    for(NSView *view in @[hero,gameSurface,settingsSurface,shortcuts,footer])[view.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active=YES;
    __weak MTLauncher *weakSelf=self;
    self.settingsObserver=[NSDistributedNotificationCenter.defaultCenter addObserverForName:MTOverlayChangedNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event){
        MTLauncher *owner=weakSelf;if(!owner.game || owner.game.terminated)return;
        NSDictionary *options=MTOverlayMessageOptions(event.object,owner.session,owner.game.processIdentifier);
        if(options){[NSUserDefaults.standardUserDefaults setObject:options forKey:MTOverlayPreferencesKey];owner.showOverlay.enabled=YES;[owner presentStatus:@"Verbunden · Overlay über ⌘ + ^ oder „Overlay einblenden“ öffnen." ready:YES];}
    }];
    self.selectionObserver=[NSDistributedNotificationCenter.defaultCenter addObserverForName:MTSelectionChangedNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *event){
        MTLauncher *owner=weakSelf;if(!owner.game || owner.game.terminated)return;
        NSDictionary *selection=MTSelectionMessageSelection(event.object,owner.session,owner.launchedProfileID,owner.game.processIdentifier);
        if(selection)[NSUserDefaults.standardUserDefaults setObject:selection forKey:MTSelectionPreferencesKey(owner.launchedProfileID)];
    }];
    if(![NSUserDefaults.standardUserDefaults stringForKey:self.pathKey].length) { NSURL *installed=[NSWorkspace.sharedWorkspace URLForApplicationWithBundleIdentifier:self.profile[@"bundleIdentifier"]];if(installed)[NSUserDefaults.standardUserDefaults setObject:installed.path forKey:self.pathKey]; }
    [self refresh:nil];[self.window center];[self.window makeKeyAndOrderFront:nil];[NSApp activateIgnoringOtherApps:YES];
}
- (void)presentStatus:(NSString *)text ready:(BOOL)ready {
    self.status.stringValue=text ?: @"";
    self.statusGlyph.image=[NSImage imageWithSystemSymbolName:ready ? @"checkmark.circle.fill" : @"info.circle" accessibilityDescription:nil];
    self.statusGlyph.contentTintColor=ready ? CDAccent() : NSColor.secondaryLabelColor;
}
- (NSString *)pathKey {return [@"GamePath." stringByAppendingString:self.profile[@"id"]];}
- (void)restoreChanged:(id)sender {(void)sender;
    BOOL enabled=self.restoreCheats.state==NSControlStateValueOn;
    [NSUserDefaults.standardUserDefaults setBool:enabled forKey:MTSelectionRestorePreferencesKey];
    self.restoreHint.stringValue=enabled ? @"Schalter und Zahlen nach dem Laden wiederherstellen.\nEinmalaktionen werden nicht automatisch ausgeführt." : @"Alle Schalter starten ausgeschaltet.\nEinmalaktionen werden nicht automatisch ausgeführt.";
}
- (void)showOverlay:(id)sender {(void)sender;
    if(!self.game || self.game.terminated || !self.session.length){self.showOverlay.enabled=NO;[self refresh:nil];return;}
    NSMutableDictionary *options=[MTNormalizeOverlayOptions([NSUserDefaults.standardUserDefaults objectForKey:MTOverlayPreferencesKey]) mutableCopy];options[@"visible"]=@YES;
    [NSDistributedNotificationCenter.defaultCenter postNotificationName:MTOverlaySettingsNotification object:MTOverlayMessage(options,self.session,self.game.processIdentifier) userInfo:nil deliverImmediately:YES];
    [self.game activateWithOptions:0];
}
- (void)refresh:(id)sender {(void)sender;self.start.enabled=NO;
    self.showOverlay.enabled=self.game && !self.game.terminated;
    if(self.showOverlay.enabled){[self presentStatus:@"Spiel läuft · Das Overlay lässt sich direkt einblenden." ready:YES];return;}
    [self restoreChanged:nil];
    if(![self.profile[@"enabled"] boolValue]){[self presentStatus:@"Dieses Spielprofil ist noch nicht freigegeben." ready:NO];return;}
    if([MTCreateGameAdapter() isMemberOfClass:MTUnsupportedAdapter.class]){[self presentStatus:@"Für dieses Spielprofil fehlt die Anbindung." ready:NO];return;}
    NSString *path=[NSUserDefaults.standardUserDefaults stringForKey:self.pathKey];NSError *error=nil;
    self.installationPath.stringValue=path ?: @"Keine Installation ausgewählt";self.installationPath.toolTip=path;
    if(!path.length){[self presentStatus:@"Bitte zuerst die passende Spiele-App auswählen." ready:NO];return;}
    self.start.enabled=MTInspectGame(path,self.profile,&error)!=nil;[self presentStatus:self.start.enabled ? @"Bereit zum Start · Das Overlay startet verborgen." : error.localizedDescription ready:self.start.enabled];
}
- (void)choose:(id)sender {(void)sender;NSOpenPanel *panel=[NSOpenPanel openPanel];panel.canChooseFiles=YES;panel.canChooseDirectories=NO;panel.allowsMultipleSelection=NO;panel.allowedContentTypes=@[UTTypeApplicationBundle];
    if([panel runModal]==NSModalResponseOK){[NSUserDefaults.standardUserDefaults setObject:panel.URL.path forKey:self.pathKey];[self refresh:nil];}}
- (void)demo:(id)sender {(void)sender;NSWorkspaceOpenConfiguration *c=[NSWorkspaceOpenConfiguration configuration];c.arguments=@[@"--demo"];c.createsNewApplicationInstance=YES;[NSWorkspace.sharedWorkspace openApplicationAtURL:NSBundle.mainBundle.bundleURL configuration:c completionHandler:nil];}
- (void)startGame:(id)sender {(void)sender;[self refresh:nil];if(!self.start.enabled)return;
    if([NSRunningApplication runningApplicationsWithBundleIdentifier:self.profile[@"bundleIdentifier"]].count){[self presentStatus:@"Die laufende Spielinstanz bitte regulär beenden." ready:NO];return;}
    NSString *path=[NSUserDefaults.standardUserDefaults stringForKey:self.pathKey];NSError *error=nil;NSDictionary *game=MTInspectGame(path,self.profile,&error);if(!game){[self presentStatus:error.localizedDescription ready:NO];return;}
    NSString *module=[NSBundle.mainBundle pathForResource:@"TrainerOverlay" ofType:@"dylib"];
    NSWorkspaceOpenConfiguration *c=[NSWorkspaceOpenConfiguration configuration];c.createsNewApplicationInstance=YES;c.activates=YES;
    self.session=NSUUID.UUID.UUIDString;
    self.launchedProfileID=self.profile[@"id"];
    id savedSelection=self.restoreCheats.state==NSControlStateValueOn
        ? [NSUserDefaults.standardUserDefaults objectForKey:MTSelectionPreferencesKey(self.launchedProfileID)] : nil;
    NSMutableDictionary *environment=[@{@"SteamAppId":self.profile[@"steamAppId"] ?: @"3321460",@"SteamGameId":self.profile[@"steamAppId"] ?: @"3321460",@"DYLD_INSERT_LIBRARIES":module,@"MT_TRAINER_TARGET":game[@"executable"],@"MT_TRAINER_CONFIG":[NSBundle.mainBundle pathForResource:@"TrainerConfig" ofType:@"json"],@"MT_TRAINER_PROFILE":self.launchedProfileID,@"MT_TRAINER_SESSION":self.session,@"MT_TRAINER_OVERLAY_OPTIONS":MTEncodeOverlayOptions(MTOverlayOptionsForLaunch([NSUserDefaults.standardUserDefaults objectForKey:MTOverlayPreferencesKey])),@"MT_TRAINER_CHEAT_SELECTION":MTEncodeCheatSelection(savedSelection)} mutableCopy];
    NSString *probe=NSProcessInfo.processInfo.environment[@"MT_CRIMSON_PROBE_OUTPUT"];
    if(probe.length)environment[@"MT_CRIMSON_PROBE_OUTPUT"]=probe;
    c.environment=environment;
    __weak MTLauncher *weakSelf=self;
    [NSWorkspace.sharedWorkspace openApplicationAtURL:[NSURL fileURLWithPath:game[@"path"]] configuration:c completionHandler:^(NSRunningApplication *app,NSError *failure){dispatch_async(dispatch_get_main_queue(),^{weakSelf.game=app;weakSelf.showOverlay.enabled=app!=nil;weakSelf.start.enabled=app==nil;[weakSelf presentStatus:failure ? failure.localizedDescription : app ? @"Spielstart angefordert · Das Overlay startet verborgen." : @"Kein Spielprozess gestartet." ready:app!=nil];});}];
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application {(void)application;return !self.game || self.game.terminated;}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)application hasVisibleWindows:(BOOL)visible {(void)application;if(!visible)[self.window makeKeyAndOrderFront:nil];return YES;}
- (void)applicationWillTerminate:(NSNotification *)notification {(void)notification;if(self.settingsObserver)[NSDistributedNotificationCenter.defaultCenter removeObserver:self.settingsObserver];if(self.selectionObserver)[NSDistributedNotificationCenter.defaultCenter removeObserver:self.selectionObserver];}
@end
int main(int argc,const char *argv[]){@autoreleasepool{[NSApplication sharedApplication];[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];if(argc==2 && !strcmp(argv[1],"--demo")){MTStartDemo();return 0;}MTUseCrimsonFeatures();MTLauncher *delegate=[MTLauncher new];NSApp.delegate=delegate;[NSApp run];}return 0;}
