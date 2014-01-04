# Roblox API Dump

An API dump file is created when a Roblox executable is run using the
following options:

    RobloxPlayer -API api.txt
    RobloxPlayerBeta --API api.txt

These dump the API to a file named `api.txt`. Note that Studio does not
currently support this command.

Some information in the API dump is taken from the `ReflectionMetadata.xml`
file. As a consequence, this file must be present in order to generate the
dump.

This repo contains Lua functions for handling the API dump in various ways.

## ParseAPI and LexAPI

These two functions are used for parsing the contents of the dump into a Lua
table, so that it may be manipulated more easily.

The first function, ParseAPI, uses regular expressions for parsing. It is
small and fast, but will crash and burn if the contents of the dump are
malformed. It is pretty much safe to use on an unmodified dump file taken
directly from the Roblox exe.

In comparison, the second function, LexAPI, is larger and slower, but
significantly more accurate. If the dump is malformed in any way, this
function will tell you the exact location of the error, down to the character.
Use this if you're making modifications to the dump file, and need to verify
that it is correct.

LexAPI could also be considered a generic implementation, which may be
portable into other languages fairly easily.

### Usage

Both functions expect a string, which is the contents of the dump file. They
both return a table containing the parsed data, in the exact same format.
Here's an example:

    local ParseAPI = require 'ParseAPI'

    local f = io.open('api.txt')
    local data = f:read('*a')
    f:close()

    local database = ParseAPI(data)

### More Info

See the [API dump format][wikiDumpFormat] page for information about the returned
table.

## FetchAPI

This function is used to retrieve Roblox API data directly from the Roblox
website.

### Usage

The FetchAPI function has two optional arguments: The version hash of
RobloxPlayer, and the version hash of RobloxStudio. If an argument is omitted,
then the latest version will be retrieved from the website and used instead.

*The studio must be fetched in order to get the `ReflectionMetadata.xml` file,
which is required, but not present in the RobloxPlayer build.*

Returns three values:
- The unparsed API dump string
- A table of class names and their corresponding explorer image indexes
- The directory where the RobloxPlayer executable that was used to get the
  data is located

Example:

	local FetchAPI = require 'FetchAPI'

	local playerVersion = 'version-01a2b3c4d5e6f789'
	local studioVersion = 'version-98f7e6d5c4b3a210'

	local dump, explorerIndex, dir = FetchAPI(playerVersion, studioVersion)

### Dependencies

FetchAPI depends on the following libraries:

- [LuaFileSystem][lfs]
- [LuaSocket][lsocket]
- [LuaZip][lzip]

### More Info

See the [FetchAPI][wikiFetchAPI] page for information about how FetchAPI
works.

## DiffAPI

This function is used to get the difference between to API dumps.

### Usage

The DiffAPI receives two API dumps (returned from ParseAPI or LexAPI) as
arguments. It returns a list of differences between the two dumps. Example:

	local DiffAPI = require 'DiffAPI'

	local oldDump = LexAPI(oldSource)
	local newDump = LexAPI(newSource)

	local diff = DiffAPI(oldDump, newDump)

### More Info

See the [API diff format][wikiDiffFormat] page for information about the returned
table.

[wikiDumpFormat]: https://github.com/Anaminus/roblox-api-dump/wiki/API-dump-format
[wikiDiffFormat]: https://github.com/Anaminus/roblox-api-dump/wiki/API-diff-format
[wikiFetchAPI]: https://github.com/Anaminus/roblox-api-dump/wiki/FetchAPI
[lfs]: http://keplerproject.github.io/luafilesystem/
[lsocket]: http://w3.impa.br/%7Ediego/software/luasocket/
[lzip]: http://www.keplerproject.org/luazip/
