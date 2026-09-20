require 'minitest/autorun'

class ArRacingIosCompatibilityTest < Minitest::Test
  SOURCE = File.read(File.expand_path('../ios/Runner/ArRacingView.swift', __dir__))

  def test_ios_18_cylinder_has_an_older_system_fallback
    assert_match(/if #available\(iOS 18\.0, \*\).*generateCylinder/m, SOURCE)
    assert_match(/return \.generateBox\(size: \[0\.05, 0\.018, 0\.05\]/, SOURCE)
  end

  def test_wheel_transform_uses_realitykit_setter
    assert_includes SOURCE, 'wheels[i].setTransformMatrix(matrix, relativeTo: nil)'
    refute_includes SOURCE, 'transformMatrix(relativeTo: nil) = matrix'
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
    assert_includes SOURCE, 'DispatchQueue.main.async { completion(.success(state)) }'
    assert_includes SOURCE, 'guard placementPhysicsMode == .fullJolt, !physicsStepPending'
  end

  def test_scan_and_driving_hud_follow_real_state
    assert_includes SOURCE, 'arView.debugOptions.insert(.showSceneUnderstanding)'
    assert_includes SOURCE, 'allowing: .existingPlaneGeometry'
    assert_includes SOURCE, 'speed.isHidden = phase != .ready'
    assert_includes SOURCE, 'steeringPad.isHidden = true'
    refute_match(/scan.*percent|scan.*progress/i, SOURCE)
  end
end
