import Foundation

public class MBTileUtils {
    
    public enum Errors: Error {
        case pathError
        case bundleError
        case isNotExistError
        case listError
    }
    
    var mb: MBTilesManager
    var tile_root: String?
        
    public init(root: String?){
        mb = MBTilesManager()
        tile_root = root
    }
    
    public func DatabaseRoot() -> URL {
        
        var root =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        if tile_root != nil {
            root = root.appendingPathComponent(tile_root!)
        }
        
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
        
        // I tried doing it the right way with regular expressions
        // but they are even weirder in Swift than they are in Go
        // which is saying something... (20190624/thisisaaronland)
        // let base_pat = "tiles/png/(\\d+)\\/(\\d+)/(\\d+)\\.png"
        // let aerial_pat = "tiles/aerial/(\\d{4})/(\\d+)/(\\d+)/(\\d+)\\.png"
        // let base_re = NSRegularExpression(pattern: base_pat, options: nil, error: nil)
        // let aerial_re = NSRegularExpression(pattern: aerial_pat, options: nil, error: nil)
        
        /*
        var z: String
        var x: String
        var y: String
        var db_name: String
        
        let parts = rel_path.components(separatedBy: "/")
        
        switch parts[1] {
        case "png":
            db_name = "base"
            z = parts[2]
            x = parts[3]
            y = parts[4].replacingOccurrences(of: ".png", with: "")
        case "aerial":
            db_name = parts[2]
            z = parts[3]
            x = parts[4]
            y = parts[5].replacingOccurrences(of: ".png", with: "")
        default:
            
            return .failure(Errors.pathError)
        }
        */
        
        var tile: MBTile
        let tile_rsp = callback(rel_path)
        
        switch tile_rsp {
        case .failure(let error):
            return .failure(error)
        case .success(let t):
            tile = t
        }
        
        guard let db_path = Bundle.main.path(forResource:tile.prefix, ofType: "db", inDirectory: tile_root) else {
            return .failure(Errors.bundleError)
        }
        
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
