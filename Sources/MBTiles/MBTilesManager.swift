import Foundation
import FMDB
import Logging

#if os(iOS)
import UIKit
#endif

public class MBTilesManager {
    
    public enum Errors: Error {
        case notAnError
        case isNotExistError
        case pngError
        case blobError
        case nullDataError
        case listError
        case databaseURI
        case databaseOpen
        case databaseTile
    }
    
    // https://developer.apple.com/documentation/dispatch/dispatchsemaphore
    // https://stackoverflow.com/questions/46169519/mutex-alternatives-in-swift
    let semaphore = DispatchSemaphore(value: 1)
    
    // var dbqueue: FMDatabaseQueue
    
    //var dbconns: [String: FMDatabase]
    var dbconns: [String: FMDatabaseQueue]
    
    var logger: Logger?
    
    // where tiles live
    var root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    public init(root: URL?, logger: Logger?) {
        
        // self.dbqueue = FMDatabaseQueue()
        
        self.dbconns = [:]
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
                databases.append(url)
            }
            
            return .success(databases)
            
        } catch (let error) {
            self.logger?.error("Failed to list databases in \(db_root): \(error)")
            return .failure(error)
        }
    }
    
    public func ListTilesForDatabase(rel_path: String)->Result<StringIterator, Error> {
        
        let db_rsp = ListTiles(rel_path: rel_path)
        
        switch db_rsp {
        case .failure(let error):
            return .failure(error)
        case .success(let db_iter):
            return .success(db_iter)
        }
    }
    
    
    public func ListTiles(rel_path: String) -> Result<StringIterator, Error> {
        
        let db_path = DatabasePath(rel_path: rel_path)
        
        let conn_rsp = dbConn(db_path: db_path)
        // let db: FMDatabase
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
                self.logger?.warning("Query failed \(error)")
                rollback.pointee = true
                ok = false
                return
            }
            
        }
        
        if !ok {
            return .failure(Errors.nullDataError)
        }
        
        let iter = MBTilesIterator(prefix: db_path, result_set: rs)
        return .success(iter)
    }
    
    public func ReadTileAsDataURLFromURI(rel_path: String, callback: (_ rel_path: String) -> Result<MBTile, Error>)->Result<String, Error>{
        
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
        
        let data_rsp = ReadTileAsDataURL(tile: tile)
        
        switch data_rsp {
        case .failure(let error):
            return .failure(error)
        case .success(let body):
            return .success(body )
        }
    }
    
    public func ReadTileAsDataURL(tile: MBTile) -> Swift.Result<String, Error> {
        
        let im_result = ReadTileAsUIImage(tile: tile)
        
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
    
    public func ReadTileAsUIImage(tile: MBTile)->Result<UIImage, Error>{
        
        let data_rsp = ReadTileAsData(tile: tile)
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
    
    public func ReadTileAsData(tile: MBTile)->Swift.Result<Data, Error>{
        
        let db_path = DatabasePathFromTile(tile: tile) 
        
        print("READ TILE FROM \(db_path)")
        
        let conn_rsp = dbConn(db_path: db_path)
        // let db: FMDatabase
        let db: FMDatabaseQueue
        
        
        switch conn_rsp {
        case .failure(let error):
            return .failure(error)
        case .success(let c):
            db = c
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
                    // return .failure(Errors.databaseTile)
                    self.logger?.warning("Query failed : No data")
                    rollback.pointee = true
                    ok = false
                    return
                }
                
                body = data
                
            } catch (let error){
                self.logger?.warning("Query failed \(error)")
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
    
    // private func dbConn(db_path: String)->Swift.Result<FMDatabase, Error> {
    private func dbConn(db_path: String)->Swift.Result<FMDatabaseQueue, Error> {
        
        print("GET DB CONN FOR \(db_path)")
        
        self.logger?.debug("Get database connection for \(db_path)")
        semaphore.wait()
        // wishing I could Go-style defer semaphore.signal()...
        
        // var conn: FMDatabase!
        var conn: FMDatabaseQueue!
        
        if let _ = dbconns[db_path] {
            conn = dbconns[db_path]
            semaphore.signal()
            return .success(conn)
        }
        
        if !FileManager.default.fileExists(atPath: db_path) {
            self.logger?.error("SQLite database \(db_path) does not exist")
            semaphore.signal()
            return .failure(Errors.isNotExistError)
        }
        
        guard let db_uri = URL(string: db_path) else {
            return .failure(Errors.databaseURI)
        }
        
        guard let db = FMDatabaseQueue(url: db_uri) else {
            print("SAD DB QUEUE...")
            return .failure(Errors.databaseURI)
        }
        
        /*
         let db = FMDatabase(url: db_uri)
         
         guard db.open() else {
         return .failure(Errors.databaseOpen)
         }
         */
        
        dbconns[db_path] = db
        semaphore.signal()
        
        return .success(db)
    }
}
