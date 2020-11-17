import Logging
import Foundation

class MBTilesCache {
    
    var logger: Logger?
    var mbutils: MBTileUtils
    
    let reading = AtomicInteger(value:0)
    
    let cache = NSCache<NSString, NSString>()
    let missing = NSCache<NSString, NSString>()
    
    var precache_tiles_throttle = 10
    var skip = Array<String>()
    
    init(root: String?, skip: Array<String>, throttle: Int, logger: Logger?){
        
        self.logger = logger
        self.mbutils = MBTileUtils(root: root, logger: logger)
        self.precache_tiles_throttle = throttle
        self.skip = skip
    }
    
    public func PrecacheTileData(callback: @escaping (_ rel_path: String) -> Result<MBTile, Error>) -> Result<Bool, Error> {
        
        let rsp = mbutils.Databases()
        
        switch rsp {
        case .failure(let error):
            return .failure(error)
        case .success(let databases):
            
            for url in databases {
                
                let fname = url.lastPathComponent
                
                if self.skip.contains(fname) {
                    continue
                }
                
                var path = url.absoluteString
                path = path.replacingOccurrences(of: "file://", with: "")
                
                let db_rsp = self.PrecacheTileDataForDatabase(path: path, callback: callback)
                
                if case .failure(let db_error) = db_rsp {
                    self.logger?.error("Failed to precache '\(path)': \(db_error)")
                }
            }
        }
        
        return .success(true)
    }
    
    public func PrecacheTileDataForDatabase(path: String,  callback: @escaping (_ rel_path: String) -> Result<MBTile, Error>) -> Result<Bool, Error> {
        
        let tiles_rsp = mbutils.ListTilesForDatabase(db_path: path)
        
        switch tiles_rsp {
        case .failure(let error):
            return .failure(error)
        case .success(let iter):
            
            var dispatched = 0
            
            while true {
                
                let tile_path = iter.next()
                
                // while case let tile_path = iter.next() {
                
                if tile_path == "" {
                    self.logger?.info("next tile path is empty \(path)")
                    // self.debugLog(body: "Tile path is empty. Stopping pre-cache.")
                    break
                }
                
                var counter = self.reading.value
                
                while counter > self.precache_tiles_throttle {
                    self.logger?.warning("Current preloading \(counter) tiles. Limit is \(self.precache_tiles_throttle). Pausing.")
                    sleep(2)
                    counter = self.reading.value
                }
                
                DispatchQueue.global(qos: .default).async {
                    
                    let load_rsp = self.mbutils.ReadTileAsDataURL(rel_path: tile_path, callback: callback)
                    
                    switch load_rsp {
                    case .success(let tile_data) :
                        
                        self.logger?.debug("Preloaded \(tile_path)")
                        
                    /*
                     DispatchQueue.main.async {
                     self.cache.setObject(NSString(string: tile_data), forKey:NSString(string: tile_path))
                     }
                     */
                    
                    case .failure(let error):
                        self.logger?.error("Failed to load tile for pre-caching '\(tile_path)': \(error)")
                    }
                }
                
                dispatched += 1
                
                if dispatched >= self.precache_tiles_throttle {
                    sleep(1)
                    dispatched = 0
                }
            }
        }
        
        return .success(true)
    }
}
