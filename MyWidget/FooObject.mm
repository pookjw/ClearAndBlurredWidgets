//
//  FooObject.mm
//  MyApp
//
//  Created by Jinwoo Kim on 9/15/24.
//

#import "FooObject.h"
#import <dispatch/dispatch.h>
#import <objc/message.h>
#import <objc/runtime.h>

@interface MyDescriptorFetchResult : NSObject <NSSecureCoding> {
    NSArray *_activityDescriptors;
    NSArray *_controlDescriptors;
    NSArray *_widgetDescriptors;
    BOOL _didPatchTarget;
}

@property(nonatomic, readonly) BOOL didPatchTarget;
@end
@implementation MyDescriptorFetchResult

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (BOOL)didPatchTarget {
    return _didPatchTarget;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        Class baseDescriptorClass = objc_lookUpClass("CHSBaseDescriptor");
        Class controlDescriptorClass = objc_lookUpClass("CHSControlDescriptor");
        Class widgetDescriptorClass = objc_lookUpClass("CHSWidgetDescriptor");
        NSSet *activityClasses = baseDescriptorClass
            ? [NSSet setWithObjects:NSArray.class, baseDescriptorClass, nil]
            : [NSSet setWithObject:NSArray.class];
        NSSet *controlClasses = controlDescriptorClass
            ? [NSSet setWithObjects:NSArray.class, controlDescriptorClass, nil]
            : [NSSet setWithObject:NSArray.class];
        NSSet *widgetClasses = widgetDescriptorClass
            ? [NSSet setWithObjects:NSArray.class, widgetDescriptorClass, nil]
            : [NSSet setWithObject:NSArray.class];

        NSArray *activityDescriptors = [coder decodeObjectOfClasses:activityClasses
                                                              forKey:@"activityDescriptors"];
        NSArray *controlDescriptors = [coder decodeObjectOfClasses:controlClasses
                                                             forKey:@"controlDescriptors"];
        NSArray *widgetDescriptors = [coder decodeObjectOfClasses:widgetClasses
                                                            forKey:@"widgetDescriptors"];
        
        //
        
        NSMutableArray *newWidgetDescriptors = [[NSMutableArray alloc] initWithCapacity:widgetDescriptors.count];
        
        for (id widgetDescriptor in widgetDescriptors) {
            NSString *kind = reinterpret_cast<id (*)(id, SEL)>(objc_msgSend)(widgetDescriptor, sel_registerName("kind"));
            
            BOOL isClearWidget = [kind isEqualToString:@"MyClearWidget"];
            BOOL isBlurWidget = [kind isEqualToString:@"MyBlurWidget"];
            if (isClearWidget || isBlurWidget) {
                id mutableWidgetDescriptor = [widgetDescriptor mutableCopy];
                SEL removableSelector = sel_registerName("setBackgroundRemovable:");
                SEL transparentSelector = sel_registerName("setTransparent:");
                SEL vibrantContentSelector = sel_registerName("setSupportsVibrantContent:");
                SEL preferredStyleSelector = sel_registerName("setPreferredBackgroundStyle:");
                BOOL supportsPatch = mutableWidgetDescriptor
                    && [mutableWidgetDescriptor respondsToSelector:removableSelector]
                    && [mutableWidgetDescriptor respondsToSelector:transparentSelector]
                    && [mutableWidgetDescriptor respondsToSelector:preferredStyleSelector]
                    && (!isBlurWidget || [mutableWidgetDescriptor respondsToSelector:vibrantContentSelector]);
                if (!supportsPatch) {
                    [newWidgetDescriptors addObject:widgetDescriptor];
                    [mutableWidgetDescriptor release];
                    continue;
                }

                reinterpret_cast<void (*)(id, SEL, BOOL)>(objc_msgSend)(
                    mutableWidgetDescriptor, removableSelector, YES);
                reinterpret_cast<void (*)(id, SEL, BOOL)>(objc_msgSend)(
                    mutableWidgetDescriptor, transparentSelector, YES);
                if (isBlurWidget) {
                    reinterpret_cast<void (*)(id, SEL, BOOL)>(objc_msgSend)(
                        mutableWidgetDescriptor, vibrantContentSelector, YES);
                }
                reinterpret_cast<void (*)(id, SEL, NSUInteger)>(objc_msgSend)(
                    mutableWidgetDescriptor, preferredStyleSelector, isBlurWidget ? 0x2 : 0x1);
                [newWidgetDescriptors addObject:mutableWidgetDescriptor];
                [mutableWidgetDescriptor release];
                _didPatchTarget = YES;
            } else {
                [newWidgetDescriptors addObject:widgetDescriptor];
            }
        }
        
        _widgetDescriptors = [newWidgetDescriptors copy];
        [newWidgetDescriptors release];
        _controlDescriptors = [controlDescriptors retain];
        _activityDescriptors = [activityDescriptors retain];
    }
    
    return self;
}

