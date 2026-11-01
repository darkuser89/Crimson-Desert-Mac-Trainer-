// SPDX-License-Identifier: GPL-3.0-only
// Private native inventory bindings. All selection discovery stays on GameThread;
// the queued transaction carries stable actor/item numbers, never UI pointers.
struct ItemBinding {uint16_t inventory=UINT16_MAX,info=UINT16_MAX;int16_t slot=-1;uint64_t number=UINT64_MAX;int64_t count=0;};
void *inventoryComponent(void *actor) {return native<void *(*)(void *)>(0x1d2e7dc)(actor);}
void *findBoundItem(void *actor,ItemBinding &binding,bool searchNumber) {
    void *component=inventoryComponent(actor);if(!component)return nullptr;
    unsigned inventories=read<uint32_t>(component,0x20);if(inventories>128)return nullptr;
    for(unsigned i=0;i<inventories;i++) {
        void *inventory=native<void *(*)(void *,unsigned)>(0x1d2f8dc)(component,i);if(!inventory)continue;
        uint16_t index=read<uint16_t>(inventory,0x10);
        if(binding.inventory!=UINT16_MAX && binding.inventory!=index)continue;
        int slots=read<int16_t>(inventory,8);if(slots<0 || slots>4096)continue;
        for(int slot=0;slot<slots;slot++) {
            void *item=native<void *(*)(void *,int16_t)>(0x1a65b54)(inventory,slot);
            if(!item || !native<bool(*)(const void *)>(0x1a6cfd0)(item))continue;
            if(binding.info!=UINT16_MAX && read<uint16_t>(item,8)!=binding.info)continue;
            uint64_t number=read<uint64_t>(item);
            if(!number || number==UINT64_MAX)continue;
            if(searchNumber && number!=binding.number)continue;
            if(!searchNumber && binding.number!=UINT64_MAX)return nullptr; // ambiguous wallet
            binding.inventory=index;binding.slot=slot;binding.number=number;
            binding.info=read<uint16_t>(item,8);binding.count=read<int64_t>(item,0x10);
            if(searchNumber)return item;
        }
    }
    if(!searchNumber && binding.number!=UINT64_MAX)return findBoundItem(actor,binding,true);
    return nullptr;
}
void *walletItem(void *actor,ItemBinding &binding) {
    void *infos=native<void *(*)(uint16_t)>(0x1b34090)(6);
    if(!infos)return nullptr;
    binding.info=read<uint16_t>(infos,0xf0);
    if(binding.info==UINT16_MAX)return nullptr;
    binding.inventory=native<uint16_t(*)(void *,uint16_t,uint8_t)>(0xf547fc)(actor,binding.info,0);
    return findBoundItem(actor,binding,false);
}
NSDictionary *selectionDiagnostic;
void *selectedItem(void *actor,ItemBinding &binding) {
    void *context=native<void *(*)()>(0x47d75c4)();
    void *manager=context ? read<void *>(context,0x68) : nullptr;
    void *modes=manager ? read<void *>(manager,0x78) : nullptr;
    uint32_t count=manager ? read<uint32_t>(manager,0x80) : 0;
    void *root=nullptr;
    NSMutableDictionary *diag=[@{@"modes":@(count)} mutableCopy];selectionDiagnostic=diag;
    if(!modes || count>16)return nullptr;
    for(uint32_t i=0;i<count;i++) {
        void *mode=read<void *>(modes,i*sizeof(void *));if(!mode)continue;
        void *candidate=native<void *(*)(void *,const char *)>(0x2e95f64)(mode,"InventoryEquipmentPanel");
        if(!candidate || read<uintptr_t>(candidate)!=imageBase+0x80c1350)continue;
        void *element=read<void *>(candidate,8);
        bool displayed=element && native<bool(*)(void *)>(0x2903210)(element);
        diag[@"mode"]=@(i);diag[@"displayed"]=@(displayed);diag[@"tab"]=@(read<uint8_t>(candidate,0x2d0));
        if(!displayed)continue;
        if(root)return nullptr;root=candidate;
    }
    if(!root)return nullptr;
    uint8_t tab=read<uint8_t>(root,0x2d0);
    void *grid=nullptr,*element=nullptr;
    if(tab==0){grid=read<void *>(root,0x220);if(grid)element=native<void *(*)(void *)>(0x4960a8c)(grid);}
    else if(tab==2){grid=read<void *>(root,0x228);if(grid)element=native<void *(*)(void *)>(0x4a5bec)(grid);}
    else return nullptr;
    diag[@"element"]=@(element!=nullptr);
    void *script=element ? native<void *(*)(void *)>(0x2901eb8)(element) : nullptr;
    diag[@"script"]=@(script!=nullptr);
    if(!script)return nullptr;
    void *vtable=read<void *>(script);
    auto matches=reinterpret_cast<bool(*)(void *,const void *)>(read<uintptr_t>(vtable,0x1a8));
    bool matched=matches && matches(script,reinterpret_cast<void *>(imageBase+0x9085a04));diag[@"typeMatched"]=@(matched);
    if(!matched)return nullptr;
    void *item=static_cast<uint8_t *>(script)+0x8b8;
    if(!native<bool(*)(const void *)>(0x1a6cfd0)(item))item=static_cast<uint8_t *>(script)+0x610;
    if(!native<bool(*)(const void *)>(0x1a6cfd0)(item))return nullptr;
    binding.number=read<uint64_t>(item);diag[@"itemNo"]=@(binding.number);return findBoundItem(actor,binding,true);
}
NSDictionary *quantityObservation;
NSDictionary *bindingJSON(const ItemBinding &b) {return @{@"itemNo":@(b.number),@"inventory":@(b.inventory),@"slot":@(b.slot),@"info":@(b.info),@"count":@(b.count)};}
// Native vectors are borrowed const views here. The engine copies/consumes their
// contents synchronously; no foreign allocator ownership is transferred.
struct NativeArray {void *data=nullptr;uint32_t count=0,capacity=0;};
struct DropBehavior {
    alignas(16) uint8_t bytes[0x1c0]{};
    DropBehavior(){native<void(*)(void *)>(0xc6dadc)(bytes);}
    ~DropBehavior(){native<void(*)(void *)>(0xc6db5c)(bytes);}
};
struct DropValue {
    alignas(8) uint8_t bytes[56]{};
    DropValue(){native<void(*)(void *)>(0x1f91df0)(bytes);}
    ~DropValue(){native<void(*)(void *)>(0x1f9201c)(bytes);}
};
struct ItemCopy {
    alignas(8) uint8_t bytes[200]{};
    ItemCopy(void *item){native<void(*)(void *,const void *)>(0x1a6cb58)(bytes,item);}
    ~ItemCopy(){native<void(*)(void *)>(0x1a6cbe4)(bytes);}
};
NSDictionary *changeQuantity(uint32_t actorKey,ItemBinding binding,int64_t target) {
    void *context=native<void *(*)()>(0xc91868)();void *manager=context ? read<void *>(context) : nullptr;
    if(!manager)return @{@"success":@NO};
    ActorScope scope=native<ActorScope(*)(void *,uint32_t)>(0x824fac)(manager,actorKey);
    if(!scope.valid || !scope.actor)return @{@"success":@NO};
    uint16_t expectedInfo=binding.info;
    void *item=findBoundItem(scope.actor,binding,true);
    if(!item || binding.info!=expectedInfo)return @{@"success":@NO};
    int64_t delta=target-binding.count;
    NSMutableDictionary *result=[@{@"before":@(binding.count),@"requested":@(target),@"itemNo":@(binding.number),@"actorKey":@(actorKey)} mutableCopy];
    if(!delta){result[@"success"]=@YES;result[@"after"]=@(target);return result;}
    // A grant may merge a native stack. Require a single matching inventory
    // stack so editing the selected row cannot change another matching row.
    if(delta>0) {
        void *component=inventoryComponent(scope.actor);
        void *inventory=native<void *(*)(void *,uint16_t)>(0x1d2f8fc)(component,binding.inventory);
        int matches=0,slots=inventory ? read<int16_t>(inventory,8) : 0;
        if(slots<0 || slots>4096)return @{@"success":@NO};
        for(int slot=0;slot<slots;slot++) {
            void *other=native<void *(*)(void *,int16_t)>(0x1a65b54)(inventory,slot);
            if(other && native<bool(*)(const void *)>(0x1a6cfd0)(other) && read<uint16_t>(other,8)==binding.info)matches++;
        }
        if(matches!=1){result[@"success"]=@NO;result[@"reason"]=@"Mehrere passende Stapel; keine Änderung.";return result;}
    }
    DropBehavior behavior;
    uint32_t error=native<uint32_t(*)(void *)>(0xc6df24)(behavior.bytes);
    if(error){result[@"success"]=@NO;result[@"nativeError"]=@(error);return result;}
    native<void(*)(void *)>(0xc717a4)(behavior.bytes);
    native<void(*)(void *,uint16_t)>(0xc717d8)(behavior.bytes,binding.inventory);
    NativeArray pops,drops;
    alignas(8) uint8_t pop[40]{};
    DropValue drop;
    if(delta>0) {
        ItemCopy copy(item);native<void(*)(void *,int64_t)>(0x1a6dfd8)(copy.bytes,delta);
        native<void(*)(void *,const void *)>(0x1f92378)(drop.bytes,copy.bytes);
        drops={drop.bytes,1,1};
    } else {
        int64_t amount=-delta;
        native<void(*)(void *,uint16_t,const uint64_t *,const int16_t *,const int64_t *)>(0x1a63ed0)(pop,binding.inventory,&binding.number,&binding.slot,&amount);
        pops={pop,1,1};
    }
    uint64_t tick=native<uint64_t(*)()>(0xea699c)();
    error=native<uint32_t(*)(void *,void *,const NativeArray *,const NativeArray *,bool,int64_t,uint64_t,uint16_t,bool,int64_t,uint16_t,bool,bool)>(0xc7168c)(behavior.bytes,scope.actor,&pops,&drops,false,0,tick,7,false,0,UINT16_MAX,true,true);
    result[@"nativeError"]=@(error);
    void *after=findBoundItem(scope.actor,binding,true);
    result[@"after"]=after ? @(read<int64_t>(after,0x10)) : @(-1);
    result[@"success"]=@(error==0 && after && read<int64_t>(after,0x10)==target);
    return result;
}

