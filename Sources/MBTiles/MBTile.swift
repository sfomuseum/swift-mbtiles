public struct MBTile {
    
    // TO DO: ensure that x, y, z are Ints
    
    public var prefix: String
    public var z: Int
    public var x: Int
    public var y: Int
    
    public init(prefix:String, z: Int, x: Int, y: Int) {
        self.prefix = prefix
        self.z = z
        self.x = x
        self.y = y
    }

}
