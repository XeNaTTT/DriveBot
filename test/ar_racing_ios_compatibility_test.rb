require 'minitest/autorun'

class ArRacingIosCompatibilityTest < Minitest::Test
  SOURCE = File.read(File.expand_path('../ios/Runner/ArRacingView.swift', __dir__))

  def test_ios_18_cylinder_has_an_older_system_fallback
    assert_match(/if #available\(iOS 18\.0, \*\).*generateCylinder/m, SOURCE)
    assert_match(/return \.generateBox\(size: \[radius \* 2, width, radius \* 2\]/, SOURCE)
  end

  def test_wheel_world_transform_is_converted_to_chassis_local_space
    assert_includes SOURCE, 'let inverseChassis = chassisTransform.inverse'
    assert_includes SOURCE, 'wheels[i].transform.matrix = inverseVisualScale * inverseChassis * value.matrix!'
    refute_includes SOURCE, 'wheels[i].setTransformMatrix(value.matrix!, relativeTo: nil)'
  end

  def test_mesh_classification_reads_the_optional_source_safely
    assert_includes SOURCE, 'let classifications = classification'
    assert_includes SOURCE, 'classifications.format == .uchar'
    assert_includes SOURCE, 'byteOffset < classifications.buffer.length'
    assert_includes SOURCE, 'ARMeshClassification(rawValue: Int(rawValue)) ?? .none'
  end

  def test_mesh_indices_use_the_geometry_helper_and_checked_width_conversion
    assert_includes SOURCE, 'UInt32(exactly: faceIndex)'
    assert_includes SOURCE, 'geometry.vertexIndex('
    refute_includes SOURCE, 'geometry.faces.index(of:'
  end

  def test_mesh_index_reader_checks_layout_and_buffer_bounds
    assert_includes SOURCE, 'faces.bytesPerIndex == MemoryLayout<UInt16>.size'
    assert_includes SOURCE, 'bufferEnd <= faces.buffer.length'
    assert_includes SOURCE, 'let vertexCount32 = UInt32(exactly: geometry.vertices.count)'
    assert_includes SOURCE, 'vertexIndex < vertexCount32'
  end

  def test_placement_is_guarded_and_transactional
    assert_includes SOURCE, 'guard phase == .aiming, let candidate = placementCandidate'
    assert_includes SOURCE, 'physics.prepareVehicle('
    assert_includes SOURCE, 'physics.removeVehicle()'
    assert_includes SOURCE, 'placementGeneration += 1'
    (1..10).each do |step|
      assert_match(/\[Placement\] #{format('%02d', step)} /, SOURCE)
    end
    assert_includes SOURCE, 'private let placementPhysicsMode: PlacementPhysicsMode = .fullJolt'
    assert_includes SOURCE, 'DRIVEBOT_VISUAL_ONLY_PLACEMENT'
    refute_includes SOURCE, 'generateCollisionShapes(recursive: true)'
  end

  def test_jolt_calls_are_serialized_away_from_realitykit
    assert_includes SOURCE, 'private final class SerializedJoltWorld'
    assert_includes SOURCE, 'DispatchQueue(label: "de.drivebot.physics"'
    assert_includes SOURCE, 'DispatchQueue.main.async { completion(result) }'
    assert_includes SOURCE, 'guard placementPhysicsMode == .fullJolt, !physicsStepPending'
  end

  def test_scan_and_driving_hud_follow_real_state
    assert_includes SOURCE, 'arView.debugOptions.insert(.showSceneUnderstanding)'
    assert_includes SOURCE, 'allowing: .existingPlaneGeometry'
    assert_includes SOURCE, 'speed.isHidden = phase != .ready'
    assert_includes SOURCE, 'steeringPad.isHidden = true'
    refute_match(/scan.*percent|scan.*progress/i, SOURCE)
  end

  def test_five_centimetre_hierarchy_is_bounds_normalized_once
    assert_includes SOURCE, 'let bounds = visualRoot.visualBounds(relativeTo: visualRoot)'
    assert_includes SOURCE, 'let uniformScale = Float(0.05) / modelLength'
    assert_includes SOURCE, 'visualRoot.scale = SIMD3(repeating: uniformScale)'
    assert_equal 1, SOURCE.scan(/visualRoot\.scale =/).size
  end

  def test_independent_pedals_motion_calibration_and_debug_hud
    assert_match(/throttleButton\.addTarget.*touchDown.*touchDragEnter/m, SOURCE)
    assert_match(/throttleButton\.addTarget.*touchUpInside.*touchUpOutside.*touchCancel/m, SOURCE)
    assert_match(/brakeButton\.addTarget.*touchUpInside.*touchUpOutside.*touchCancel/m, SOURCE)
    assert_includes SOURCE, 'brake > 0 ? 0 : throttle'
    assert_includes SOURCE, 'case .landscapeLeft: return -gravity.y'
    assert_includes SOURCE, 'case .landscapeRight: return gravity.y'
    assert_includes SOURCE, 'Gas %.1f | Bremse %.1f | Lenkung %+.2f'
  end
end
