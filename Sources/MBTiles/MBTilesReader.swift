import Foundation
import Logging
import SQLite

#if os(iOS)
import UIKit
#endif

public class MBTilesReader {
    
    public enum Errors: Error {
        case pngError
        case blobError
        case nullDataError
        case listError
    }
    
    var logger: Logger?
    var resolver: MBTilesResolver
    
    public init(resolver: MBTilesResolver, logger: Logger?) {
        self.logger = logger
        self.resolver = resolver
    }
    
    public func ListTiles(db_pool: MBTilesDatabasePool, db_path: String) -> Swift.Result<StringIterator, Error> {
        
        let prefix_rsp = self.resolver.PrefixFromPath(path: db_path)
        var prefix: String
        
        switch prefix_rsp {
        case .failure(let error):
            return .failure(error)
        case .success(let p):
            prefix = p
        }
        
        let conn: Connection
        
        let conn_rsp = db_pool.GetConnection(db_path: db_path)
        
        switch conn_rsp {
        case .failure(let error):
            return .failure(error)
        case .success(let c):
            conn = c
        }
        
        let q = "SELECT map.zoom_level AS z, map.tile_column AS x, map.tile_row AS y, images.tile_data AS tile_data FROM map JOIN images ON images.tile_id = map.tile_id"
        
        // query = query + " WHERE z < 19 ORDER BY z DESC"
        
        do  {
            let rsp = try conn.prepare(q)
            let db_iter = rsp.makeIterator()
            
            let iter = MBTilesIterator(prefix: prefix, resolver: self.resolver, result_set: db_iter)
            return .success(iter)
            
        } catch (let error){
            self.logger?.warning("List query failed \(error)")
            return .failure(error)
        }
        
        
    }
    
    public func ReadTileAsDataURL(db_pool: MBTilesDatabasePool, db_path: String, tile: MBTile) -> Swift.Result<String, Error> {
        
        let data_rsp = ReadTileAsData(db_pool: db_pool, db_path: db_path, tile: tile)
        let data: Data
        
        switch data_rsp {
        case .failure(let error):
            self.logger?.warning("Failed to read tile (as data) for \(tile.String()), \(error)")
            return .failure(error)
        case .success(let d):
            data = d
        }
        
        // See this? We're assuming PNG images here which may not always be true.
        // Today, it is true however... (20210721/thisisaaronland)
        let uri = "data:image/png;base64," + data.base64EncodedString()
        return .success(uri)
        
        /*
        let im_result = ReadTileAsUIImage(db_pool: db_pool, db_path: db_path, tile: tile)
        
        let im: UIImage
        
        switch im_result {
        case .failure(let error):
            self.logger?.warning("Failed to read tile as UIImage, \(error)")
            return .failure(error)
        case .success(let i):
            im = i
        }
        
        guard let im_data = im.pngData() as NSData? else {
            self.logger?.warning("Failed to derived data from PNG, \(Errors.pngError)")
            return .failure(Errors.pngError)
        }
        
        let b64 = im_data.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        let uri = "data:image/png;base64," + b64
        
        return .success(uri)
        */
    }
    
    public func ReadTileAsUIImage(db_pool: MBTilesDatabasePool, db_path: String, tile: MBTile)->Swift.Result<UIImage, Error>{
        
        let data_rsp = ReadTileAsData(db_pool: db_pool, db_path: db_path, tile: tile)
        let data: Data
        
        switch data_rsp {
        case .failure(let error):
            self.logger?.warning("Failed to read tile (as data) for \(tile.String()), \(error)")
            return .failure(error)
        case .success(let d):
            data = d
        }
        
        guard let im = UIImage(data: data) else {
            self.logger?.warning("Failed to derive UIImage for \(tile.String())")
            return .failure(Errors.blobError)
        }
        
        return .success(im)
    }
    
    public func ReadTileAsData(db_pool: MBTilesDatabasePool, db_path: String, tile: MBTile)->Swift.Result<Data, Error>{
        
        let conn_rsp = db_pool.GetConnection(db_path: db_path)
        
        let conn: Connection
        
        switch conn_rsp {
        case .failure(let error):
            self.logger?.warning("Failed to creata database connection for \(db_path), \(error)")
            return .failure(error)
        case .success(let c):
            conn = c
        }
        
        let z = tile.z
        let x = tile.x
        let y = tile.y
        
        
        let q = "SELECT i.tile_data AS tile_data FROM map m, images i WHERE i.tile_id = m.tile_id AND m.zoom_level=? AND m.tile_column=? AND m.tile_row=?"
                
        // something something something max zoom...
        
        // please move this in to init()
        var get_tile: Statement
        
        do  {
            get_tile = try conn.prepare(q)
        } catch {
            return .failure(error)
        }
        
        var blob: SQLite.Blob?
        
        do {
            try get_tile = get_tile.run(z, x, y)
            blob = try get_tile.scalar() as? SQLite.Blob
            
            if (blob == nil){
                // self.logger?.warning("Failed to create SQLite.Blob for \(tile.String())")
                return .failure(Errors.nullDataError)
            }
            
        } catch {
            print(db_path, z, x, y, error)
            return .failure(error)
        }
        
        let data = Data.fromDatatypeValue(blob!)
        return .success(data)
    }
}
