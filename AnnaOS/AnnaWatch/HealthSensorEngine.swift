import Foundation
import HealthKit
import CoreMotion

protocol SensorProviding: AnyObject {
    var onStateUpdate: ((SensorState) -> Void)? { get set }
    func start()
    func stop()
}

final class HealthSensorEngine: SensorProviding {
    var onStateUpdate: ((SensorState) -> Void)?

    private let healthStore = HKHealthStore()
    private let motionManager = CMMotionManager()
    private let altimeter = CMAltimeter()
    private var heartRate: Double = 72
    private var barometer: Double = 101325
    private var acceleration: Double = 0
    private var gyroscope: Double = 0
    private var timer: Timer?

    func start() {
        requestHealthAuthorization()
        startMotion()
        startAltimeter()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.emitState()
        }
    }

    func stop() {
        timer?.invalidate()
        motionManager.stopDeviceMotionUpdates()
        altimeter.stopRelativeAltitudeUpdates()
    }

    private func requestHealthAuthorization() {
        guard HKHealthStore.isHealthDataAvailable(),
              let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        healthStore.requestAuthorization(toShare: nil, read: [heartRateType]) { [weak self] _, _ in
            self?.startHeartRateQuery()
        }
    }

    private func startHeartRateQuery() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.processHeartRateSamples(samples)
        }

        query.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processHeartRateSamples(samples)
        }

        healthStore.execute(query)
    }

    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let sample = (samples?.last as? HKQuantitySample) else { return }
        let unit = HKUnit.count().unitDivided(by: .minute())
        let bpm = sample.quantity.doubleValue(for: unit)
        DispatchQueue.main.async { [weak self] in
            self?.heartRate = bpm
        }
    }

    private func startMotion() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let accel = motion.userAcceleration
            let magnitude = sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)
            let rotation = motion.rotationRate
            let gyro = sqrt(rotation.x * rotation.x + rotation.y * rotation.y + rotation.z * rotation.z)
            self?.acceleration = magnitude
            self?.gyroscope = gyro
        }
    }

    private func startAltimeter() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
            guard let pressure = data?.pressure.doubleValue else { return }
            // kPa → Pa, approximate absolute from relative
            self?.barometer = 101325 + (pressure * 1000)
        }
    }

    private func emitState() {
        let isSleeping = heartRate < 60 && acceleration < 0.1
        let state = SensorState(
            heartRate: heartRate,
            barometer: barometer,
            acceleration: acceleration,
            gyroscope: gyroscope,
            audioLevel: 0,
            isSleeping: isSleeping,
            timestamp: Date()
        )
        onStateUpdate?(state)
    }
}