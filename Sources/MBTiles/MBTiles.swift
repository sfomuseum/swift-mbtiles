import SQLite
import Foundation
import Cocoa

import FMDB

// https://github.com/stephencelis/SQLite.swift/blob/master/Documentation/Index.md
// note that SQLite.swift defines its own Result type so be explicit about Swift.Result below

class MBTiles {
	
	public enum Errors: Error {
		case isNotExistError
		case pngError
		case blobError
		case nullDataError
        case databaseURI
        case databaseOpen
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
		
		let blob_rsp = ReadTileAsBlob(db_path: db_path, z: z, x: x, y: y)
		let blob: SQLite.Blob
		
		switch blob_rsp {
		case .failure(let error):
			return .failure(error)
		case .success(let b):
			blob = b
		}
		
		
		guard let im = NSImage(data: Data.fromDatatypeValue(blob)) else {
			return .failure(Errors.blobError)
		}
		
		return .success(im)
	}
	
	func ReadTileAsBlob(db_path: String, z: String, x: String, y: String)->Swift.Result<SQLite.Blob, Error>{
		
		let conn_rsp = dbConn(db_path: db_path)
		let conn: FMDatabase
		
		switch conn_rsp {
		case .failure(let error):
			return .failure(error)
		case .success(let c):
			conn = c
		}
		
		// please move this in to init()
		var get_tile: Statement
		
		do  {
			get_tile = try conn.prepare("SELECT i.tile_data FROM map m, images i WHERE i.tile_id = m.tile_id AND m.zoom_level=? AND m.tile_column=? AND m.tile_row=?")
		} catch {
			return .failure(error)
		}
		
		var tile_data: SQLite.Blob?
		
		do {
			try get_tile = get_tile.run(z, x, y)
			tile_data = try get_tile.scalar() as? SQLite.Blob
				
			if (tile_data == nil){
				return .failure(Errors.nullDataError)
			}

		} catch {
			print(db_path, z, x, y, error)
			return .failure(error)
		}
		
		return .success(tile_data as! SQLite.Blob)
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
