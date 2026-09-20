require 'minitest/autorun'

class DriveBotJoltIntegrationTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  PODSPEC = File.join(ROOT, 'ios/DriveBotJolt/DriveBotJolt.podspec')
  WRAPPER = File.join(ROOT, 'ios/DriveBotJolt/Sources/DriveBotJolt.mm')
  CODEMAGIC = File.join(ROOT, 'codemagic.yaml')

  def test_vendor_headers_are_not_added_to_cocoapods_header_map
    podspec = File.read(PODSPEC)

    source_files = podspec.lines.find { |line| line.include?('s.source_files') }
    refute_includes source_files, 'Vendor/Jolt/Jolt/**/*.{h,cpp}'
    assert_includes source_files, 'Vendor/Jolt/Jolt/**/*.cpp'
    refute_includes podspec, 's.header_mappings_dir'
  end

  def test_jolt_uses_one_non_recursive_include_root_and_libcxx
    podspec = File.read(PODSPEC)

    assert_includes podspec, '"${PODS_TARGET_SRCROOT}/Vendor/Jolt"'
    refute_match(/HEADER_SEARCH_PATHS.*\*\*/, podspec)
    assert_includes podspec, "'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17'"
    assert_includes podspec, "'CLANG_CXX_LIBRARY' => 'libc++'"
  end

  def test_wrapper_loads_jolt_base_header_before_other_headers
    includes = File.readlines(WRAPPER).grep(/^#(?:include|import)/)

    assert_equal '#include <Jolt/Jolt.h>', includes.first.strip
  end

  def test_disabled_features_are_not_defined_as_zero
    podspec = File.read(PODSPEC)

    refute_match(/JPH_[A-Z0-9_]+=0/, podspec)
  end

  def test_vehicle_creation_checks_each_fallible_jolt_resource
    wrapper = File.read(WRAPPER)

    assert_includes wrapper, 'shapeResult.HasError()'
    assert_includes wrapper, 'Body *createdBody = bodies.CreateBody(body)'
    assert_includes wrapper, 'if (lock.Succeeded())'
    assert_match(/}\n  if \(_vehicle == nullptr/, wrapper)
    assert_includes wrapper, '- (void)removeVehicle'
    refute_includes wrapper, 'Create().Get()'
  end

  def test_mesh_boundary_validates_buffer_layout_and_indices
    wrapper = File.read(WRAPPER)

    assert_includes wrapper, 'vertexData.length % sizeof(simd_float3)'
    assert_includes wrapper, 'inputIndices[index] >= vertexCount'
    assert_includes wrapper, 'if (!IsFinite(inputVertices[index])) return;'
  end

  def test_step_uses_typed_scalar_transport_and_validates_before_insertion
    wrapper = File.read(WRAPPER)

    assert_includes wrapper, '_vehicle->GetWheels().size() != 4'
    assert_includes wrapper, 'if (wheels[index] == nullptr)'
    assert_includes wrapper, 'updateError != EPhysicsUpdateError::None'
    assert_includes wrapper, 'DBJoltTransform *value = TransformValue(wheelMatrix, index)'
    assert_match(/if \(value == nil\).*?return failure/m, wrapper)
    assert_match(/if \(value == nil\).*?\[wheelTransforms addObject:value\]/m, wrapper)
    refute_includes wrapper, 'initWithBytes:&matrix objCType:@encode(simd_float4x4)'
    assert_includes wrapper, 'value.positionX = (float)position.GetX()'
    assert_includes wrapper, 'matrix.GetQuaternion().Normalized()'
    refute_includes wrapper, 'matrix.GetRotation().Normalized()'
    assert_includes wrapper, '} @catch (NSException *exception) {'
  end

  def test_native_build_log_is_preserved_without_masking_xcodebuild_status
    codemagic = File.read(CODEMAGIC)

    assert_includes codemagic, 'build 2>&1 | tee build/native-logs/jolt-xcodebuild.log'
    assert_includes codemagic, 'XCODEBUILD_STATUS=${PIPESTATUS[0]}'
    assert_includes codemagic, 'exit "$XCODEBUILD_STATUS"'
    assert_includes codemagic, '- build/native-logs/*.log'
  end
end
