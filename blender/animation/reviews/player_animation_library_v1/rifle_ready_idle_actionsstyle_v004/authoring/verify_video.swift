import Foundation
import AVFoundation
import CoreVideo
var reports: [[String: Any]] = []
for name in CommandLine.arguments.dropFirst() {
 let asset = AVURLAsset(url: URL(fileURLWithPath: name))
 guard let track = asset.tracks(withMediaType: .video).first else { fatalError("Missing video") }
 let reader = try AVAssetReader(asset: asset)
 let output = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
 reader.add(output); guard reader.startReading() else { fatalError("Cannot decode") }
 var count=0; var last:Double = -1; var maxStepError:Double=0; var hashes=Set<UInt64>()
 while let sample = output.copyNextSampleBuffer() {
  let t=CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample))
  if last>=0 {maxStepError=max(maxStepError,abs(t-last-1.0/30.0))};last=t
  guard let image=CMSampleBufferGetImageBuffer(sample) else {fatalError("Missing decoded pixels")}
  let width=CVPixelBufferGetWidth(image); assert([640,1280].contains(width) && CVPixelBufferGetHeight(image)==640)
  CVPixelBufferLockBaseAddress(image,.readOnly)
  let rowBytes=CVPixelBufferGetBytesPerRow(image);let data=CVPixelBufferGetBaseAddress(image)!.assumingMemoryBound(to:UInt8.self)
  var hash:UInt64=1469598103934665603
  for y in stride(from:0,to:640,by:16) {for x in stride(from:0,to:width,by:16) {for c in 0..<3 {hash=(hash ^ UInt64(data[y*rowBytes+x*4+c])) &* 1099511628211}}}
  hashes.insert(hash);CVPixelBufferUnlockBaseAddress(image,.readOnly);count+=1
 }
 assert(reader.status == .completed && count==324 && abs(track.nominalFrameRate-30)<0.001 && maxStepError<0.000001)
 reports.append(["file":name,"decoded_frames":count,"fps":track.nominalFrameRate,"duration_s":Double(count)/30.0,"max_timestamp_step_error_s":maxStepError,"distinct_sampled_pixel_hashes":hashes.count,"passed":true])
}
let data=try JSONSerialization.data(withJSONObject:reports,options:[.prettyPrinted,.sortedKeys]);print(String(data:data,encoding:.utf8)!)
