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
/// Creates a complete vehicle transactionally. On failure no driveable body is
/// left in the world and `error` describes the failed validation/creation step.
- (BOOL)prepareVehicleAt:(simd_float3)position
                 heading:(float)heading
                 profile:(NSString *)profile
                   error:(NSError *_Nullable *_Nullable)error;
- (void)removeVehicle;
- (BOOL)isReady;
- (void)setThrottle:(float)throttle brake:(float)brake steering:(float)steering;
- (void)setPaused:(BOOL)paused;
- (void)replaceStaticMesh:(NSUUID *)identifier
                  vertices:(NSData *)vertices
                   indices:(NSData *)indices;
- (void)removeStaticMesh:(NSUUID *)identifier;
- (DBJoltVehicleState *)step:(double)elapsedSeconds;
@end

NS_ASSUME_NONNULL_END
