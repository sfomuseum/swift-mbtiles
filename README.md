# swift-mbtiles

Swift package for reading and caching MBTile databases.

## Important

Work in progress. Documentation.

## Under the hood

Under the hood this package is using [stephencelis/SQLite.swift](https://github.com/stephencelis/SQLite.swift) for database access.

There is also [a branch that uses FMDB](https://github.com/sfomuseum/swift-mbtiles/tree/fmdb) but it contains a crashing bug that I haven't been able to debug (taking in to account all the things that the documentation says to do).

## See also

* https://github.com/stephencelis/SQLite.swift