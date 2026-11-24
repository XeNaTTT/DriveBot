require 'minitest/autorun'

class ArRacingIosCompatibilityTest < Minitest::Test
  SOURCE = File.read(File.expand_path('../ios/Runner/ArRacingView.swift', __dir__))
  VEHICLE = File.read(File.expand_path('../ios/Runner/RallyVehicleVisual.swift', __dir__))

  def test_building_visit_hud_and_walking_control_contract
    assert_includes SOURCE, 'let canUseShop = mode == .onFoot && shop != nil'
    assert_includes SOURCE, 'canUseShop ? "Betreten"'
    assert_includes SOURCE, 'mode = .visiting'
    assert_includes SOURCE, 'if mode == .onFoot { walkInput = input; return }'
    completion = SOURCE.split('if step.done {', 2).last.split('guard settingsPanel.isHidden', 2).first
    assert_includes completion, 'mode = .onFoot'
    assert_includes completion, 'inventory.pick(item)'
    cancellation = SOURCE.split('func interrupted()', 2).last.split('private var door:', 2).first
    assert_includes cancellation, 'avatar.root.setPosition(visit.start, relativeTo: nil)'
    assert_includes cancellation, 'avatar.root.isEnabled = true'
  end

  def test_wheels_use_ios_15_mesh_generation
    assert_includes VEHICLE, 'MeshResource.generate(from: [descriptor])'
    refute_includes VEHICLE, '.generateCylinder'
  end

  def test_wheel_world_transform_is_converted_to_chassis_local_space
    assert_includes SOURCE, 'let inverseChassis = chassisTransform.inverse'
    assert_includes SOURCE, 'chassisLocal: inverseChassis * matrix, visualScale: scale'
    assert_includes VEHICLE, 'chassisLocal.columns.3.x / visualScale'
    refute_includes SOURCE, 'wheels[i].setTransformMatrix(value.matrix!, relativeTo: nil)'
  end

  def test_vehicle_moves_under_a_fixed_anchor_and_relocalizes
    assert_includes SOURCE, 'anchor.addChild(pose)'
    assert_includes SOURCE, 'pose.setTransformMatrix(chassisTransform, relativeTo: nil)'
    refute_includes SOURCE, 'anchor.transform.matrix = chassisTransform'
    recovery = SOURCE.split('func sessionInterruptionEnded', 2).last.split('func session(', 2).first
    refute_includes recovery, 'startSession()'
    refute_includes recovery, 'removeVehicle()'
  end

  def test_busy_display_frames_keep_elapsed_time
    assert_match(/!physicsStepPending.*let dt = previousTime.*previousTime = link.timestamp/m, SOURCE)
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
    assert_includes SOURCE, 'steeringPad.isHidden = !playing'
    assert_includes SOURCE, 'mode == .onFoot && nearDoor'
    assert_includes SOURCE, 'physics.setPaused(mode != .driving)'
    refute_match(/scan.*percent|scan.*progress/i, SOURCE)
  end

  def test_five_centimetre_hierarchy_is_bounds_normalized_once
    assert_includes SOURCE, 'let bounds = visualRoot.visualBounds(relativeTo: visualRoot)'
    assert_includes SOURCE, 'let uniformScale = RallyScale.metres(6.5) / modelLength'
    assert_includes SOURCE, 'visualRoot.scale = SIMD3(repeating: uniformScale)'
    assert_equal 1, SOURCE.scan(/visualRoot\.scale =/).size
  end

  def test_independent_pedals_motion_calibration_and_debug_hud
    assert_match(/throttleButton\.addTarget.*touchDown.*touchDragEnter/m, SOURCE)
    assert_match(/throttleButton\.addTarget.*touchUpInside.*touchUpOutside.*touchCancel/m, SOURCE)
    assert_match(/brakeButton\.addTarget.*touchUpInside.*touchUpOutside.*touchCancel/m, SOURCE)
    assert_includes SOURCE, 'physics.setThrottle(pedals.throttle, brake: pedals.brake'
    assert_includes SOURCE, 'case .landscapeLeft: return -gravity.y'
    assert_includes SOURCE, 'case .landscapeRight: return gravity.y'
    assert_includes SOURCE, 'Gas %+.1f | Bremse %.1f | Lenkung %+.2f'
  end
end
