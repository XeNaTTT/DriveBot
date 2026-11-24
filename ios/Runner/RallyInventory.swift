import RealityKit
import UIKit

enum RallyItem: Int, CaseIterable {
  case nos, sword, blaster, wings
  var symbol: String { ["bolt.fill","sparkles","scope","wind"][rawValue] }
  var title: String { ["NOS-Booster", "Laserschwert", "Virtuelles Gewehr", "Cessna-Tragflächen"][rawValue] }
  @MainActor func model() -> Entity? {
    guard let url = Bundle.main.url(forResource: "Item" + String(rawValue), withExtension: "usdz", subdirectory: "RallyAssets"),
          let model = try? Entity.load(contentsOf: url) else { return nil }
    if self == .sword {
      func illuminate(_ entity: Entity) {
        if let blade = entity as? ModelEntity, entity.name.lowercased().contains("blade") {
          var finish = PhysicallyBasedMaterial()
          finish.baseColor = .init(tint: .cyan)
          finish.emissiveColor = .init(color: .cyan)
          finish.emissiveIntensity = 2.4
          blade.model?.materials = [finish]
        }
        for child in entity.children { illuminate(child) }
      }
      illuminate(model)
    }
    model.scale = SIMD3(repeating: RallyScale.factor)
    return model
  }
}

struct RallyInventory {
  private(set) var collected: Set<RallyItem> = []
  private(set) var held: RallyItem?
  private(set) var wings = false
  private(set) var remaining: Float = 0
  var boosting = false
  private var previous: SIMD2<Float>?

  mutating func pick(_ item: RallyItem) -> Bool {
    guard collected.insert(item).inserted else { return false }
    held = item
    return true
  }

  mutating func enterVehicle() {
    if collected.contains(.nos), remaining == 0, !spent { remaining = 10 }
    wings = collected.contains(.wings)
    if held == .nos || held == .wings {
      held = collected.contains(.sword) ? .sword : collected.contains(.blaster) ? .blaster : nil
    }
    stopBoost()
  }

  private var spent = false
  mutating func stopBoost() { boosting = false; previous = nil }
  mutating func sample(_ position: SIMD2<Float>, elapsed: Float, speed: Float) {
    guard boosting, remaining > 0 else { previous = nil; return }
    defer { previous = boosting ? position : nil }
    guard let previous, elapsed > 0 else { return }
    let distance = simd_distance(previous, position)
    guard distance.isFinite, distance <= max(0.005, speed * min(elapsed,0.1) * 2 + 0.002) else { return }
    remaining = max(0, remaining - distance)
    if remaining == 0 { spent = true; stopBoost() }
  }

  func shouldGlide(groundedWheels: Int) -> Bool { wings && groundedWheels == 0 }

  mutating func cycle() {
    guard collected.contains(.sword), collected.contains(.blaster) else { return }
    held = held == .sword ? .blaster : .sword
  }
}
