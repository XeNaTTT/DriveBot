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
end
