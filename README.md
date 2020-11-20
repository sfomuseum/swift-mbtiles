# swift-mbtiles

Swift package for reading and caching data from MBTile databases.

## Important

Work in progress, including documentation.

## Example

```
// Logger is part of the swift-log packacge and is an optional parameter for
// the swift-mbtiles classes described below

let logger = Logger(label: "org.example.mbtiles")
logger.logLevel = .info

let tiles_resolver = TileResolver()

let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let tiles_collection = MBTilesCollection(root: root, logger: logger)
        
let tiles_pool = MBTilesDatabasePool(logger: logger)
let tiles_reader = MBTilesReader(resolver: tiles_resolver, logger: logger)
let tiles_cache = MBTilesCache(db_pool: tiles_pool, db_reader: tiles_reader, resolver: tiles_resolver, throttle: 10, logger: logger)
```

An attempt has been made to create small and discrete classes that only do a finite set of tasks. They are:

* `MBTilesCollection` This class manages a set of MBTiles database contained in a parent directory.
* `MBTilesDatabasePool` This class manages database connections to one or more MBTiles (SQLite) databases.
* `MBTilesReader` This class manages queries of and reading data from an MBTiles (SQLite) database.
* `MBTilesCache` This class manages a caching layer for tile requests. Interface-wise it's a bit of a mess; this is discussed more below.

Some of these classes suffer, in a technical sense, from "leaky abstractions". That's not ideal but in the interest of "getting things done" they are understood as acceptable compromises until such a time as they are not.

Under the hood this package is using [stephencelis/SQLite.swift](https://github.com/stephencelis/SQLite.swift) for database access. The (SQLite) database layer has not been abstracted behind a single class (`MBTilesDatabasePool`). The different `swift-mbtiles` classes pass each other `SQLite` instances. This is one of those places where, in time, we might be able to develop a higer level abstraction for MBTiles-related tasks but, as of this writing, it's still too soon for that.

There is also [a branch that uses FMDB](https://github.com/sfomuseum/swift-mbtiles/tree/fmdb) but it contains a crashing bug that I haven't been able to debug (taking in to account all the things that the documentation says to do).

Did you notice the instatiation of the `TileResolver()` class above? This is code that you will need to implement and that conforms to the `MBTilesResolver` protocol below. This is code used to resolve a URL in to MBTile database specifics like the name of the database and Z, X, Y coordinates.

Once all of these classes have been instantiated you can precache the tiles in your MBTiles databases like this:

```
DispatchQueue.global(qos: .background).async {
                
	let db_rsp = tiles_collection.Databases()
	var database_urls = Array<URL>()
                
	switch db_rsp {
	case .failure(let error):
		// handle error here
	case .success(let urls):
		database_urls = urls
	}
                
	let cache_rsp = tiles_cache.PrecacheTileData(databases: database_urls)
                
	if case .failure(let error) = cache_rsp {
		// handle error here
	}
}	
```

And then later on in your code when a tile is requested we check to see if we have a cached version:

```
if let _ = tiles_cache.missing.object(forKey: tile_path as NSString) {
	return .failure(Errors.missingTileError)
}
		
if let tile_data = tiles_cache.cache.object(forKey: tile_path as NSString) {
	return .success(tile_data as String)
}
```

See the way we're calling `tiles_cache.missing.object` and `tiles_cache.cache.object` ? These are not ideal interfaces for dealing with tile caching. What's really needed is an interface for _tiles_ that sits on top of a generic interface for caching and there hasn't been the luxury of time to figure that out yet. It is definitely an area for improvement.

Assuming there isn't a cached version (and we don't know that the tile is missing) the tile data would be retrieved like this:

```
let tile_path = "tiles/example/10/12/345.png"

var tile: MBTile
			
let tile_rsp = tiles_resolver.MBTileFromPath(path: tile_path)
			
switch tile_rsp {
case .failure(let error):
	// handle error here
case .success(let t):
	tile = t
}
			
let db_path = tiles_collection.DatabasePathFromTile(tile: tile)
			
let data_rsp = tiles_reader.ReadTileAsDataURL(db_pool: tiles_pool, db_path: db_path, tile: tile)
			
switch data_rsp {
case .failure(let error):
	// handle error here				
case .success(let tile_data):
	tiles_cache.cache.setObject(NSString(string: tile_data), forKey:NSString(string: tile_path))
	// do something with tile data here
}
```


## MBTilesResolver

```
public protocol MBTilesResolver {
    func PrefixFromPath(path: String) -> Result<String, Error>
    func MBTileFromPath(path: String) -> Result<MBTile, Error>
    func PathFromMBTile(tile: MBTile) -> Result<String, Error>
}
```

## See also

* https://github.com/stephencelis/SQLite.swift