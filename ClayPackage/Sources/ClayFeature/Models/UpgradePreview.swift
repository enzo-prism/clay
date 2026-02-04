import Foundation

public struct UpgradePreview {
    public var cost: ResourceAmount
    public var durationSeconds: Double
    public var deltaProductionPerHour: ResourceAmount
    public var deltaConsumptionPerHour: ResourceAmount
    public var deltaStorageCap: ResourceAmount
    public var deltaLogisticsCap: Double
    public var deltaProjectSpeed: Double
    public var deltaDefense: Double
}
