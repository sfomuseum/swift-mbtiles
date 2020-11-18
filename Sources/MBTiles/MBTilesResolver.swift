public protocol MBTilesResolver {
    func PrefixFromPath(path: String) -> Result<String, Error>
    func MBTileFromPath(path: String) -> Result<MBTile, Error>
}
