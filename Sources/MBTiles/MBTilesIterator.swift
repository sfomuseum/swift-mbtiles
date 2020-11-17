import Foundation
import FMDB

// https://developer.apple.com/documentation/swift/iteratorprotocol
// https://github.com/apple/swift/blob/master/docs/SequencesAndCollections.rst
// https://www.swiftbysundell.com/articles/swift-sequences-the-art-of-being-lazy/

public protocol StringIterator {
    func next() -> String
}

struct MBTilesIterator: StringIterator {
    
    let prefix: String
    let rs: FMResultSet
    
    init(prefix: String, result_set: FMResultSet) {
        self.prefix = prefix
        self.rs = result_set
    }
    
    func next() ->String {
        
        rs.next()
                
        let z = rs.int(forColumn: "z")
        let x = rs.int(forColumn: "x")
        let y = rs.int(forColumn: "y")
        
        let path = String(format: "%@/%d/%d/%d.png", prefix, z, x, y)
        return path
    }
    
}


