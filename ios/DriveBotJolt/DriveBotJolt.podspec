Pod::Spec.new do |s|
  s.name = 'DriveBotJolt'
  s.version = '5.6.0'
  s.summary = 'Pinned Jolt Physics vehicle bridge for DriveBot'
  s.homepage = 'https://github.com/jrouwe/JoltPhysics'
  s.license = { :type => 'MIT', :file => 'Vendor/Jolt/LICENSE' }
  s.author = 'DriveBot'
  s.platform = :ios, '15.0'
  s.source = { :git => 'https://github.com/jrouwe/JoltPhysics.git', :commit => 'e77f175595e64cb44218cc9d9d56fc365ad0e36a' }
  s.prepare_command = <<-CMD
    set -eu
    if [ ! -f Vendor/Jolt/Jolt/Jolt.h ]; then
      rm -rf Vendor/Jolt
      git clone --depth 1 --branch v5.6.0 https://github.com/jrouwe/JoltPhysics.git Vendor/Jolt
    fi
    test "$(git -C Vendor/Jolt rev-parse HEAD)" = "e77f175595e64cb44218cc9d9d56fc365ad0e36a"
  CMD
  s.source_files = 'Sources/**/*.{h,mm}', 'Vendor/Jolt/Jolt/**/*.{h,cpp}'
  s.public_header_files = 'Sources/DriveBotJolt.h'
  s.header_mappings_dir = '.'
  s.preserve_paths = 'Vendor/Jolt/LICENSE'
  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/Vendor/Jolt"',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) JPH_OBJECT_STREAM=0 JPH_DEBUG_RENDERER=0 JPH_PROFILE_ENABLED=0 JPH_FLOATING_POINT_EXCEPTIONS_ENABLED=0'
  }
  s.frameworks = 'Foundation'
end