- (void)dealloc {
    [_activityDescriptors release];
    [_controlDescriptors release];
    [_widgetDescriptors release];
    [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_activityDescriptors forKey:@"activityDescriptors"];
    [coder encodeObject:_controlDescriptors forKey:@"controlDescriptors"];
    [coder encodeObject:_widgetDescriptors forKey:@"widgetDescriptors"];
}

@end

namespace custom_ExportedObject {
    namespace getAllCurrentDescriptorsWithCompletion {
        void (*original)(id, SEL, id);
        void custom(id self, SEL _cmd, void (^completion)(id fetchResult)) {
            original(self, _cmd, ^(id fetchResult_1) {
                if (!fetchResult_1 || ![fetchResult_1 respondsToSelector:@selector(encodeWithCoder:)]) {
                    completion(fetchResult_1);
                    return;
                }

                NSError * _Nullable error = nil;
                
                NSKeyedArchiver *archiver_1 = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
                [fetchResult_1 encodeWithCoder:archiver_1];
                
                NSData *encodedData_1 = archiver_1.encodedData;
                [archiver_1 release];
                
                //
                
                NSKeyedUnarchiver *unarchiver_1 = [[NSKeyedUnarchiver alloc] initForReadingFromData:encodedData_1 error:&error];
                if (error != nil || unarchiver_1 == nil) {
                    completion(fetchResult_1);
                    [unarchiver_1 release];
                    return;
                }
                
                MyDescriptorFetchResult *fetchResult_2 = [[MyDescriptorFetchResult alloc] initWithCoder:unarchiver_1];
                [unarchiver_1 release];
                if (fetchResult_2 == nil || !fetchResult_2.didPatchTarget) {
                    [fetchResult_2 release];
                    completion(fetchResult_1);
                    return;
                }
                
                NSKeyedArchiver *archiver_2 = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
                [fetchResult_2 encodeWithCoder:archiver_2];
                [fetchResult_2 release];
                NSData *encodedData_2 = archiver_2.encodedData;
                [archiver_2 release];
                
                //
                
                error = nil;
                NSKeyedUnarchiver *unarchiver_3 = [[NSKeyedUnarchiver alloc] initForReadingFromData:encodedData_2 error:&error];
                Class descriptorFetchResultClass = objc_lookUpClass("_TtC9WidgetKit21DescriptorFetchResult");
                if (error != nil || unarchiver_3 == nil || descriptorFetchResultClass == nil) {
                    [unarchiver_3 release];
                    completion(fetchResult_1);
                    return;
                }
                
                id fetchResult_3 = [[descriptorFetchResultClass alloc] initWithCoder:unarchiver_3];
                [unarchiver_3 release];
                if (fetchResult_3 == nil) {
                    completion(fetchResult_1);
                    return;
                }

                completion(fetchResult_3);
                [fetchResult_3 release];
            });
        }
        void swizzle() {
            if (original != nil) {
                return;
            }

            Class exportedObject = objc_lookUpClass("_TtCC9WidgetKit24WidgetExtensionXPCServer14ExportedObject");
            Method method = class_getInstanceMethod(exportedObject, sel_registerName("getAllCurrentDescriptorsWithCompletion:"));
            if (method == nil) {
                return;
            }
            original = reinterpret_cast<decltype(original)>(method_getImplementation(method));
            method_setImplementation(method, reinterpret_cast<IMP>(custom));
        }
    }
}

@implementation FooObject

+ (void)load {
    custom_ExportedObject::getAllCurrentDescriptorsWithCompletion::swizzle();
    dispatch_async(dispatch_get_main_queue(), ^{
        custom_ExportedObject::getAllCurrentDescriptorsWithCompletion::swizzle();
    });
}

@end
