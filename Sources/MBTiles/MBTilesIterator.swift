import Foundation
import FMDB

// https://developer.apple.com/documentation/swift/iteratorprotocol
// https://github.com/apple/swift/blob/master/docs/SequencesAndCollections.rst
// https://www.swiftbysundell.com/articles/swift-sequences-the-art-of-being-lazy/

public protocol StringIterator {
    func next() -> String
}

struct MBTilesIterator: StringIterator {
    
    let resolver: MBTilesResolver
    let prefix: String
    let rs: FMResultSet
    
    init(prefix: String, resolver: MBTilesResolver, result_set: FMResultSet) {
        self.prefix = prefix
        self.resolver = resolver
        self.rs = result_set
    }
    
    func next() ->String {
        
        rs.next()
                
        let z = rs.int(forColumn: "z")
        let x = rs.int(forColumn: "x")
        let y = rs.int(forColumn: "y")
        
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
    
}


