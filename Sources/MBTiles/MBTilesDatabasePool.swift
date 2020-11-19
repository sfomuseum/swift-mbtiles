import Foundation
import Logging
import SQLite

public class MBTilesDatabasePool {
    
    public enum Errors: Error {
        case isNotExistError
    }
    
    // https://developer.apple.com/documentation/dispatch/dispatchsemaphore
    // https://stackoverflow.com/questions/46169519/mutex-alternatives-in-swift
    let semaphore = DispatchSemaphore(value: 1)
    
    var dbconns: [String: Connection]
    var logger: Logger?
    
    public init(logger: Logger?) {
        self.dbconns = [:]
        self.logger = logger
    }
    
    public func GetConnection(db_path: String)->Swift.Result<Connection, Error> {
                
        self.logger?.debug("Get database connection for \(db_path)")
        semaphore.wait()
        
        defer {
            semaphore.signal()
        }
        
        // wishing I could Go-style defer semaphore.signal()...
        
        var conn: Connection!
        
        if let _ = dbconns[db_path] {
            conn = dbconns[db_path]
            return .success(conn)
        }
        
        if !FileManager.default.fileExists(atPath: db_path) {
            self.logger?.error("SQLite database \(db_path) does not exist")
            return .failure(Errors.isNotExistError)
        }
        
        do {
            conn = try Connection(db_path, readonly: true)
        } catch {
            return .failure(error)
        }
        
        dbconns[db_path] = conn
        return .success(conn)
    }
}
