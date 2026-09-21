#import <Foundation/Foundation.h>
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

/// Explicit scalar transport avoids relying on NSValue's unsupported encoding
/// of simd_float4x4 (a C struct containing vector fields).
@interface DBJoltTransform : NSObject
@property(nonatomic) NSInteger wheelIndex; // -1 for the chassis
@property(nonatomic) float positionX;
@property(nonatomic) float positionY;
@property(nonatomic) float positionZ;
@property(nonatomic) float rotationX;
@property(nonatomic) float rotationY;
@property(nonatomic) float rotationZ;
@property(nonatomic) float rotationW;
@end

/// Objective-C value type keeps all C++ ownership inside the pod.
@interface DBJoltVehicleState : NSObject
@property(nonatomic) BOOL success;
@property(nonatomic) NSInteger errorCode;
@property(nonatomic, copy, nullable) NSString *errorMessage;
@property(nonatomic, strong, nullable) DBJoltTransform *chassis;
@property(nonatomic, copy) NSArray<DBJoltTransform *> *wheels;
@property(nonatomic) float speedMetersPerSecond;
@property(nonatomic) float appliedThrottle;
@property(nonatomic) float appliedBrake;
@property(nonatomic) float appliedSteering;
@property(nonatomic) BOOL collided;
@property(nonatomic, copy) NSString *operation;
@property(nonatomic) NSInteger simulationStep;
@property(nonatomic) double timeStep;
@property(nonatomic) NSInteger expectedWheelCount;
@property(nonatomic) NSInteger outputWheelCount;
@property(nonatomic) BOOL transformsFinite;
@end

@interface DBJoltWorld : NSObject
- (instancetype)init;
/// Confirms that the long-lived allocator, factory, jobs and physics system exist.
- (BOOL)isOperational;
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
