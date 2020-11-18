import Foundation
import FMDB
import Logging

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
       
    public func ListTiles(db_pool: MBTilesDatabasePool, db_path: String) -> Result<StringIterator, Error> {
                
        let prefix_rsp = self.resolver.PrefixFromPath(path: db_path)
        var prefix: String
        
        switch prefix_rsp {
        case .failure(let error):
            return .failure(error)
        case .success(let p):
            prefix = p
        }
        
        let conn_rsp = db_pool.GetConnection(db_path: db_path)
        
        let db: FMDatabaseQueue
        
        switch conn_rsp {
        case .failure(let error):
            return .failure(error)
        case .success(let d):
            db = d
        }
        
        let q = "SELECT map.zoom_level AS z, map.tile_column AS x, map.tile_row AS y, images.tile_data AS tile_data FROM map JOIN images ON images.tile_id = map.tile_id"
        
        // query = query + " WHERE z < 19 ORDER BY z DESC"
        
        var rs = FMResultSet()
        var ok = true
        
        db.inTransaction { (db, rollback) in
            
            do  {
                rs = try db.executeQuery(q, values: nil)
                
            } catch (let error){
                self.logger?.warning("List query failed \(error)")
                rollback.pointee = true
                ok = false
                return
            }
            
        }
        
        if !ok {
            return .failure(Errors.listError)
        }
        
        let iter = MBTilesIterator(prefix: prefix, result_set: rs)
        return .success(iter)
    }
    
    public func ReadTileAsDataURL(db_pool: MBTilesDatabasePool, db_path: String, tile: MBTile) -> Swift.Result<String, Error> {
        
        let im_result = ReadTileAsUIImage(db_pool: db_pool, db_path: db_path, tile: tile)
        
        let im: UIImage
        
        switch im_result {
        case .failure(let error):
            return .failure(error)
        case .success(let i):
            im = i
        }
        
        guard let im_data = im.pngData() as NSData? else {
            return .failure(Errors.pngError)
        }
        
        let b64 = im_data.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        let uri = "data:image/png;base64," + b64
        
        return .success(uri)
    }
    
    public func ReadTileAsUIImage(db_pool: MBTilesDatabasePool, db_path: String, tile: MBTile)->Result<UIImage, Error>{
        
        let data_rsp = ReadTileAsData(db_pool: db_pool, db_path: db_path, tile: tile)
        let data: Data
        
        switch data_rsp {
        case .failure(let error):
            return .failure(error)
        case .success(let d):
            data = d
        }
        
        guard let im = UIImage(data: data) else {
            return .failure(Errors.blobError)
        }
        
        return .success(im)
    }
    
    public func ReadTileAsData(db_pool: MBTilesDatabasePool, db_path: String, tile: MBTile)->Swift.Result<Data, Error>{
        
        let conn_rsp = db_pool.GetConnection(db_path: db_path)
        
        let db: FMDatabaseQueue
        
        switch conn_rsp {
        case .failure(let error):
            return .failure(error)
        case .success(let d):
            db = d
        }
        
        let z = tile.z
        let x = tile.x
        let y = tile.y
        
        
        let q = "SELECT i.tile_data AS tile_data FROM map m, images i WHERE i.tile_id = m.tile_id AND m.zoom_level=? AND m.tile_column=? AND m.tile_row=?"
        
        var body = Data()
        var ok = true
        
        db.inTransaction { (db, rollback) in
            
            do  {
                
                let rs = try db.executeQuery(q, values: [ z, x, y])
                rs.next()
                
                guard let data = rs.data(forColumn: "tile_data") else {
                    self.logger?.warning("Tile query failed : No data")
                    rollback.pointee = true
                    ok = false
                    return
                }
                
                body = data
                
            } catch (let error){
                self.logger?.warning("Tile query failed \(error)")
                rollback.pointee = true
                ok = false
                return
            }
            
        }
        
        if !ok {
            return .failure(Errors.nullDataError)
        }
        
        return .success(body)
    }
}
