import Foundation
import AVFoundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import CryptoKit

func jsonSeconds(_ value: CMTime) -> Any {
    let seconds = CMTimeGetSeconds(value)
    return seconds.isFinite ? seconds as Any : NSNull()
}

let input = URL(fileURLWithPath: CommandLine.arguments[1])
let root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let framesDir = root.appendingPathComponent("native_frames", isDirectory: true)
try FileManager.default.createDirectory(at: framesDir, withIntermediateDirectories: true)
let asset = AVURLAsset(url: input)
let track = asset.tracks(withMediaType: .video)[0]
let reader = try AVAssetReader(asset: asset)
let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA])
output.alwaysCopiesSampleData = false
reader.add(output)
guard reader.startReading() else { print("Reader did not start: \(String(describing: reader.error))"); exit(2) }
let context = CIContext(options: [.useSoftwareRenderer: true])
var frames: [[String: Any]] = []
var lastDigest = ""
var duplicates: [[Int]] = []
while let sample = output.copyNextSampleBuffer() {
    let i = frames.count
    guard let pixel = CMSampleBufferGetImageBuffer(sample) else { fatalError("No image buffer") }
    CVPixelBufferLockBaseAddress(pixel, .readOnly)
    let w = CVPixelBufferGetWidth(pixel), h = CVPixelBufferGetHeight(pixel)
    let rowBytes = CVPixelBufferGetBytesPerRow(pixel)
    let base = CVPixelBufferGetBaseAddress(pixel)!
    var data = Data(capacity: w*h*4)
    for row in 0..<h { data.append(base.advanced(by: row*rowBytes).assumingMemoryBound(to: UInt8.self), count: w*4) }
    let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    CVPixelBufferUnlockBaseAddress(pixel, .readOnly)
    if digest == lastDigest { duplicates.append([i-1,i]) }
    lastDigest = digest
    let frameURL = framesDir.appendingPathComponent(String(format:"frame_%04d.png",i))
    let ci = CIImage(cvPixelBuffer: pixel)
    guard let cg = context.createCGImage(ci, from: ci.extent), let dst = CGImageDestinationCreateWithURL(frameURL as CFURL, UTType.png.identifier as CFString, 1, nil) else { fatalError("Image creation failed") }
    CGImageDestinationAddImage(dst, cg, nil)
    guard CGImageDestinationFinalize(dst) else { fatalError("Image save failed") }
    let pts = CMSampleBufferGetPresentationTimeStamp(sample)
    let dur = CMSampleBufferGetDuration(sample)
    frames.append(["index":i,"pts_s":jsonSeconds(pts),"pts_value":pts.value,"pts_timescale":pts.timescale,"duration_s":jsonSeconds(dur),"raw_BGRA_SHA256":digest,"png":frameURL.path])
}
guard reader.status == .completed else { fatalError("Reader failed: \(String(describing: reader.error))") }
let report: [String: Any] = ["input":input.path,"decoder":"macOS AVFoundation AVAssetReader; 32BGRA; CoreImage software renderer; PNG via ImageIO","nominal_fps":track.nominalFrameRate,"natural_size":[track.naturalSize.width,track.naturalSize.height],"duration_s":CMTimeGetSeconds(asset.duration),"track_timescale":track.naturalTimeScale,"frame_count":frames.count,"exact_duplicate_frame_pairs":duplicates,"frames":frames]
try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:root.appendingPathComponent("native_decode_manifest.json"))
print("Decoded \(frames.count) frames; nominal FPS \(track.nominalFrameRate); size \(track.naturalSize); exact duplicates \(duplicates)")
