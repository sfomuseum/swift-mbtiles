import Foundation
import Logging

public class MBTileUtils {
    
    public enum Errors: Error {
        case pathError
        case bundleError
        case isNotExistError
        case listError
    }
    
    var mb: MBTilesManager
    var tile_root: String?
    var logger: Logger?
    
    public init(root: String?, logger: Logger?){
        self.mb = MBTilesManager(logger: logger)
        self.logger = logger
        self.tile_root = root
    }
    
    public func DatabaseRoot() -> URL {
        
        var root =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        if tile_root != nil {
            root = root.appendingPathComponent(tile_root!)
        }
        
        self.logger?.debug("database root is \(root)")
        return root
    }
    
    public func DatabasePath(db_name: String) -> String {
        
        // This is what we used to do when we bundled the tile databases with
        // the app itself (20191002/thisisaaronland)
        // let path_db = "tiles/sqlite/" + db_name
        // let bundle_path = FileUtils.BundlePath(path_db)
        
        // This is what we do now when we copy the tile databases in to the app's
        // Documents folder using the Apple Configurator tool (20191002/thisisaaronland)
        
        let db_root =  self.DatabaseRoot()
        let db_url = db_root.appendingPathComponent(db_name)
        
        let db_path = db_url.absoluteString
        return db_path.replacingOccurrences(of: "file://", with: "")
    }
    
    public func Databases() -> Result<[URL], Error> {
        
        let db_root = self.DatabaseRoot()
        
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: db_root, includingPropertiesForKeys: nil)
            
            var databases = [URL]()
            
            for url in directoryContents.filter({ $0.pathExtension == "db" }) {
                databases.append(url)
            }
            
            return .success(databases)
            
        } catch {
            return .failure(Errors.listError)
        }
    }
    
    public func ListTilesForDatabase(db_path: String)->Result<StringIterator, Error> {
        
        let db_rsp = mb.ListTiles(db_path: db_path)
        
        switch db_rsp {
        case .failure(let error):
            return .failure(error)
        case .success(let db_iter):
            return .success(db_iter)
        }
    }
    
    public func ReadTileAsDataURL(rel_path: String, callback: (_ rel_path: String) -> Result<MBTile, Error>)->Result<String, Error>{
        
        self.logger?.debug("read tile as data URL from '\(rel_path)'")
        
        var tile: MBTile
        let tile_rsp = callback(rel_path)
        
        switch tile_rsp {
        case .failure(let error):
            return .failure(error)
        case .success(let t):
            tile = t
        }
        
        self.logger?.debug("read tile as data URL from '\(tile.prefix)'")
        
        guard let db_path = Bundle.main.path(forResource:tile.prefix, ofType: "db", inDirectory: tile_root) else {
            return .failure(Errors.bundleError)
        }
        
        self.logger?.debug("read tile as data URL with '\(db_path)'")
        
        // it sure would be nice to be able to return mb.ReadTileAsDataURL(...)
        
        let data_rsp = mb.ReadTileAsDataURL(db_path: db_path, z: tile.z, x: tile.x, y: tile.y)
        
        switch data_rsp {
        case .failure(let error):
            return .failure(error)
        case .success(let body):
            return .success(body )
        }
    }
}
