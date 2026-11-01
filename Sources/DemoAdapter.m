// SPDX-License-Identifier: GPL-3.0-only
#import "DemoAdapter.h"
@implementation MTDemoAdapter {
    NSMutableDictionary<NSNumber *,NSNumber *> *_data;
    NSMutableDictionary<NSNumber *,NSDictionary *> *_effects;
    NSString *_world;
}
- (instancetype)init {if((self=[super init])){_effects=[NSMutableDictionary new];_mode=MTSessionSolo;[self newArea];}return self;}
- (NSDictionary *)values {return [_data copy];}
- (void)newArea {_world=NSUUID.UUID.UUIDString;_data=[@{@0:@50,@1:@40,@2:@6,@3:@1,@4:@500,@5:@10} mutableCopy];}
- (void)onGameThread:(dispatch_block_t)work {dispatch_async(dispatch_get_main_queue(),work);}
- (MTGameContext *)captureContext {MTGameContext *c=[MTGameContext new];c.kind=_mode;c.identity=_mode==MTSessionLoading ? @"loading" : _world;c.note=@"DEMO: ausschließlich simulierte Werte, keine Spielanbindung.";return c;}
- (void)releaseFeature:(NSNumber *)key {NSDictionary *record=_effects[key];if(record){NSMutableDictionary *owner=record[@"owner"];owner[key]=record[@"original"];[_effects removeObjectForKey:key];}}
- (void)releaseEffects {for(NSNumber *key in _effects.allKeys)[self releaseFeature:key];}
- (MTFeatureState *)applyFeature:(MTFeature)feature wanted:(BOOL)wanted value:(double)value {
    MTFeatureState *result=[MTFeatureState new];result.available=YES;result.note=@"DEMO: Änderung nur im simulierten Modell.";
    NSNumber *key=@(feature);NSDictionary *record=_effects[key];
    if(record && (!wanted || record[@"owner"]!=_data)){[self releaseFeature:key];record=nil;}
    if(wanted && !MTFeatureInfoAt(feature)->oneShot){
        if(!record){record=@{@"owner":_data,@"original":_data[key]};_effects[key]=record;}
        double target=feature==MTFeatureSpeed ? [record[@"original"] doubleValue]*value : feature==MTFeatureAmmo ? 99 : 100;
        _data[key]=@(target);result.active=[_data[key] doubleValue]==target;
    }return result;
}
- (NSString *)performOneShot:(MTFeature)feature value:(double)value {
    if(feature==MTFeatureMoney)_data[@(feature)]=@(value);
    if(feature==MTFeatureResources)_data[@(feature)]=@([_data[@(feature)] doubleValue]+100);
    return [NSString stringWithFormat:@"DEMO: %@ = %@ · nur Simulation",MTFeatureInfoAt(feature)->title,_data[@(feature)]];
}
- (BOOL)setOverlayInteraction:(BOOL)wanted {return wanted;}
@end
