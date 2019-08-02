// https://stackoverflow.com/questions/29262624/nsimage-to-nsdata-as-png-swift

import AppKit

extension NSBitmapImageRep {
    var png: Data? {
        return representation(using: .png, properties: [:])
    }
}
extension Data {
    var bitmap: NSBitmapImageRep? {
        return NSBitmapImageRep(data: self)
    }
}
extension NSImage {
    func pngData() -> Data? {
        return tiffRepresentation?.bitmap?.png
    }
    func savePNG(to url: URL) -> Bool {
        do {
            try pngData()?.write(to: url)
            return true
        } catch {
            print(error)
            return false
        }

    }
}
