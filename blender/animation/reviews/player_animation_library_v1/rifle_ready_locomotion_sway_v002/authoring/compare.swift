import Foundation
import AVFoundation
import QuartzCore
import AppKit
let comp=AVMutableComposition();var layers:[AVMutableVideoCompositionLayerInstruction]=[]
for (i,p) in CommandLine.arguments.dropFirst().prefix(2).enumerated(){
 let a=AVURLAsset(url:URL(fileURLWithPath:p));let t=a.tracks(withMediaType:.video)[0]
 let ct=comp.addMutableTrack(withMediaType:.video,preferredTrackID:kCMPersistentTrackID_Invalid)!
 var start=0.0;let duration=CMTimeGetSeconds(a.duration)
 while start<4.8-0.00001{let take=min(duration,4.8-start);try ct.insertTimeRange(CMTimeRange(start:.zero,duration:CMTime(seconds:take,preferredTimescale:600)),of:t,at:CMTime(seconds:start,preferredTimescale:600));start+=take}
 let l=AVMutableVideoCompositionLayerInstruction(assetTrack:ct);l.setTransform(t.preferredTransform.concatenating(CGAffineTransform(translationX:CGFloat(i*640),y:0)),at:.zero);layers.append(l)
}
let ins=AVMutableVideoCompositionInstruction();ins.timeRange=CMTimeRange(start:.zero,duration:CMTime(seconds:4.8,preferredTimescale:600));ins.layerInstructions=layers
let vc=AVMutableVideoComposition();vc.instructions=[ins];vc.renderSize=CGSize(width:1280,height:640);vc.frameDuration=CMTime(value:1,timescale:30)
let parent=CALayer();parent.frame=CGRect(x:0,y:0,width:1280,height:640)
let video=CALayer();video.frame=parent.frame;parent.addSublayer(video)
for (i,title) in [CommandLine.arguments[3],CommandLine.arguments[4]].enumerated(){
 let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1248,pixelsHigh:60,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
 NSColor.black.withAlphaComponent(0.65).setFill();NSRect(x:0,y:0,width:1248,height:60).fill()
 let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:42,weight:.semibold),.foregroundColor:NSColor.white]
 let text=title as NSString;let size=text.size(withAttributes:attrs);text.draw(at:NSPoint(x:(1248-size.width)/2,y:5),withAttributes:attrs)
 NSGraphicsContext.restoreGraphicsState()
 let t=CALayer();t.contents=bitmap.cgImage;t.contentsScale=2;t.frame=CGRect(x:i*640+8,y:600,width:624,height:30);parent.addSublayer(t)
}
vc.animationTool=AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer:video,in:parent)
let out=URL(fileURLWithPath:CommandLine.arguments.last!);try? FileManager.default.removeItem(at:out)
let session=AVAssetExportSession(asset:comp,presetName:AVAssetExportPresetHighestQuality)!;session.outputURL=out;session.outputFileType = .mp4;session.videoComposition=vc
let sem=DispatchSemaphore(value:0);session.exportAsynchronously{sem.signal()};sem.wait()
if session.status != .completed {fatalError("Comparison export failed: \(String(describing:session.error))")};print("Comparison export completed",out.path)
