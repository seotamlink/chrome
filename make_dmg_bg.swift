// Ảnh nền cho cửa sổ DMG: mũi tên từ icon app sang thư mục Applications.
// Dùng: make_dmg_bg <out.png>
import AppKit

let W: CGFloat = 620, H: CGFloat = 400
let img = NSImage(size: NSSize(width: W, height: H))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// nền tối, cùng tông với app
ctx.setFillColor(CGColor(red: 0.059, green: 0.075, blue: 0.102, alpha: 1))   // #0F131A
ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

// mũi tên giữa hai icon (toạ độ CoreGraphics: gốc dưới-trái)
let y: CGFloat = H - 190
ctx.setStrokeColor(CGColor(red: 0.184, green: 0.42, blue: 1, alpha: 0.85))   // accent
ctx.setLineWidth(4)
ctx.setLineCap(.round)
ctx.move(to: CGPoint(x: 250, y: y))
ctx.addLine(to: CGPoint(x: 368, y: y))
ctx.strokePath()
ctx.beginPath()
ctx.move(to: CGPoint(x: 388, y: y))
ctx.addLine(to: CGPoint(x: 362, y: y + 13))
ctx.addLine(to: CGPoint(x: 362, y: y - 13))
ctx.closePath()
ctx.setFillColor(CGColor(red: 0.184, green: 0.42, blue: 1, alpha: 0.85))
ctx.fillPath()

func text(_ s: String, _ size: CGFloat, _ yPos: CGFloat, _ alpha: CGFloat, bold: Bool = false) {
    let st = NSMutableParagraphStyle(); st.alignment = .center
    let attrs: [NSAttributedString.Key: Any] = [
        .font: bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size),
        .foregroundColor: NSColor(white: 1, alpha: alpha),
        .paragraphStyle: st,
    ]
    s.draw(in: CGRect(x: 0, y: yPos, width: W, height: size * 1.6), withAttributes: attrs)
}

text("Kéo Account Dock vào thư mục Applications", 15, 92, 0.88, bold: true)
text("Sau khi kéo xong, mở Terminal và dán lệnh trong DOC-DE-CHAY.txt", 11.5, 66, 0.5)
text("Không làm bước đó thì macOS sẽ báo app bị hỏng", 11.5, 48, 0.42)

img.unlockFocus()
let tiff = img.tiffRepresentation!
let png = NSBitmapImageRep(data: tiff)!.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
