// Ghép icon: logo Chrome làm nền + avatar tài khoản làm badge tròn góc dưới-phải.
// Dùng: swift make_icon.swift <base.icns> <avatar.png> <out.png>
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func load(_ path: String) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
    // .icns chứa nhiều kích thước -> lấy bản lớn nhất
    var best: CGImage? = nil
    for i in 0..<CGImageSourceGetCount(src) {
        guard let img = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
        if best == nil || img.width > best!.width { best = img }
    }
    return best
}

func write(_ img: CGImage, to path: String) -> Bool {
    guard let dst = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else { return false }
    CGImageDestinationAddImage(dst, img, nil)
    return CGImageDestinationFinalize(dst)
}

let args = CommandLine.arguments
guard args.count == 4,
      let base = load(args[1]),
      let avatar = load(args[2]) else {
    FileHandle.standardError.write("make_icon: không đọc được ảnh đầu vào\n".data(using: .utf8)!)
    exit(1)
}

let S: CGFloat = 1024
guard let ctx = CGContext(data: nil, width: Int(S), height: Int(S),
                          bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }
ctx.interpolationQuality = .high

// 1. Nền: logo Chrome, thu nhỏ nhẹ để chừa chỗ cho badge
let inset: CGFloat = S * 0.055
ctx.draw(base, in: CGRect(x: inset, y: inset, width: S - inset*2, height: S - inset*2))

// 2. Badge tròn ở góc dưới-phải (CoreGraphics: gốc toạ độ ở dưới-trái)
let r: CGFloat = S * 0.250                      // bán kính badge
let c = CGPoint(x: S - r - S*0.035, y: r + S*0.035)
let ring: CGFloat = S * 0.028                   // độ dày viền trắng

// bóng đổ cho badge nổi khỏi nền
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -S*0.012), blur: S*0.030,
              color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.34))
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r*2, height: r*2))
ctx.restoreGState()

// 3. Avatar, clip vào trong vòng tròn, scale theo aspect-fill
let ri = r - ring
ctx.saveGState()
ctx.addEllipse(in: CGRect(x: c.x - ri, y: c.y - ri, width: ri*2, height: ri*2))
ctx.clip()
let aw = CGFloat(avatar.width), ah = CGFloat(avatar.height)
let scale = max(ri*2 / aw, ri*2 / ah)
let dw = aw * scale, dh = ah * scale
ctx.draw(avatar, in: CGRect(x: c.x - dw/2, y: c.y - dh/2, width: dw, height: dh))
ctx.restoreGState()

guard let out = ctx.makeImage(), write(out, to: args[3]) else {
    FileHandle.standardError.write("make_icon: không ghi được file\n".data(using: .utf8)!)
    exit(1)
}
