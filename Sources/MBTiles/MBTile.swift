public struct MBTile {
    
    // TO DO: ensure that x, y, z are Ints
    
    public var prefix: String
    public var z: String
    public var x: String
    public var y: String
    
    public init(prefix:String, z: String, x: String, y: String) {        
        self.prefix = prefix
        self.z = z
        self.x = x
        self.y = y
    }
    
    public func URI() -> String {
        let uri = String(format: "%@/%@/%@/%@.png", prefix, z, x, y)
        return uri
    }
}
