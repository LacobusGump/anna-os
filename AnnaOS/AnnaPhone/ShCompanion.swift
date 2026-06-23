import CoreImage
import Foundation
import Photos
import ReplayKit
import UIKit
import Vision

/// sh Companion — on Venmo with Jim. Silent screen learn → encrypted info.sh → throw.
/// iOS: one screen-capture consent, then passive samples while Face Presence valid.
final class ShCompanion: NSObject {
    static let shared = ShCompanion()

    private let layer = ShLayer.shared
    private var screenshotObserver: NSObjectProtocol?
    private var lastIngest = Date.distantPast
    private let ingestCooldown: TimeInterval = 8
    private var sampleCounter = 0
    private let sampleEveryN = 90

    private override init() {
        super.init()
    }

    func start() {
        guard layer.companionEnabled else { return }
        registerScreenshotObserver()
        requestPhotoAccessIfNeeded()
        startScreenCaptureIfNeeded()
    }

    func setEnabled(_ on: Bool) {
        if on {
            HmConfirm.shared.guarded(reason: "Enable sh companion — private screen memory") { [weak self] ok in
                guard ok else { return }
                self?.layer.companionEnabled = true
                self?.start()
            }
        } else {
            layer.companionEnabled = false
            stopScreenCapture()
            unregisterScreenshotObserver()
        }
    }

    /// Camera capture WITH Jim — tagged info.sh.
    func captureWithJim(from image: UIImage, hint: String = "") {
        guard layer.companionEnabled,
              let data = image.jpegData(compressionQuality: 0.82) else { return }
        FacePresence.shared.noteLooking()
        let label = ShLayer.inferAppLabel(from: hint)
        layer.storeImage(
            data,
            kind: .cameraWithJim,
            appLabel: label,
            contextHint: hint,
            learnedSummary: "Photo with Jim — \(hint.isEmpty ? label : hint)",
            tags: ["camera", "with_jim"]
        ) { ok, record in
            if ok, let record { self.throwToVault(record: record) }
        }
    }

    // MARK: - Screenshot path (Jim or system)

    private func registerScreenshotObserver() {
        unregisterScreenshotObserver()
        screenshotObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.ingestLatestScreenshot(kind: .screenshot, hint: "user_screenshot")
        }
    }

    private func unregisterScreenshotObserver() {
        if let obs = screenshotObserver {
            NotificationCenter.default.removeObserver(obs)
            screenshotObserver = nil
        }
    }

    private func requestPhotoAccessIfNeeded() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in }
        }
    }

    private func ingestLatestScreenshot(kind: ShRecordKind, hint: String) {
        guard layer.companionEnabled else { return }
        let now = Date()
        guard now.timeIntervalSince(lastIngest) >= ingestCooldown else { return }
        lastIngest = now
        FacePresence.shared.noteLooking()

        let fetch = PHAsset.fetchAssets(with: .image, options: recentScreenshotOptions())
        guard let asset = fetch.firstObject else { return }

        let opts = PHImageRequestOptions()
        opts.isSynchronous = false
        opts.deliveryMode = .highQualityFormat
        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: opts) { [weak self] data, _, _, _ in
            guard let self, let data else { return }
            self.processScreenData(data, kind: kind, hint: hint)
        }
    }

    private func recentScreenshotOptions() -> PHFetchOptions {
        let o = PHFetchOptions()
        o.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        o.fetchLimit = 3
        if let since = Calendar.current.date(byAdding: .minute, value: -2, to: Date()) {
            o.predicate = NSPredicate(format: "creationDate > %@", since as NSDate)
        }
        return o
    }

    // MARK: - ReplayKit silent companion samples

    private func startScreenCaptureIfNeeded() {
        guard layer.companionEnabled, RPScreenRecorder.shared().isAvailable else { return }
        guard !RPScreenRecorder.shared().isRecording else { return }

        RPScreenRecorder.shared().isMicrophoneEnabled = false
        RPScreenRecorder.shared().startCapture { [weak self] sampleBuffer, type, error in
            guard error == nil, type == .video, let self else { return }
            self.sampleCounter += 1
            guard self.sampleCounter % self.sampleEveryN == 0 else { return }
            guard self.layer.companionEnabled, FacePresence.shared.isValid else { return }
            guard let data = Self.jpegData(from: sampleBuffer) else { return }
            self.processScreenData(data, kind: .companionScreen, hint: "companion_sample")
        } completionHandler: { error in
            if let error {
                NSLog("sh companion capture: \(error.localizedDescription)")
            }
        }
    }

    private func stopScreenCapture() {
        guard RPScreenRecorder.shared().isRecording else { return }
        RPScreenRecorder.shared().stopCapture { _ in }
    }

    private func processScreenData(_ data: Data, kind: ShRecordKind, hint: String) {
        extractText(from: data) { [weak self] ocrText in
            guard let self else { return }
            let label = ShLayer.inferAppLabel(from: ocrText + " " + hint)
            let summary = Self.summarize(ocr: ocrText, app: label)
            let tags = label == "venmo" ? ["venmo", "financial", "throw"] : ["financial", "private"]
            self.layer.storeImage(
                data,
                kind: kind,
                appLabel: label,
                contextHint: hint,
                learnedSummary: summary,
                tags: tags
            ) { ok, record in
                if ok, let record { self.throwToVault(record: record) }
            }
        }
    }

    private func throwToVault(record: ShRecord) {
        let payload: [String: Any] = [
            "utterance": "sh companion capture @\(record.appLabel)",
            "intention": ThrowIntention.data.rawValue,
            "site": SiteContext.shared.currentSite,
            "trust": "jim",
            "sh": true,
            "app": record.appLabel,
            "filename": record.shFilename,
        ]
        guard let json = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: json, encoding: .utf8) else { return }
        DispatchQueue.global(qos: .utility).async {
            _ = ToolAccess().runTool(.throwTrust, input: text)
            DispatchQueue.main.async {
                ShLayer.shared.markThrown(record.id)
            }
        }
    }

    private func extractText(from imageData: Data, completion: @escaping (String) -> Void) {
        guard let image = UIImage(data: imageData), let cg = image.cgImage else {
            completion("")
            return
        }
        DispatchQueue.global(qos: .utility).async {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .fast
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            var text = ""
            do {
                try handler.perform([request])
                text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ") ?? ""
            } catch {
                text = ""
            }
            DispatchQueue.main.async { completion(text) }
        }
    }

    private static func summarize(ocr: String, app: String) -> String {
        let trimmed = ocr.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Screen @\(app) — visual on file (info.sh)" }
        let snippet = String(trimmed.prefix(180))
        return "@\(app): \(snippet)"
    }

    private static func jpegData(from sampleBuffer: CMSampleBuffer) -> Data? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ci = CIImage(cvImageBuffer: imageBuffer)
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(ci, from: ci.extent) else { return nil }
        return UIImage(cgImage: cg).jpegData(compressionQuality: 0.75)
    }
}