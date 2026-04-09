//
//  OnDeviceAIEngine.swift
//  Optly
//
//  Core ML model loading with heuristic fallbacks; predictions stay on device.
//

import Foundation
#if canImport(CoreML)
import CoreML
#endif

// MARK: - Errors

public enum OnDeviceAIError: LocalizedError, Sendable {
    case modelNotFound(String)
    case predictionFailed(underlying: Error)
    case unsupportedInput

    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let name):
            return "Core ML model not found in bundle: \(name)"
        case .predictionFailed(let e):
            return "On-device prediction failed: \(e.localizedDescription)"
        case .unsupportedInput:
            return "The provided input is not supported for this model."
        }
    }
}

// MARK: - Input / output types

public struct EnergyPredictionInput: Sendable {
    public var sleepHours: Double
    public var stepCount: Double
    public var activeEnergy: Double
    public var meetingDensity: Double
    public var hourOfDay: Int

    public init(sleepHours: Double, stepCount: Double, activeEnergy: Double, meetingDensity: Double, hourOfDay: Int) {
        self.sleepHours = sleepHours
        self.stepCount = stepCount
        self.activeEnergy = activeEnergy
        self.meetingDensity = meetingDensity
        self.hourOfDay = hourOfDay
    }
}

public struct HabitSuccessInput: Sendable {
    public var streakDays: Int
    public var completionRate7d: Double
    public var preferredSlotFree: Bool
    public var weekend: Bool

    public init(streakDays: Int, completionRate7d: Double, preferredSlotFree: Bool, weekend: Bool) {
        self.streakDays = streakDays
        self.completionRate7d = completionRate7d
        self.preferredSlotFree = preferredSlotFree
        self.weekend = weekend
    }
}

public struct SpendingAnomalyInput: Sendable {
    public var categorySpendZScore: Double
    public var monthOverMonthChange: Double
    public var recurringShare: Double

    public init(categorySpendZScore: Double, monthOverMonthChange: Double, recurringShare: Double) {
        self.categorySpendZScore = categorySpendZScore
        self.monthOverMonthChange = monthOverMonthChange
        self.recurringShare = recurringShare
    }
}

/// A free calendar interval paired with an on-device energy score for that window (e.g. from ``predictEnergyLevel``).
public struct ScoredTimeSlot: Sendable {
    public var interval: DateInterval
    public var energyScore: Double

    public init(interval: DateInterval, energyScore: Double) {
        self.interval = interval
        self.energyScore = energyScore
    }
}

// MARK: - Engine

/// Loads bundled Core ML models when present; otherwise uses transparent heuristics.
public final class OnDeviceAIEngine: @unchecked Sendable {

    private let bundle: Bundle
    #if canImport(CoreML)
    private var energyModel: MLModel?
    #endif

    /// Names of `.mlmodelc` resources in the app bundle (omit extension).
    public var energyModelName: String?

    public init(bundle: Bundle = .main, energyModelName: String? = "EnergyPredictor") {
        self.bundle = bundle
        self.energyModelName = energyModelName
    }

    // MARK: Model lifecycle

    /// Loads optional Core ML models; safe to call multiple times.
    public func loadModels() throws {
        #if canImport(CoreML)
        guard let name = energyModelName else { return }
        guard let url = bundle.url(forResource: name, withExtension: "mlmodelc") else {
            energyModel = nil
            return
        }
        do {
            energyModel = try MLModel(contentsOf: url)
        } catch {
            energyModel = nil
            throw OnDeviceAIError.predictionFailed(underlying: error)
        }
        #endif
    }

    // MARK: Predictions

    public func predictEnergyLevel(input: EnergyPredictionInput) async -> Double {
        #if canImport(CoreML)
        if let model = energyModel {
            do {
                let dict: [String: NSNumber] = [
                    "sleep_hours": NSNumber(value: input.sleepHours),
                    "steps": NSNumber(value: input.stepCount),
                    "active_energy": NSNumber(value: input.activeEnergy),
                    "meeting_density": NSNumber(value: input.meetingDensity),
                    "hour": NSNumber(value: input.hourOfDay)
                ]
                let provider = try MLDictionaryFeatureProvider(dictionary: dict)
                let out = try model.prediction(from: provider)
                if let score = out.featureValue(for: "energy_score")?.doubleValue {
                    return min(100, max(0, score))
                }
            } catch {
                // Fall through to heuristic
            }
        }
        #endif
        return Self.heuristicEnergy(from: input)
    }

    public func habitSuccessProbability(input: HabitSuccessInput) -> Double {
        var p = input.completionRate7d * 0.55
        p += min(0.25, Double(min(input.streakDays, 14)) / 14 * 0.25)
        p += input.preferredSlotFree ? 0.15 : -0.05
        p += input.weekend ? -0.05 : 0.05
        return min(0.99, max(0.01, p))
    }

    public func spendingAnomalyScore(input: SpendingAnomalyInput) -> Double {
        let z = abs(input.categorySpendZScore)
        let mom = max(0, input.monthOverMonthChange)
        let recurring = input.recurringShare
        let raw = z * 0.4 + mom * 0.4 + recurring * 0.2
        return min(100, max(0, raw * 25))
    }

    /// Picks the longest feasible sub-interval of `habitDurationMinutes` inside each free slot, favoring higher ``ScoredTimeSlot/energyScore`` and closeness to target duration.
    public func suggestOptimalSchedule(
        scoredFreeSlots: [ScoredTimeSlot],
        habitDurationMinutes: Int
    ) -> DateInterval? {
        let need = Double(habitDurationMinutes * 60)
        var best: (interval: DateInterval, score: Double)?
        for slot in scoredFreeSlots {
            guard slot.interval.duration >= need else { continue }
            let candidate = DateInterval(start: slot.interval.start, duration: need)
            let fitPenalty = abs(slot.interval.duration - need)
            let combined = slot.energyScore - fitPenalty / 60
            if best == nil || combined > best!.score {
                best = (candidate, combined)
            }
        }
        return best?.interval
    }

    // MARK: Heuristics

    public static func heuristicEnergy(from input: EnergyPredictionInput) -> Double {
        let sleep = min(100, (input.sleepHours / 8) * 100)
        let steps = min(100, (input.stepCount / 10_000) * 100)
        let cal = min(100, (input.activeEnergy / 500) * 100)
        let meetingPenalty = input.meetingDensity * 40
        let hourBoost = (input.hourOfDay >= 9 && input.hourOfDay <= 11) ? 5.0 : 0
        let base = sleep * 0.4 + steps * 0.25 + cal * 0.25 + hourBoost
        return min(100, max(0, base - meetingPenalty))
    }
}
