import Foundation
import Logging
import FMDB

public class MBTilesDatabasePool {
    
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
    
    var dbconns: [String: FMDatabaseQueue]    
    var logger: Logger?
    
    public init(logger: Logger?) {
        self.dbconns = [:]
        self.logger = logger
    }
    
    public func GetConnection(db_path: String)->Swift.Result<FMDatabaseQueue, Error> {
                
        self.logger?.debug("Get database connection for \(db_path)")
        semaphore.wait()
        
        defer {
            semaphore.signal()
        }
        
        // wishing I could Go-style defer semaphore.signal()...
        
        var conn: FMDatabaseQueue!
        
        if let _ = dbconns[db_path] {
            conn = dbconns[db_path]
            return .success(conn)
        }
        
        if !FileManager.default.fileExists(atPath: db_path) {
            self.logger?.error("SQLite database \(db_path) does not exist")
            return .failure(Errors.isNotExistError)
        }
        
        guard let db_uri = URL(string: db_path) else {
            return .failure(Errors.databaseURI)
        }
        
        guard let db = FMDatabaseQueue(url: db_uri) else {
            return .failure(Errors.databaseOpen)
        }
        
        dbconns[db_path] = db        
        return .success(db)
    }
}
