// SPDX-License-Identifier: GPL-3.0-only
#import "DemoHost.h"
#import "DemoAdapter.h"
#import "Overlay.h"
@interface MTDemoDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic) NSWindow *window;
@property(nonatomic) MTOverlayRoot *root;
@property(nonatomic) MTDemoAdapter *adapter;
@property(nonatomic) MTGameBridge *bridge;
@property(nonatomic) NSTextField *values;
@property(nonatomic) NSTimer *timer;
@property(nonatomic) id monitor;
@end
@implementation MTDemoDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    self.window=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,1000,620) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:NO];
    self.window.title=@"TRAINER-VORLAGE · DEMO · keine Verbindung zu einem Spiel";self.window.releasedWhenClosed=NO;
    self.window.minSize=NSMakeSize(700,450);
    NSTextField *title=[NSTextField labelWithString:@"Demo-Modell: keine echten Cheats"];
    title.font=[NSFont boldSystemFontOfSize:21];title.frame=NSMakeRect(24,540,450,32);[self.window.contentView addSubview:title];
    self.values=[NSTextField wrappingLabelWithString:@""];self.values.frame=NSMakeRect(24,220,440,260);self.values.font=[NSFont monospacedSystemFontOfSize:14 weight:NSFontWeightRegular];[self.window.contentView addSubview:self.values];
    NSArray *titles=@[@"Neues Gebiet",@"Ladepause",@"Einzelspieler",@"Netzwerk",@"Alle aus"];
    SEL actions[]={@selector(travel:),@selector(loading:),@selector(solo:),@selector(network:),@selector(stop:)};
    for(NSUInteger i=0;i<titles.count;i++){NSButton *b=[NSButton buttonWithTitle:titles[i] target:self action:actions[i]];b.frame=NSMakeRect(24+i*155,38,145,32);[self.window.contentView addSubview:b];}
    self.adapter=[MTDemoAdapter new];self.bridge=[[MTGameBridge alloc]initWithAdapter:self.adapter];
    self.root=[[MTOverlayRoot alloc]initWithFrame:self.window.contentView.bounds version:@"DEMO"];
    NSDictionary *saved=[NSUserDefaults.standardUserDefaults objectForKey:MTOverlayPreferencesKey];
    [self.root applyOverlayOptions:MTOverlayOptionsForLaunch(saved ?: @{@"position":@"top-right"})];
    [self.window.contentView addSubview:self.root positioned:NSWindowAbove relativeTo:nil];
    __weak MTDemoDelegate *weakSelf=self;
    self.root.featureHandler=^(MTFeature f){[weakSelf.bridge performFeature:f];};
    self.root.valueHandler=^(MTFeature f,double value){[weakSelf.bridge setValue:value forFeature:f];};
    self.root.actionHandler=^(MTTrainerAction action){[weakSelf.bridge performAction:action];};
    self.root.optionsChanged=^(NSDictionary *options){[NSUserDefaults.standardUserDefaults setObject:options forKey:MTOverlayPreferencesKey];[weakSelf.bridge setOverlayInteraction:weakSelf.root.wantsMouseInteraction];};
    self.bridge.stateChanged=^(MTTrainerState *state){[weakSelf.root updateState:state];[weakSelf refresh];};
    NSEventMask mask=NSEventMaskKeyDown|NSEventMaskLeftMouseDown|NSEventMaskLeftMouseDragged|NSEventMaskLeftMouseUp;
    self.monitor=[NSEvent addLocalMonitorForEventsMatchingMask:mask handler:^NSEvent *(NSEvent *event){
        MTDemoDelegate *s=weakSelf;if(event.window!=s.window)return event;
        BOOL handled=event.type==NSEventTypeKeyDown ? [s.root handleEvent:event] : [s.root handleMouseEvent:event];return handled ? nil : event;
    }];
    self.timer=[NSTimer timerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer){(void)timer;[weakSelf.bridge poll];}];
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
    [self.bridge setOverlayInteraction:self.root.wantsMouseInteraction];[self.bridge poll];
    [self.window center];[self.window makeKeyAndOrderFront:nil];[NSApp activateIgnoringOtherApps:YES];
}
- (void)refresh {
    NSMutableString *text=[NSMutableString stringWithString:@"Nur Werte dieses Demo-Prozesses:\n\n"];
    for(NSInteger i=0;i<MTFeatureCount;i++)[text appendFormat:@"%@: %@\n",MTFeatureInfoAt(i)->title,self.adapter.values[@(i)]];
    [text appendFormat:@"\nStatus: %@\n\n⌘ ^: Overlay + Maus\nF1–F6: Beispiele · ⇧F9: alles aus",self.bridge.state.status];self.values.stringValue=text;
}
- (void)travel:(id)sender {(void)sender;self.adapter.mode=MTSessionLoading;[self.bridge poll];__weak MTDemoDelegate *weakSelf=self;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,400*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[weakSelf.adapter newArea];weakSelf.adapter.mode=MTSessionSolo;[weakSelf.bridge poll];});}
- (void)loading:(id)sender {(void)sender;self.adapter.mode=MTSessionLoading;[self.bridge poll];}
- (void)solo:(id)sender {(void)sender;self.adapter.mode=MTSessionSolo;[self.bridge poll];}
- (void)network:(id)sender {(void)sender;self.adapter.mode=MTSessionNetwork;[self.bridge poll];}
- (void)stop:(id)sender {(void)sender;[self.bridge performAction:MTTrainerDisableAll];}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application {(void)application;return YES;}
@end
void MTStartDemo(void){MTDemoDelegate *delegate=[MTDemoDelegate new];NSApp.delegate=delegate;[NSApp run];}
