import Foundation

public class MBTileUtils {
	
	public enum Errors: Error {
    		case pathError
    		case bundleError	
		case isNotExistError
	}
	
	var mb: MBTiles
    	var tile_root: String

    	init(root: String){
		mb = MBTiles()
		tile_root = root
	}
	
	public func ReadTileAsDataURL(rel_path: String)->Result<String, Error>{
		
		// I tried doing it the right way with regular expressions
		// but they are even weirder in Swift than they are in Go
		// which is saying something... (20190624/thisisaaronland)
		// let base_pat = "tiles/png/(\\d+)\\/(\\d+)/(\\d+)\\.png"
		// let aerial_pat = "tiles/aerial/(\\d{4})/(\\d+)/(\\d+)/(\\d+)\\.png"
		// let base_re = NSRegularExpression(pattern: base_pat, options: nil, error: nil)
		// let aerial_re = NSRegularExpression(pattern: aerial_pat, options: nil, error: nil)
		
		var z: String
		var x: String
		var y: String
		var db_name: String
		
		let parts = rel_path.components(separatedBy: "/")
		
		switch parts[1] {
		case "png":
			db_name = "base"
			z = parts[2]
			x = parts[3]
			y = parts[4].replacingOccurrences(of: ".png", with: "")
		case "aerial":
			db_name = parts[2]
			z = parts[3]
			x = parts[4]
			y = parts[5].replacingOccurrences(of: ".png", with: "")
		default:

			return .failure(Errors.pathError)
		}

		guard let db_path = Bundle.main.path(forResource:db_name, ofType: "db", inDirectory: tile_root) else {
		    return .failure(Errors.bundleError)
		}
	
		// it sure would be nice to be able to return mb.ReadTileAsDataURL(...)
		
		let data_rsp = mb.ReadTileAsDataURL(db_path: db_path, z: z, x: x, y: y)
		
		switch data_rsp {
		case .failure(let error):
			return .failure(error)
		case .success(let body):
			return .success(body )
		}
	}
}
