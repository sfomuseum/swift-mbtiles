import Logging
import Foundation

public class MBTilesCache {
    
    var logger: Logger?
    var db_pool: MBTilesDatabasePool
    var db_reader: MBTilesReader
    
    var precache_tiles_throttle = 10
    var skip = Array<String>()
    
    public let reading = AtomicInteger(value:0)    
    public let cache = NSCache<NSString, NSString>()
    public let missing = NSCache<NSString, NSString>()
    
    public init(db_pool: MBTilesDatabasePool, db_reader: MBTilesReader, throttle: Int, logger: Logger?){

        self.db_pool = db_pool
        self.db_reader = db_reader
        self.logger = logger
        self.precache_tiles_throttle = throttle
    }
    
    // see notes about onload_callback below (20201118/thisisaaronland)
    
    public func PrecacheTileData(databases: Array<URL>, callback: @escaping (_ rel_path: String) -> Result<MBTile, Error>) -> Result<Bool, Error> {
                
            for url in databases {
                
                // let fname = url.lastPathComponent
                
                var path = url.absoluteString
                path = path.replacingOccurrences(of: "file://", with: "")
                
                let db_rsp = self.PrecacheTileDataForDatabase(path: path, callback: callback)
                
                if case .failure(let db_error) = db_rsp {
                    self.logger?.error("Failed to precache '\(path)': \(db_error)")
                }
            }
        
        return .success(true)
    }
    
    // this needs a second "onload" callback that the actual tile data is dispatched to
    // (20201118/thisisaaronland)
    
    public func PrecacheTileDataForDatabase(path: String,  callback: @escaping (_ rel_path: String) -> Result<MBTile, Error>) -> Result<Bool, Error> {
        
        self.logger?.info("Precache tiles for \(path)")
        
        let tiles_rsp = self.db_reader.ListTiles(db_pool: self.db_pool, db_path: path)
        
        switch tiles_rsp {
        case .failure(let error):
            return .failure(error)
        case .success(let iter):
            
            var dispatched = 0
            
            while true {
                
                let tile_path = iter.next()
                                
                if tile_path == "" {
                    self.logger?.info("next tile path is empty \(path)")
                    break
                }
                
                var counter = self.reading.value
                
                while counter > self.precache_tiles_throttle {
                    self.logger?.warning("Current preloading \(counter) tiles. Limit is \(self.precache_tiles_throttle). Pausing.")
                    sleep(2)
                    counter = self.reading.value
                }
                
                DispatchQueue.global(qos: .default).async {
                    
                    let tile_rsp = callback(tile_path)
                    
                    var tile: MBTile
                    
                    switch tile_rsp {
                    case .failure(let error):
                        self.logger?.warning("Failed to derive tile path from \(tile_path), \(error)")
                        return
                    case .success(let t):
                        tile = t
                    }
                    
                    let load_rsp = self.db_reader.ReadTileAsDataURL(db_pool: self.db_pool, db_path: path, tile: tile)
                    
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