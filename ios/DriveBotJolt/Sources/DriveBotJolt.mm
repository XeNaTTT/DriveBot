#include <Jolt/Jolt.h>
#import "DriveBotJolt.h"
#include <Jolt/RegisterTypes.h>
#include <Jolt/Core/Factory.h>
#include <Jolt/Core/TempAllocator.h>
#include <Jolt/Core/JobSystemThreadPool.h>
#include <Jolt/Physics/PhysicsSystem.h>
#include <Jolt/Physics/Body/BodyCreationSettings.h>
#include <Jolt/Physics/Collision/Shape/BoxShape.h>
#include <Jolt/Physics/Collision/Shape/MeshShape.h>
#include <Jolt/Physics/Collision/Shape/OffsetCenterOfMassShape.h>
#include <Jolt/Physics/Vehicle/VehicleConstraint.h>
#include <Jolt/Physics/Vehicle/WheeledVehicleController.h>
#include <algorithm>
#include <cmath>
#include <unordered_map>

using namespace JPH;
namespace {
namespace Layers { static constexpr ObjectLayer STATIC = 0, MOVING = 1; }
NSString *const DBJoltErrorDomain = @"de.drivebot.jolt";

class PairFilter final : public ObjectLayerPairFilter {
 public: bool ShouldCollide(ObjectLayer a, ObjectLayer b) const override {
   return a == Layers::MOVING || b == Layers::MOVING;
 }
};
class BroadLayer final : public BroadPhaseLayerInterface {
  BroadPhaseLayer layers[2] = {BroadPhaseLayer(0), BroadPhaseLayer(1)};
 public:
  uint GetNumBroadPhaseLayers() const override { return 2; }
  BroadPhaseLayer GetBroadPhaseLayer(ObjectLayer layer) const override { return layers[layer]; }
#if defined(JPH_EXTERNAL_PROFILE) || defined(JPH_PROFILE_ENABLED)
  const char *GetBroadPhaseLayerName(BroadPhaseLayer layer) const override {
    return layer == layers[0] ? "Static" : "Moving";
  }
#endif
};
class ObjectBroadFilter final : public ObjectVsBroadPhaseLayerFilter {
 public: bool ShouldCollide(ObjectLayer layer, BroadPhaseLayer broad) const override {
   return layer == Layers::MOVING || broad == BroadPhaseLayer(1);
 }
};
static simd_float4x4 Matrix(RMat44 matrix) {
  simd_float4x4 output;
  for (int column = 0; column < 4; ++column)
    for (int row = 0; row < 4; ++row)
      output.columns[column][row] = (float)matrix(column, row);
  return output;
}
static bool IsFinite(simd_float3 value) {
  return std::isfinite(value.x) && std::isfinite(value.y) && std::isfinite(value.z);
}
static void SetError(NSError **error, NSInteger code, NSString *message) {
  if (error) *error = [NSError errorWithDomain:DBJoltErrorDomain code:code
    userInfo:@{NSLocalizedDescriptionKey: message}];
}
struct Profile {
  float mass, torque, steer, clearance, suspension, frequency, damping;
};
static Profile ProfileNamed(NSString *name) {
  if ([name isEqualToString:@"sport"]) return {1.55f, 2.25f, 34, .006f, .026f, 3.8f, .72f};
  if ([name isEqualToString:@"offroad"]) return {2.1f, 1.95f, 28, .012f, .052f, 2.5f, .68f};
  return {1.75f, 1.65f, 30, .008f, .035f, 3.1f, .72f};
}
}

@implementation DBJoltVehicleState
- (instancetype)init {
  if ((self = [super init])) {
    _chassisTransform = matrix_identity_float4x4;
    _wheelTransforms = @[];
  }
  return self;
}
@end

@interface DBJoltWorld () {
  PhysicsSystem *_physics;
  TempAllocatorImpl *_temp;
  JobSystemThreadPool *_jobs;
  BroadLayer *_broad;
  PairFilter *_pairs;
  ObjectBroadFilter *_objectBroad;
  BodyID _car;
  Ref<VehicleConstraint> _vehicle;
  std::unordered_map<std::string, BodyID> _meshes;
  float _throttle, _brake, _steering;
  double _accumulator;
  BOOL _paused;
  Vec3 _lastVelocity;
}
@end

