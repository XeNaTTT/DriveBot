// The pinned Jolt PhysicsSystem selects its broad phase in its implementation.
// Compile that translation unit once with Jolt's direct body-bounds backend.
// This avoids cached parent bounds while AR surfaces are replaced during play.
// Load both class declarations before the translation-unit-local substitution.
#include <Jolt/Jolt.h>
#include <Jolt/Physics/Collision/BroadPhase/BroadPhaseBruteForce.h>
#include <Jolt/Physics/Collision/BroadPhase/BroadPhaseQuadTree.h>

#define BroadPhaseQuadTree BroadPhaseBruteForce
#include <Jolt/Physics/PhysicsSystem.cpp>
#undef BroadPhaseQuadTree
