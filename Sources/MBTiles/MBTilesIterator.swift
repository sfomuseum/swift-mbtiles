import Foundation
import SQLite

// https://developer.apple.com/documentation/swift/iteratorprotocol
// https://github.com/apple/swift/blob/master/docs/SequencesAndCollections.rst
// https://www.swiftbysundell.com/articles/swift-sequences-the-art-of-being-lazy/

public protocol StringIterator {
    func next() -> String
    func close() -> Void
}

struct MBTilesIterator: StringIterator {
    
    let resolver: MBTilesResolver
    let prefix: String
    let rs: Statement
    
    init(prefix: String, resolver: MBTilesResolver, result_set: Statement) {
        self.prefix = prefix
        self.resolver = resolver
        self.rs = result_set
    }
    
    func next() ->String {
        
        guard let t = rs.next() else {
            return ""
        }
        
        let z = t[0] as! Int64
        let x = t[1] as! Int64
        let y = t[2] as! Int64
        
        let tile = MBTile(prefix:self.prefix, z: Int(z), x: Int(x), y: Int(y))
        
        let rsp = self.resolver.PathFromMBTile(tile: tile)
        
        switch rsp {
        case .failure(let error):
            print(error)
            return ""
        case .success(let path):
            return path
        }
        
    }
    
    func close() -> Void {}
}