@implementation DBJoltWorld
- (instancetype)init {
  if ((self = [super init])) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
      RegisterDefaultAllocator();
      Factory::sInstance = new Factory;
      RegisterTypes();
    });
    _temp = new TempAllocatorImpl(8 * 1024 * 1024);
    _jobs = new JobSystemThreadPool(cMaxPhysicsJobs, cMaxPhysicsBarriers, 2);
    _broad = new BroadLayer;
    _pairs = new PairFilter;
    _objectBroad = new ObjectBroadFilter;
    _physics = new PhysicsSystem;
    _physics->Init(4096, 0, 4096, 4096, *_broad, *_objectBroad, *_pairs);
    _physics->SetGravity(Vec3(0, -9.81f, 0));
    _paused = YES;
  }
  return self;
}
- (void)dealloc {
  [self removeVehicle];
  BodyInterface &bodies = _physics->GetBodyInterface();
  for (const auto &entry : _meshes) {
    bodies.RemoveBody(entry.second);
    bodies.DestroyBody(entry.second);
  }
  _meshes.clear();
  delete _physics; delete _jobs; delete _temp;
  delete _objectBroad; delete _pairs; delete _broad;
}
- (BOOL)isReady { return _vehicle != nullptr && !_car.IsInvalid(); }
- (void)removeVehicle {
  if (!_vehicle) return;
  _paused = YES;
  _physics->RemoveStepListener(_vehicle);
  _physics->RemoveConstraint(_vehicle);
  if (!_car.IsInvalid()) {
    BodyInterface &bodies = _physics->GetBodyInterface();
    bodies.RemoveBody(_car);
    bodies.DestroyBody(_car);
  }
  _vehicle = nullptr;
  _car = BodyID();
  _accumulator = 0;
}
- (BOOL)prepareVehicleAt:(simd_float3)p heading:(float)heading profile:(NSString *)name
                   error:(NSError **)error {
  [self removeVehicle];
  if (!IsFinite(p) || !std::isfinite(heading)) {
    SetError(error, 1, @"Die Platzierungstransformation ist nicht endlich.");
    return NO;
  }
  const Profile profile = ProfileNamed(name);
  constexpr float halfWidth = .075f, halfHeight = .025f, halfLength = .15f, radius = .025f;
  auto shapeResult = OffsetCenterOfMassShapeSettings(
    Vec3(0, -.018f, 0), new BoxShape(Vec3(halfWidth, halfHeight, halfLength))).Create();
  if (shapeResult.HasError()) {
    SetError(error, 2, @"Die Kollisionsform des Fahrzeugs konnte nicht erstellt werden.");
    return NO;
  }
  BodyCreationSettings body(shapeResult.Get(), RVec3(p.x, p.y + .075f, p.z),
    Quat::sRotation(Vec3::sAxisY(), heading), EMotionType::Dynamic, Layers::MOVING);
  body.mOverrideMassProperties = EOverrideMassProperties::CalculateInertia;
  body.mMassPropertiesOverride.mMass = profile.mass;
  BodyInterface &bodies = _physics->GetBodyInterface();
  Body *createdBody = bodies.CreateBody(body);
  if (createdBody == nullptr) {
    SetError(error, 3, @"Jolt konnte keinen Fahrzeugkörper reservieren.");
    return NO;
  }
  _car = createdBody->GetID();
  bodies.AddBody(_car, EActivation::Activate);

  VehicleConstraintSettings settings;
  settings.mMaxPitchRollAngle = DegreesToRadians(65.f);
  const Vec3 positions[] = {
    {halfWidth, -halfHeight, .105f}, {-halfWidth, -halfHeight, .105f},
    {halfWidth, -halfHeight, -.105f}, {-halfWidth, -halfHeight, -.105f}};
  for (int index = 0; index < 4; ++index) {
    auto *wheel = new WheelSettingsWV;
    wheel->mPosition = positions[index]; wheel->mRadius = radius; wheel->mWidth = .018f;
    wheel->mSuspensionMinLength = profile.clearance;
    wheel->mSuspensionMaxLength = profile.suspension;
    wheel->mSuspensionSpring.mFrequency = profile.frequency;
    wheel->mSuspensionSpring.mDamping = profile.damping;
    wheel->mMaxSteerAngle = index < 2 ? DegreesToRadians(profile.steer) : 0;
    wheel->mMaxBrakeTorque = 2.2f; wheel->mMaxHandBrakeTorque = index >= 2 ? 3.f : 0;
    settings.mWheels.push_back(wheel);
  }
  auto *controller = new WheeledVehicleControllerSettings;
  controller->mEngine.mMaxTorque = profile.torque;
  controller->mEngine.mMinRPM = 200; controller->mEngine.mMaxRPM = 6000;
  controller->mTransmission.mShiftUpRPM = 4500;
  controller->mDifferentials.resize(1);
  controller->mDifferentials[0].mLeftWheel = 2;
  controller->mDifferentials[0].mRightWheel = 3;
  settings.mController = controller;

  BodyLockWrite lock(_physics->GetBodyLockInterface(), _car);
  if (!lock.Succeeded()) {
    bodies.RemoveBody(_car); bodies.DestroyBody(_car); _car = BodyID();
    SetError(error, 4, @"Der Fahrzeugkörper konnte nicht gesperrt werden.");
    return NO;
  }
  _vehicle = new VehicleConstraint(lock.GetBody(), settings);
  _vehicle->SetVehicleCollisionTester(
    new VehicleCollisionTesterCastSphere(Layers::MOVING, .009f));
  _physics->AddConstraint(_vehicle);
  _physics->AddStepListener(_vehicle);
  _lastVelocity = Vec3::sZero(); _accumulator = 0; _paused = YES;
  return YES;
}
- (void)setThrottle:(float)t brake:(float)b steering:(float)s {
  _throttle = std::clamp(t, 0.f, 1.f); _brake = std::clamp(b, 0.f, 1.f);
  _steering = std::clamp(s, -1.f, 1.f);
}
- (void)setPaused:(BOOL)paused {
  _paused = paused;
  if (paused) [self setThrottle:0 brake:1 steering:0];
}
- (void)replaceStaticMesh:(NSUUID *)identifier vertices:(NSData *)vertexData
                  indices:(NSData *)indexData {
  if (vertexData.length == 0 || indexData.length == 0 ||
      vertexData.length % sizeof(simd_float3) != 0 || indexData.length % sizeof(uint32_t) != 0) return;
  const simd_float3 *inputVertices = (const simd_float3 *)vertexData.bytes;
  const uint32_t *inputIndices = (const uint32_t *)indexData.bytes;
  const NSUInteger vertexCount = vertexData.length / sizeof(simd_float3);
  VertexList vertices; vertices.reserve(vertexCount);
  for (NSUInteger index = 0; index < vertexCount; ++index) {
    if (!IsFinite(inputVertices[index])) return;
    vertices.push_back(Float3(inputVertices[index].x, inputVertices[index].y, inputVertices[index].z));
  }
  IndexedTriangleList triangles;
  for (NSUInteger index = 0; index + 2 < indexData.length / sizeof(uint32_t); index += 3) {
    if (inputIndices[index] >= vertexCount || inputIndices[index + 1] >= vertexCount ||
        inputIndices[index + 2] >= vertexCount) return;
    triangles.push_back(IndexedTriangle(inputIndices[index], inputIndices[index + 1], inputIndices[index + 2]));
  }
  if (triangles.empty()) return;
  auto result = MeshShapeSettings(vertices, triangles).Create();
  if (result.HasError()) return;
  BodyCreationSettings body(result.Get(), RVec3::sZero(), Quat::sIdentity(),
                            EMotionType::Static, Layers::STATIC);
  Body *created = _physics->GetBodyInterface().CreateBody(body);
  if (!created) return;
  std::string key(identifier.UUIDString.UTF8String);
  [self removeStaticMesh:identifier];
  _physics->GetBodyInterface().AddBody(created->GetID(), EActivation::DontActivate);
  _meshes[key] = created->GetID();
}
- (void)removeStaticMesh:(NSUUID *)identifier {
  auto iterator = _meshes.find(identifier.UUIDString.UTF8String);
  if (iterator == _meshes.end()) return;
  BodyInterface &bodies = _physics->GetBodyInterface();
  bodies.RemoveBody(iterator->second); bodies.DestroyBody(iterator->second);
  _meshes.erase(iterator);
}
- (DBJoltVehicleState *)step:(double)elapsed {
  DBJoltVehicleState *state = [DBJoltVehicleState new];
  if (![self isReady]) return state;
  if (!_paused && std::isfinite(elapsed) && elapsed > 0) {
    _accumulator += std::min(elapsed, .1);
    constexpr float timeStep = 1.f / 60.f;
    int count = 0;
    while (_accumulator >= timeStep && count++ < 4) {
      auto *controller = static_cast<WheeledVehicleController *>(_vehicle->GetController());
      controller->SetDriverInput(_throttle, _steering, _brake, _brake);
      if (_throttle != 0 || _steering != 0 || _brake != 0)
        _physics->GetBodyInterface().ActivateBody(_car);
      _physics->Update(timeStep, 1, _temp, _jobs);
      _accumulator -= timeStep;
    }
  }
  BodyInterface &bodies = _physics->GetBodyInterface();
  const RMat44 transform = bodies.GetWorldTransform(_car);
  const Vec3 velocity = bodies.GetLinearVelocity(_car);
  state.chassisTransform = Matrix(transform);
  state.speedMetersPerSecond = velocity.Length();
  state.collided = (velocity - _lastVelocity).Length() > 1.5f;
  _lastVelocity = velocity;
  NSMutableArray *wheelTransforms = [NSMutableArray arrayWithCapacity:4];
  for (uint index = 0; index < _vehicle->GetWheels().size(); ++index) {
    simd_float4x4 matrix = Matrix(
      _vehicle->GetWheelWorldTransform(index, Vec3::sAxisY(), Vec3::sAxisX()));
    [wheelTransforms addObject:[NSValue valueWithBytes:&matrix objCType:@encode(simd_float4x4)]];
  }
  state.wheelTransforms = wheelTransforms;
  return state;
}
@end
