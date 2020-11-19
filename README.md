# swift-mbtiles

Swift package for reading and caching data from MBTile databases.

## Important

Work in progress. Documentation to follow.

## Example

_This example is incomplete._

```
let logger = Logger(label: "org.example.mbtiles")
logger.logLevel = .info
        
let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
let tiles_resolver = TileResolver()
        
let tiles_collection = MBTilesCollection(root: root, logger: logger)
let tiles_pool = MBTilesDatabasePool(logger: logger)
let tiles_reader = MBTilesReader(resolver: tiles_resolver, logger: logger)
let tiles_cache = MBTilesCache(db_pool: tiles_pool, db_reader: tiles_reader, resolver: tiles_resolver, throttle: 10, logger: logger)
```

## Under the hood

Under the hood this package is using [stephencelis/SQLite.swift](https://github.com/stephencelis/SQLite.swift) for database access.

There is also [a branch that uses FMDB](https://github.com/sfomuseum/swift-mbtiles/tree/fmdb) but it contains a crashing bug that I haven't been able to debug (taking in to account all the things that the documentation says to do).

## See also

* https://github.com/stephencelis/SQLite.swift