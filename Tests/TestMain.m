// SPDX-License-Identifier: GPL-3.0-only
#import <AppKit/AppKit.h>
#import <mach-o/loader.h>
#import <mach/machine.h>
#import "GameBridge.h"
#import "SelectionSettings.h"
#import "DemoAdapter.h"
#import "GameProfile.h"
#import "MemoryAccess.h"
#import "Overlay.h"
#import "TrainerMaterial.h"
#include <math.h>
static void drain(void){for(int i=0;i<16;i++)[NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.005]];}
static void bridgeTests(void){
    MTDemoAdapter *a=[MTDemoAdapter new];MTGameBridge *b=[[MTGameBridge alloc]initWithAdapter:a];
    [b poll];drain();NSCAssert(b.state.ready,@"solo demo ready");
    [b performFeature:MTFeatureHealth];[b performFeature:MTFeatureSpeed];drain();
    NSCAssert(b.state.features[MTFeatureHealth].active && [a.values[@0] intValue]==100 && [a.values[@3] doubleValue]==2,@"confirmed demo effects");
    [b poll];drain();NSCAssert([a.values[@3] doubleValue]==2,@"factors never compound");
    [b setValue:NAN forFeature:MTFeatureSpeed];[b setValue:100 forFeature:MTFeatureSpeed];drain();NSCAssert(b.state.features[MTFeatureSpeed].value==2,@"invalid numeric values ignored");
    [b setValue:1000.5 forFeature:MTFeatureMoney];drain();NSCAssert(b.state.features[MTFeatureMoney].value==1000,@"integer amounts enforced");
    a.mode=MTSessionLoading;[b poll];drain();
    NSCAssert(!b.state.ready && b.state.features[MTFeatureHealth].wanted && !b.state.features[MTFeatureHealth].active && [a.values[@0] intValue]==50,@"loading releases effects but preserves choices");
    uint64_t context=b.state.context;[b poll];drain();NSCAssert(b.state.context==context,@"stable loading context");
    [a newArea];a.mode=MTSessionSolo;[b poll];drain();NSCAssert(b.state.features[MTFeatureHealth].active && [a.values[@3] doubleValue]==2,@"new area rebinds continuous effects");
    [b poll];[b performFeature:MTFeatureMoney];[b performFeature:MTFeatureResources];[a newArea];drain();
    NSCAssert([a.values[@4] intValue]==500 && [a.values[@5] intValue]==10 && b.state.features[MTFeatureHealth].active,@"stale one-shot actions are discarded across direct travel");
    a.mode=MTSessionNetwork;[b setOverlayInteraction:YES];[b poll];drain();
    NSCAssert(b.state.ready && b.state.overlayMouseActive && b.state.features[MTFeatureHealth].active && [a.values[@3] doubleValue]==2,@"network context retains choices and active effects");
    [b performFeature:MTFeatureMoney];drain();NSCAssert([a.values[@4] intValue]==1000,@"network permits one-shots");
    a.mode=MTSessionSolo;[b poll];drain();NSCAssert(b.state.features[MTFeatureHealth].active,@"return to solo retains selected cheats");
    [b poll];for(int i=0;i<24;i++)[b performFeature:MTFeatureResources];[b performAction:MTTrainerDisableAll];a.mode=MTSessionLoading;drain();
    NSCAssert(!b.state.features[MTFeatureHealth].wanted && [a.values[@5] intValue]==10,@"Shift F9 survives full queue and loading");
    [b setOverlayInteraction:NO];drain();NSCAssert(!b.state.overlayMouseActive,@"UI release survives loading");
    MTGameBridge *unsupported=[[MTGameBridge alloc]initWithAdapter:[MTUnsupportedAdapter new]];[unsupported poll];[unsupported performFeature:MTFeatureHealth];drain();NSCAssert(!unsupported.state.ready && !unsupported.state.features[0].active,@"unknown adapter cannot claim a working cheat");
}
static void selectionTests(void) {
    NSDictionary *raw=@{@"features":@{@"0":@{@"wanted":@YES},
        @"3":@{@"wanted":@YES,@"value":@3},
        @"4":@{@"wanted":@YES,@"value":@1250},
        @"5":@{@"wanted":@YES},@"999":@{@"wanted":@YES}}};
    NSDictionary *selection=MTDecodeCheatSelection(MTEncodeCheatSelection(raw));
    NSDictionary *features=selection[@"features"];
    NSCAssert([features[@"0"][@"wanted"] boolValue] && [features[@"3"][@"value"] doubleValue]==3, @"continuous switches and numeric settings survive encoding");
    NSCAssert(![features[@"4"][@"wanted"] boolValue] && [features[@"4"][@"value"] doubleValue]==1250
        && ![features[@"5"][@"wanted"] boolValue] && !features[@"999"],@"one-shot actions never restore");
    NSDictionary *invalid=MTNormalizeCheatSelection(@{@"features":@{@"3":@{@"wanted":@YES,@"value":@999}}});
    NSCAssert([invalid[@"features"][@"3"][@"value"] doubleValue]==2,@"numeric values stay within the feature catalog");
    NSString *message=MTSelectionMessage(selection,@"session-A",@"game-A",1234);
    NSCAssert([MTSelectionMessageSelection(message,@"session-A",@"game-A",1234) isEqual:selection]
        && !MTSelectionMessageSelection(message,@"session-B",@"game-A",1234)
        && !MTSelectionMessageSelection(message,@"session-A",@"game-B",1234)
        && !MTSelectionMessageSelection(message,@"session-A",@"game-A",1235),@"only matching session, game, and process may save selection");
    NSCAssert(![MTSelectionPreferencesKey(@"game-A") isEqual:MTSelectionPreferencesKey(@"game-B")],@"profiles keep separate choices");
    MTDemoAdapter *adapter=[MTDemoAdapter new];adapter.mode=MTSessionLoading;
    MTGameBridge *bridge=[[MTGameBridge alloc]initWithAdapter:adapter];
    [bridge restoreSelection:selection];[bridge poll];drain();
    NSCAssert(!bridge.state.ready && bridge.state.features[0].wanted && !bridge.state.features[0].active
        && [adapter.values[@4] intValue]==500,@"loading preserves restored switches without running one-shots");
    adapter.mode=MTSessionSolo;[bridge poll];drain();
    NSCAssert(bridge.state.features[0].active && bridge.state.features[3].active
        && [adapter.values[@3] doubleValue]==3 && [adapter.values[@4] intValue]==500,@"restore applies after solo load");
    NSCAssert([MTSelectionFromState(bridge.state) isEqual:selection],@"live state saves the same sanitized selection");
    adapter.mode=MTSessionNetwork;[bridge poll];drain();
    NSCAssert(bridge.state.ready && bridge.state.features[0].active && [MTSelectionFromState(bridge.state) isEqual:selection],@"network keeps restored and persisted switches");
    [bridge performAction:MTTrainerDisableAll];drain();
    NSCAssert(!bridge.state.features[0].wanted,@"stop clears restored switches");
}
static NSEvent *mouse(NSWindow *window,NSView *view,NSPoint p,NSEventType type){return [NSEvent mouseEventWithType:type location:[view convertPoint:p toView:nil] modifierFlags:0 timestamp:0 windowNumber:window.windowNumber context:nil eventNumber:1 clickCount:1 pressure:1];}
static void uiTests(void){
    [NSApplication sharedApplication];
    NSWindow *w=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,1000,620) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];w.releasedWhenClosed=NO;
    MTOverlayRoot *r=[[MTOverlayRoot alloc]initWithFrame:NSMakeRect(20,30,950,550) version:@"DEMO TEST"];
    [w.contentView addSubview:r];MTTrainerState *s=[MTTrainerState new];s.ready=YES;[r updateState:s];
    __block NSInteger clicks=0;
    for(NSNumber *scale in @[@0.7,@0.9,@1.3])for(NSString *pos in @[@"top-left",@"bottom-right",@"center"]){
        [r applyOverlayOptions:@{@"visible":@YES,@"scale":scale,@"position":pos}];
        NSCAssert(NSContainsRect(r.bounds,r.panel.frame),@"panel fits window");
        for(NSInteger i=0;i<MTFeatureCount;i++){
            r.featureHandler=^(MTFeature f){NSCAssert(f==i,@"correct click target");clicks++;};
            NSView *row=((MTTrainerMaterial *)r.panel).contentView.subviews[i];NSInteger before=clicks;
            NSCAssert([r handleMouseEvent:mouse(w,row,NSMakePoint(244,10),NSEventTypeLeftMouseDown)],@"click consumed");
            NSCAssert([r handleMouseEvent:mouse(w,row,NSMakePoint(244,10),NSEventTypeLeftMouseUp)],@"release consumed");NSCAssert(clicks==before+1,@"one dispatch per click");
        }
    }
    NSDictionary *launch=MTOverlayOptionsForLaunch(@{@"visible":@YES,@"badge":@YES,@"mouse":@NO,@"position":@"bottom-right",@"scale":@1.3});
    NSCAssert(![launch[@"visible"] boolValue] && ![launch[@"badge"] boolValue] && !launch[@"mouse"] && [launch[@"position"] isEqual:@"bottom-right"] && [launch[@"scale"] doubleValue]==1.3,@"new sessions open hidden and preserve layout without a separate mouse setting");
    [r applyOverlayOptions:@{@"visible":@YES,@"mouse":@NO}];
    NSCAssert(r.wantsMouseInteraction && !r.overlayOptions[@"mouse"],@"legacy mouse-off preference cannot disable a visible overlay");
    r.featureHandler=nil;
    NSView *firstRow=((MTTrainerMaterial *)r.panel).contentView.subviews[0];
    NSCAssert([r handleMouseEvent:mouse(w,firstRow,NSMakePoint(244,10),NSEventTypeLeftMouseDown)]
        && [r handleMouseEvent:mouse(w,firstRow,NSMakePoint(244,10),NSEventTypeLeftMouseUp)],@"visible overlay accepts the first mouse click");
    [r togglePanel:nil];NSCAssert(r.panel.hidden && !r.wantsMouseInteraction,@"hide gives game input back");
    [r togglePanel:nil];NSCAssert(!r.panel.hidden && r.wantsMouseInteraction && !r.overlayOptions[@"mouse"],@"Command-caret opens the overlay with mouse even after a legacy mouse-off preference");
    [r togglePanel:nil];NSCAssert(r.panel.hidden && !r.wantsMouseInteraction,@"second Command-caret returns input to game");
    s.ready=NO;[r updateState:s];__block NSInteger stops=0;r.actionHandler=^(MTTrainerAction action){NSCAssert(action==MTTrainerDisableAll,@"Shift F9 stop");stops++;};
    NSEvent *stop=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagShift timestamp:0 windowNumber:0 context:nil characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:101];[r handleEvent:stop];NSCAssert(stops==1,@"Shift F9 works during loading");
    MTOverlayShortcuts *keys=[MTOverlayShortcuts new];keys.enabled=YES;[keys setRegistered:YES shortcut:MTShortcutPanel];__block int toggles=0;keys.handler=^(MTOverlayShortcut action){(void)action;toggles++;};
    NSEvent *caret=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagCommand timestamp:0 windowNumber:w.windowNumber context:nil characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:10];
    NSEvent *oldMouse=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:NSEventModifierFlagCommand|NSEventModifierFlagOption timestamp:0 windowNumber:w.windowNumber context:nil characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:10];
    NSCAssert(MTShortcutForEvent(caret)==MTShortcutPanel && MTShortcutForEvent(oldMouse)<0,@"Command-caret alone owns overlay and mouse");
    [keys nativeShortcut:MTShortcutPanel pressed:YES];[keys nativeShortcut:MTShortcutPanel pressed:YES];NSCAssert(toggles==1,@"native repeats cannot toggle twice");[keys nativeShortcut:MTShortcutPanel pressed:NO];[keys nativeShortcut:MTShortcutPanel pressed:YES];NSCAssert(toggles==2,@"fresh press toggles");
    keys.enabled=NO;NSCAssert(![keys nativeShortcut:MTShortcutPanel pressed:YES],@"inactive app owns no hotkeys");
    NSCAssert(!MTOverlayMessageOptions(MTOverlayMessage(@{},@"A",12),@"B",12),@"foreign settings sessions ignored");
    NSDictionary *legacy=MTDecodeOverlayOptions(@"{\"visible\":true,\"mouse\":false}");
    NSCAssert(!legacy[@"mouse"] && [legacy[@"visible"] boolValue],@"old saved mouse-off state is discarded");
    [w close];
}
static void profileTests(NSString *configPath){
    NSError *error=nil;NSDictionary *config=MTLoadConfiguration(configPath,&error);NSCAssert(config && !error,@"valid template config");NSCAssert(!MTLoadConfiguration(nil,NULL),@"missing config fails safely");
    NSCAssert(!MTInspectGame(@"relative.app",config[@"profiles"][0],NULL),@"disabled/missing identity never launches");
    NSCAssert(!MTCurrentProcessMatches(config[@"profiles"][0],@"/unknown"),@"disabled profile never installs runtime");
    NSString *folder=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];[NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    @try{
        NSString *file=[folder stringByAppendingPathComponent:@"fake-executable"];
        struct mach_header_64 h={.magic=MH_MAGIC_64,.cputype=CPU_TYPE_ARM64,.filetype=MH_EXECUTE,.ncmds=1,.sizeofcmds=sizeof(struct uuid_command)};
        struct uuid_command u={.cmd=LC_UUID,.cmdsize=sizeof(u)};NSUUID *uuid=[NSUUID UUID];[uuid getUUIDBytes:u.uuid];NSMutableData *data=[NSMutableData dataWithBytes:&h length:sizeof(h)];[data appendBytes:&u length:sizeof(u)];[data writeToFile:file atomically:YES];
        NSCAssert([MTReadExecutableIdentity(file)[@"uuid"] isEqual:uuid.UUIDString],@"exact arm64 identity read");
        h.ncmds=2;memcpy(data.mutableBytes,&h,sizeof(h));[data writeToFile:file atomically:YES];NSCAssert(!MTReadExecutableIdentity(file),@"truncated Mach-O rejected");
        NSMutableDictionary *bad=[config mutableCopy];bad[@"profiles"]=@[@{@"id":@"bad",@"name":@"Bad",@"enabled":@YES,@"bundleIdentifier":@"example.game",@"executable":@"Game",@"uuids":@[]}];
        NSString *json=[folder stringByAppendingPathComponent:@"bad.json"];[[NSJSONSerialization dataWithJSONObject:bad options:0 error:NULL]writeToFile:json atomically:YES];NSCAssert(!MTLoadConfiguration(json,NULL),@"active profile without UUID denied");
    }@finally{[NSFileManager.defaultManager removeItemAtPath:folder error:NULL];}
    uint8_t byte;NSCAssert(!MTReadMemory((void *)1,&byte,1) && !MTWriteByte((void *)1,0,1),@"unmapped memory denied");
    uint8_t writable[65]={0}, input[65]={1};
    NSCAssert(MTWriteMemory(writable,input,64) && writable[0]==1 && !MTWriteMemory(writable,input,65) && !MTWriteMemory((void *)1,input,1),@"Generic data writes enforce mapped writable pages and 64-byte bound");
    float local=1;NSCAssert(MTWriteFloat(&local,0,2) && local==2 && !MTWriteFloat(&local,0,NAN),@"writable finite data only");
}
void MTPresentationRunTests(void);
void CDRuntimeRunTests(void);
int main(int argc,const char *argv[]){@autoreleasepool{NSCAssert(argc==2,@"config argument");bridgeTests();selectionTests();profileTests([NSString stringWithUTF8String:argv[1]]);uiTests();MTPresentationRunTests();CDRuntimeRunTests();puts("Template checks passed: saved selection/profile isolation/one-shots, demo effects/restoration, travel, stale actions, loading/Shift F9, network continuity, unsupported adapter, scaled clicks, shortcuts, profiles and bounded memory.");}return 0;}
