import Foundation
import Logging

// A collection of MBTiles databases in a single directory

public class MBTilesCollection {
    
    var logger: Logger?
    
    var root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    public init(root: URL?, logger: Logger?) {
                
        self.logger = logger
        
        if root != nil {
            self.root = root!
        }
    }
    
    public func DatabaseRoot() -> URL {
        
        self.logger?.debug("database root is \(self.root)")
        return self.root
    }
    
    public func DatabasePath(rel_path: String) -> String {
        
        self.logger?.debug("Get database paths for \(rel_path)")
        
        // This is what we used to do when we bundled the tile databases with
        // the app itself (20191002/thisisaaronland)
        // let path_db = "tiles/sqlite/" + db_name
        // let bundle_path = FileUtils.BundlePath(path_db)
        
        // This is what we do now when we copy the tile databases in to the app's
        // Documents folder using the Apple Configurator tool (20191002/thisisaaronland)
        
        let db_root =  self.DatabaseRoot()
        
        self.logger?.debug("Database root is \(db_root)")
        let db_url = db_root.appendingPathComponent(rel_path)
        
        let db_path = db_url.absoluteString
        self.logger?.debug("Database path is \(db_path)")
        
        return db_path.replacingOccurrences(of: "file://", with: "")
    }
    
    public func DatabasePathFromTile(tile: MBTile) -> String {
        // let rel_path = String(format: "%@.db", )
        return DatabasePath(rel_path: tile.prefix)
    }
    
    public func Databases() -> Result<[URL], Error> {
        
        let db_root = self.DatabaseRoot()
        
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(at: db_root, includingPropertiesForKeys: nil)
            
            var databases = [URL]()
            
            for url in directoryContents.filter({ $0.pathExtension == "db" }) {
                
                /*
                guard let base = url.baseURL else {
                    continue
                }
                */
                
                databases.append(url)
            }
            
            return .success(databases)
            
        } catch (let error) {
            self.logger?.error("Failed to list databases in \(db_root): \(error)")
            return .failure(error)
        }
    }

}
