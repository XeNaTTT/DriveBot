#import <Foundation/Foundation.h>
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

/// Objective-C value type keeps all C++ ownership inside the pod.
@interface DBJoltVehicleState : NSObject
@property(nonatomic) simd_float4x4 chassisTransform;
@property(nonatomic, copy) NSArray<NSValue *> *wheelTransforms;
@property(nonatomic) float speedMetersPerSecond;
@property(nonatomic) BOOL collided;
@end

@interface DBJoltWorld : NSObject
- (instancetype)init;
- (void)resetAt:(simd_float3)position heading:(float)heading;
- (void)setThrottle:(float)throttle brake:(float)brake steering:(float)steering;
- (void)setPaused:(BOOL)paused;
- (void)replaceStaticMesh:(NSUUID *)identifier
                  vertices:(NSData *)vertices
                   indices:(NSData *)indices;
- (void)removeStaticMesh:(NSUUID *)identifier;
- (DBJoltVehicleState *)step:(double)elapsedSeconds;
@end

NS_ASSUME_NONNULL_END
