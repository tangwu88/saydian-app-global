// Reuse the original trademark artwork without redrawing any glyph.
import AppKit
import ImageIO
let args = CommandLine.arguments
let source = NSImage(contentsOfFile: args[1])!
let color = CGColorSpace(name: CGColorSpace.sRGB)!
let canvas = CGContext(data:nil,width:1024,height:1024,bitsPerComponent:8,bytesPerRow:0,space:color,bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
canvas.setFillColor(NSColor.white.cgColor); canvas.fill(CGRect(x:0,y:0,width:1024,height:1024))
let logo = source.cgImage(forProposedRect:nil,context:nil,hints:nil)!
let w: CGFloat = 822, h = w * CGFloat(logo.height)/CGFloat(logo.width)
canvas.interpolationQuality = .high; canvas.draw(logo,in:CGRect(x:(1024-w)/2,y:(1024-h)/2,width:w,height:h))
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath:args[2]) as CFURL,"public.png" as CFString,1,nil)!
CGImageDestinationAddImage(dest,canvas.makeImage()!,nil); precondition(CGImageDestinationFinalize(dest))
