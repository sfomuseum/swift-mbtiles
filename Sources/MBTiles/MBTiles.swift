import Foundation
import Cocoa
import FMDB

class MBTiles {
	
	public enum Errors: Error {
		case isNotExistError
		case pngError
		case blobError
		case nullDataError
        case databaseURI
        case databaseOpen
        case databaseTile
	}
	
	// https://developer.apple.com/documentation/dispatch/dispatchsemaphore
	// https://stackoverflow.com/questions/46169519/mutex-alternatives-in-swift
	let semaphore = DispatchSemaphore(value: 1)
	
	var dbconns: [String: FMDatabase]
	
	init() {
		dbconns = [:]
	}
	
	func ReadTileAsDataURL(db_path: String, z: String, x: String, y: String) -> Swift.Result<String, Error> {
		
		let im_result = ReadTileAsNSImage(db_path: db_path, z: z, x: x, y: y)
		
		let im: NSImage
		
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
	
	func ReadTileAsNSImage(db_path: String, z: String, x: String, y: String)->Swift.Result<NSImage, Error>{
		
		let data_rsp = ReadTileAsData(db_path: db_path, z: z, x: x, y: y)
		let data: Data
		
		switch data_rsp {
		case .failure(let error):
			return .failure(error)
		case .success(let d):
			data = d
		}
		
		guard let im = NSImage(data: data) else {
			return .failure(Errors.blobError)
		}
		
		return .success(im)
	}
	
	func ReadTileAsData(db_path: String, z: String, x: String, y: String)->Swift.Result<Data, Error>{
		
		let conn_rsp = dbConn(db_path: db_path)
		let db: FMDatabase
		
		switch conn_rsp {
		case .failure(let error):
			return .failure(error)
		case .success(let c):
			db = c
		}
		
        var body: Data
        
        let q = "SELECT i.tile_data AS tile_data FROM map m, images i WHERE i.tile_id = m.tile_id AND m.zoom_level=? AND m.tile_column=? AND m.tile_row=?"
        
		do  {
            let rs = try db.executeQuery(q, values: [ z, x, y])
            rs.next()
            
            guard let data = rs.data(forColumn: "tile_data") else {
                return .failure(Errors.databaseTile)
            }
            
            body = data
            
		} catch {
			return .failure(error)
		}
    
		return .success(body)
	}
	
	private func dbConn(db_path: String)->Swift.Result<FMDatabase, Error> {
		
		semaphore.wait()
		// wishing I could Go-style defer semaphore.signal()...
		
		var conn: FMDatabase!
		
		if let _ = dbconns[db_path] {
			conn = dbconns[db_path]
			semaphore.signal()
			return .success(conn)
		}
		
		if !FileManager.default.fileExists(atPath: db_path) {
			print("SQLite database \(db_path) does not exist")
			semaphore.signal()
			return .failure(Errors.isNotExistError)
		}
		
        guard let db_uri = URL(string: db_path) else {
            return .failure(Errors.databaseURI)
        }
        
        let db = FMDatabase(url: db_uri)
        
        guard db.open() else {
            return .failure(Errors.databaseOpen)
        }
        
        dbconns[db_path] = db
        semaphore.signal()
        
        return .success(db)
	}
}
