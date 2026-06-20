import Foundation

enum HealthDataType: String, Codable, CaseIterable {
    case heartRate = "heart-rate"
    case dailyRestingHeartRate = "daily-resting-heart-rate"
    case dailyHeartRateVariability = "daily-heart-rate-variability"
    case dailyHeartRateZones = "daily-heart-rate-zones"
    case sleep = "sleep"
    case steps = "steps"
    case distance = "distance"
    case activeEnergyBurned = "active-energy-burned"
    case exercise = "exercise"
    case activeZoneMinutes = "active-zone-minutes"
    case vo2Max = "run-vo2-max"
    case weight = "weight"
    case bodyFat = "body-fat"
    case coreBodyTemperature = "core-body-temperature"
    case skinTemperature = "skin-temperature"
    case oxygenSaturation = "daily-oxygen-saturation"
    case respiratoryRate = "daily-respiratory-rate"
    case sleepStages = "sleep-stages"
    case bloodPressure = "blood-pressure"
}
