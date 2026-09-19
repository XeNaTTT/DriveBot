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
#include <unordered_map>

using namespace JPH;
namespace {
namespace Layers { static constexpr ObjectLayer STATIC = 0, MOVING = 1, COUNT = 2; }
class PairFilter final : public ObjectLayerPairFilter { public: bool ShouldCollide(ObjectLayer a,ObjectLayer b) const override { return a==Layers::MOVING||b==Layers::MOVING; } };
class BroadLayer final : public BroadPhaseLayerInterface {
  BroadPhaseLayer layers[2] = {BroadPhaseLayer(0), BroadPhaseLayer(1)};
public: uint GetNumBroadPhaseLayers() const override{return 2;} BroadPhaseLayer GetBroadPhaseLayer(ObjectLayer l) const override{return layers[l];}
#if defined(JPH_EXTERNAL_PROFILE) || defined(JPH_PROFILE_ENABLED)
  const char *GetBroadPhaseLayerName(BroadPhaseLayer l) const override{return l==layers[0]?"Static":"Moving";}
#endif
};
class ObjectBroadFilter final : public ObjectVsBroadPhaseLayerFilter { public: bool ShouldCollide(ObjectLayer l,BroadPhaseLayer b) const override{return l==Layers::MOVING||b==BroadPhaseLayer(1);} };
static simd_float4x4 Matrix(RMat44 m) { simd_float4x4 out; for(int c=0;c<4;c++) for(int r=0;r<4;r++) out.columns[c][r]=(float)m(c,r); return out; }
}

@implementation DBJoltVehicleState @end

@interface DBJoltWorld () { PhysicsSystem *_physics; TempAllocatorImpl *_temp; JobSystemThreadPool *_jobs; BroadLayer *_broad; PairFilter *_pairs; ObjectBroadFilter *_objectBroad; BodyID _car; Ref<VehicleConstraint> _vehicle; std::unordered_map<std::string, BodyID> _meshes; float _throttle,_brake,_steering; double _accumulator; BOOL _paused; Vec3 _lastVelocity; } @end

