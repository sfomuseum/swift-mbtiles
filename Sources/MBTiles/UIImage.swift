#if os(macOS)

// https://gist.github.com/JohnSundell/05f837a3f901630e65e3652945424ba5
import Cocoa

// Step 1: Typealias UIImage to NSImage
public typealias UIImage = NSImage

// Step 2: You might want to add these APIs that UIImage has but NSImage doesn't.
extension NSImage {
    var cgImage: CGImage? {
        var proposedRect = CGRect(origin: .zero, size: size)

        return cgImage(forProposedRect: &proposedRect,
                       context: nil,
                       hints: nil)
    }

    convenience init?(named name: String) {
        self.init(named: Name(name))
    }
}

#endif