NSDictionary *inventoryDiagnostic(void *actor) {
    void *component=inventoryComponent(actor);NSMutableArray *list=[NSMutableArray new];
    unsigned count=component ? read<uint32_t>(component,0x20) : 0;
    for(unsigned i=0;i<std::min(count,128u);i++) {
        void *inv=native<void *(*)(void *,unsigned)>(0x1d2f8dc)(component,i);if(!inv)continue;
        int slots=read<int16_t>(inv,8);NSMutableArray *items=[NSMutableArray new];
        for(int j=0;j<std::min(slots,4096);j++) {
            void *item=native<void *(*)(void *,int16_t)>(0x1a65b54)(inv,j);
            if(item && native<bool(*)(const void *)>(0x1a6cfd0)(item)) {
                [items addObject:@{@"slot":@(j),@"no":@(read<uint64_t>(item)),@"info":@(read<uint16_t>(item,8)),@"count":@(read<int64_t>(item,0x10))}];
                if(items.count>=6)break;
            }
        }
        [list addObject:@{@"index":@(read<uint16_t>(inv,0x10)),@"slots":@(slots),@"items":items}];
    }
    return @{@"component":@(component!=nullptr),@"count":@(count),@"moneyInventory":@(native<uint16_t(*)()>(0x1951d2c)()),@"inventories":list};
}