@implementation DBJoltWorld
- (instancetype)init { if ((self=[super init])) { static dispatch_once_t once; dispatch_once(&once, ^{ RegisterDefaultAllocator(); Factory::sInstance=new Factory; RegisterTypes(); }); _temp=new TempAllocatorImpl(8*1024*1024); _jobs=new JobSystemThreadPool(cMaxPhysicsJobs,cMaxPhysicsBarriers,2); _broad=new BroadLayer; _pairs=new PairFilter; _objectBroad=new ObjectBroadFilter; _physics=new PhysicsSystem; _physics->Init(4096,0,4096,4096,*_broad,*_objectBroad,*_pairs); _physics->SetGravity(Vec3(0,-9.81f,0)); _accumulator=0; } return self; }
- (void)dealloc { if (_vehicle) { _physics->RemoveStepListener(_vehicle); _physics->RemoveConstraint(_vehicle); } delete _physics; delete _jobs; delete _temp; delete _objectBroad; delete _pairs; delete _broad; }
- (void)resetAt:(simd_float3)p heading:(float)heading {
  BodyInterface &bi=_physics->GetBodyInterface();
  if (_vehicle) { _physics->RemoveStepListener(_vehicle); _physics->RemoveConstraint(_vehicle); bi.RemoveBody(_car); bi.DestroyBody(_car); _vehicle=nullptr; }
  const float halfW=.075f, halfH=.025f, halfL=.15f, radius=.025f;
  RefConst<Shape> shape=OffsetCenterOfMassShapeSettings(Vec3(0,-.018f,0),new BoxShape(Vec3(halfW,halfH,halfL))).Create().Get();
  BodyCreationSettings body(shape,RVec3(p.x,p.y+.075f,p.z),Quat::sRotation(Vec3::sAxisY(),heading),EMotionType::Dynamic,Layers::MOVING); body.mOverrideMassProperties=EOverrideMassProperties::CalculateInertia; body.mMassPropertiesOverride.mMass=1.8f;
  _car=bi.CreateAndAddBody(body,EActivation::Activate);
  VehicleConstraintSettings settings; settings.mMaxPitchRollAngle=DegreesToRadians(65.f);
  const Vec3 positions[]={{halfW,-halfH,.105f},{-halfW,-halfH,.105f},{halfW,-halfH,-.105f},{-halfW,-halfH,-.105f}};
  for(int i=0;i<4;i++){ auto *w=new WheelSettingsWV; w->mPosition=positions[i]; w->mRadius=radius; w->mWidth=.018f; w->mSuspensionMinLength=.005f; w->mSuspensionMaxLength=.035f; w->mSuspensionSpring.mFrequency=3.0f; w->mSuspensionSpring.mDamping=.65f; w->mMaxSteerAngle=i<2?DegreesToRadians(30.f):0; w->mMaxBrakeTorque=2.2f; w->mMaxHandBrakeTorque=i>=2?3.f:0; settings.mWheels.push_back(w); }
  auto *controller=new WheeledVehicleControllerSettings; controller->mEngine.mMaxTorque=1.8f; controller->mEngine.mMinRPM=200; controller->mEngine.mMaxRPM=6000; controller->mTransmission.mShiftUpRPM=4500; controller->mDifferentials.resize(1); controller->mDifferentials[0].mLeftWheel=2; controller->mDifferentials[0].mRightWheel=3; settings.mController=controller;
  BodyLockWrite lock(_physics->GetBodyLockInterface(),_car); _vehicle=new VehicleConstraint(lock.GetBody(),settings); _vehicle->SetVehicleCollisionTester(new VehicleCollisionTesterCastSphere(Layers::MOVING,.009f)); _physics->AddConstraint(_vehicle); _physics->AddStepListener(_vehicle); _lastVelocity=Vec3::sZero(); _accumulator=0;
}
- (void)setThrottle:(float)t brake:(float)b steering:(float)s { _throttle=std::clamp(t,0.f,1.f); _brake=std::clamp(b,0.f,1.f); _steering=std::clamp(s,-1.f,1.f); }
- (void)setPaused:(BOOL)p { _paused=p; if(p) [self setThrottle:0 brake:1 steering:0]; }
- (void)replaceStaticMesh:(NSUUID *)identifier vertices:(NSData *)vd indices:(NSData *)idat {
  std::string key(identifier.UUIDString.UTF8String); [self removeStaticMesh:identifier];
  const simd_float3 *v=(const simd_float3 *)vd.bytes; const uint32_t *idx=(const uint32_t *)idat.bytes; VertexList vertices; IndexedTriangleList tris; vertices.reserve(vd.length/sizeof(simd_float3)); for(NSUInteger i=0;i<vd.length/sizeof(simd_float3);i++) vertices.push_back(Float3(v[i].x,v[i].y,v[i].z)); for(NSUInteger i=0;i+2<idat.length/sizeof(uint32_t);i+=3) tris.push_back(IndexedTriangle(idx[i],idx[i+1],idx[i+2]));
  auto result=MeshShapeSettings(vertices,tris).Create(); if(result.HasError()) return; BodyCreationSettings body(result.Get(),RVec3::sZero(),Quat::sIdentity(),EMotionType::Static,Layers::STATIC); BodyID bid=_physics->GetBodyInterface().CreateAndAddBody(body,EActivation::DontActivate); _meshes[key]=bid;
}
- (void)removeStaticMesh:(NSUUID *)identifier { auto it=_meshes.find(identifier.UUIDString.UTF8String); if(it==_meshes.end()) return; auto &bi=_physics->GetBodyInterface(); bi.RemoveBody(it->second); bi.DestroyBody(it->second); _meshes.erase(it); }
- (DBJoltVehicleState *)step:(double)elapsed { DBJoltVehicleState *state=[DBJoltVehicleState new]; if(_vehicle && !_paused){ _accumulator+=std::min(elapsed,.1); const float dt=1.f/60.f; int count=0; while(_accumulator>=dt&&count++<4){ auto *c=static_cast<WheeledVehicleController *>(_vehicle->GetController()); c->SetDriverInput(_throttle,_steering,_brake,_brake); if(_throttle!=0||_steering!=0||_brake!=0) _physics->GetBodyInterface().ActivateBody(_car); _physics->Update(dt,1,_temp,_jobs); _accumulator-=dt; }} if(!_vehicle) return state; auto &bi=_physics->GetBodyInterface(); RMat44 transform=bi.GetWorldTransform(_car); Vec3 velocity=bi.GetLinearVelocity(_car); state.chassisTransform=Matrix(transform); state.speedMetersPerSecond=velocity.Length(); state.collided=(velocity-_lastVelocity).Length()>1.5f; _lastVelocity=velocity; NSMutableArray *wheels=[NSMutableArray arrayWithCapacity:4]; for(uint i=0;i<4;i++){ simd_float4x4 m=Matrix(_vehicle->GetWheelWorldTransform(i,Vec3::sAxisY(),Vec3::sAxisX())); [wheels addObject:[NSValue valueWithBytes:&m objCType:@encode(simd_float4x4)]]; } state.wheelTransforms=wheels; return state; }
@end
