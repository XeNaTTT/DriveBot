require 'minitest/autorun'

class DriveBotJoltIntegrationTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  PODSPEC = File.join(ROOT, 'ios/DriveBotJolt/DriveBotJolt.podspec')
  WRAPPER = File.join(ROOT, 'ios/DriveBotJolt/Sources/DriveBotJolt.mm')

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
    assert_includes wrapper, 'if (!lock.Succeeded())'
    assert_includes wrapper, '- (void)removeVehicle'
    refute_includes wrapper, 'Create().Get()'
  end

  def test_mesh_boundary_validates_buffer_layout_and_indices
    wrapper = File.read(WRAPPER)

    assert_includes wrapper, 'vertexData.length % sizeof(simd_float3)'
    assert_includes wrapper, 'inputIndices[index] >= vertexCount'
    assert_includes wrapper, 'if (!IsFinite(inputVertices[index])) return;'
  end
end
