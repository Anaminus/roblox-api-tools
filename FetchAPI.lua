--[[

# FetchAPI

This module is used to retrieve ROBLOX API data directly from the ROBLOX
website.

## Usage

The FetchAPI function retrieves a ROBLOX build from a version hash. This is a
string that takes the form of:

	version-<hash>

Where `<hash>` is some 16-digit hexadecimal number.

If no arguments are passed, FetchAPI will retrieve data for the latest version
of the ROBLOX client.

If one argument is passed, then the argument is the version hash of a specific
client build to retrieve. Depending on the build, it may be necessary to
supply the version hash of a related studio build as a second argument.

Returns three values:
- An unparsed API dump string
- A table of class names and their corresponding explorer image indexes
- The path to the directory where the ROBLOX client executable is located

## Example

	local FetchAPI = require 'FetchAPI'

	-- RobloxApp build
	local dump, explorerIndex, dir = FetchAPI('version-87de5333d4254860')

	-- RobloxPlayer build
	local dump, explorerIndex, dir = FetchAPI('version-38293b7e060d4866')

	-- RobloxPlayerBeta build
	local dump, explorerIndex, dir = FetchAPI('version-12cd4783f01a48cf')

	-- Studio-required build
	local dump, explorerIndex, dir = FetchAPI(
		'version-19c5d0ac8e9b47c4',
		'version-e8936cd10a7748e5'
	)

## Dependencies

- LuaFileSystem
- LuaSocket
- LuaZip

## More Info

https://github.com/Anaminus/roblox-api-dump

]]

-- Combines arguments into a path, and normalizes
local function path(...)
	local a = {...}
	local p = a[1] or ''
	for i = 2,#a do
		p = p .. '/' .. a[i]
	end
	return p:gsub('[\\/]+','/')
end

local baseURL = 'roblox.com'
local setupURL = 'http://setup.' .. baseURL .. '/'
local tmpDir = path(os.getenv('TEMP'),'roblox-build-cache/')
local dumpName = 'dump.rbxapi'

local function mkdir(...)
	local lfs = require 'lfs'
	local s,err = lfs.mkdir(...)
	if not s and not err:match('File exists') then
		return s,err
	end
	return true
end

-- open a file, creating directories as necessary
local function dopen(name,...)
	name = path(name)
	local list = {}
	for dir in name:gmatch('[^/]+') do
		list[#list+1] = dir
	end
	local dir = ''
	for i = 1,#list do
		local f,m = io.open(name,...)
		if f then
			return f
		elseif m:match('No such file or directory') then
			dir = dir .. (i==1 and '' or '/') .. list[i]
			local s,err = mkdir(dir)
			if not s then return s,err end
		else
			return nil,m
		end
	end
	return nil,"Could not open file"
end

local function exists(filename)
	return not not lfs.attributes(filename)
end

-- returns true if file does not exist
local function fileempty(filename)
	local size = lfs.attributes(filename,'size')
	return not size or size == 0
end

local function dirempty(dir)
	local c = 0
	for d in lfs.dir(dir) do
		if d ~= '..' and d ~= '.' then
			c = c + 1
		end
	end
	return c == 0
end

-- verify whether the content of a build folder is complete
local function validBuild(dir)
	if not exists(dir) then
		return false
	end
	if dirempty(dir) then
		return false
	end
	if exists(path(dir,'INVALID')) then
		return false
	end
	return true
end

local function filter(msg,b,s,h,l)
	if b == nil then
		return b,s
	end
	if s ~= 200 then
		return nil,msg
	end
	return b,s,h,l
end

local function readManifest(ver)
	local http = require 'socket.http'
	local ltn12 = require 'ltn12'
	local filename = path(tmpDir,ver,'rbxManifest.txt')
	local f,err = io.open(filename,'rb')
	if not f then
		local b,s = filter(
			"Failed to get manifest from `" .. setupURL .. ver .. "-rbxManifest.txt`",
			http.request{
				url = setupURL .. ver .. '-rbxManifest.txt';
				sink = ltn12.sink.file(io.open(filename,'wb'));
			}
		)
		if not b then return b,s end
		f,err = io.open(filename,'rb')
	end
	if not f then
		return nil,"Could not open manifest file: " .. err
	end

	local man = f:read('*a')
	f:close()

	local manifest = {}
	for name,hash in man:gmatch('(.-)\r?\n(%x+)\r?\n') do
		manifest[name] = hash
	end
	return manifest
end

local function unzip(url,dir)
	local zip = require 'zip'
	local http = require 'socket.http'
	local ltn12 = require 'ltn12'
	local ztmp = os.tmpname()

	local b,s = filter(
		"Failed to get file `" .. url .. "`",
		http.request{
			url = url;
			sink = ltn12.sink.file(io.open(ztmp,'wb'));
		}
	)
	if not b then return b,s end

	local zipfile,err = zip.open(ztmp)
	if not zipfile then
		return nil,"Could not open file `" .. url .. "`: " .. err
	end
	for data in zipfile:files() do
		local filename = data.filename
		-- If file is not a directory
		if filename:sub(-1,-1) ~= '/' then
			-- Copy file to given folder
			local zfile,err = zipfile:open(filename)
			if not zfile then
				return nil,"Could not unzip `" .. filename .. "`: " .. err
			end
			local file,err = dopen(path(dir,filename),'wb')
			if not file then
				zfile:close()
				return nil,"Could not open `" .. path(dir,filename) .. "`: " .. err
			end

			file:write(zfile:read('*a'))
			file:flush()
			file:close()
			zfile:close()
		end
	end
	zipfile:close()
	return true
end

return function(verPlayer,verStudio)
	local lfs = require 'lfs'
	local http = require 'socket.http'

	local s,err = mkdir(tmpDir)
	if not s then
		return s,"Could not create temporary directory: " .. err
	end

	if not verPlayer then
		local b,s = filter(
			"Failed to get latest player version",
			http.request(setupURL .. 'version')
		)
		if not b then return b,s end
		verPlayer = b
	end

	local dirPlayer = path(tmpDir,verPlayer)

	if not validBuild(dirPlayer) then
		local s,err = mkdir(dirPlayer)
		if not s then
			return s,"Could not create player directory: " .. err
		end
		s,err = io.open(path(dirPlayer,'INVALID'),'wb')
		if not s then
			return s,"Could not create placeholder file: " .. err
		end
		s:close()


		-- AppSettings must be created manually
		local app,err = io.open(path(dirPlayer,'AppSettings.xml'),'w')
		if not app then
			return app,"Could not open AppSettings.xml for writing: " .. err
		end
		app:write([[
<?xml version="1.0" encoding="UTF-8"?>
<Settings>
	<ContentFolder>content</ContentFolder>
	<BaseUrl>http://www.]] .. baseURL .. [[</BaseUrl>
</Settings>]])
		app:flush()
		app:close()

		-- Content directory is required by the exe
		mkdir(path(dirPlayer,'content'))
		if not s then
			return s,"Could not create content directory: " .. err
		end

		local zips = {
			{setupURL .. verPlayer .. '-RobloxApp.zip',dirPlayer};
			{setupURL .. verPlayer .. '-Libraries.zip',dirPlayer};
			{setupURL .. verPlayer .. '-redist.zip',dirPlayer};
		}
		for i = 1,#zips do
			local s,err = unzip(zips[i][1],zips[i][2])
			if not s then return s,err end
		end

		s,err = os.remove(path(dirPlayer,'INVALID'))
		if not s then
			return s,"Could not remove placeholder file: " .. err
		end
	end

	-- Indicates whether the given studio version is different from the cached
	-- results.
	local updateStudio do
		local f,err = io.open(path(dirPlayer,'STUDIO'),'rb')
		-- If the STUDIO file does not exist, then the player may not require
		-- a studio build. If it turns out that it does, then the STUDIO file
		-- will be created, indicating that the player requires one. If not,
		-- then updateStudio will always be false.
		if f then
			-- If updateStudio is true, then files will be updated whether they
			-- exist or not.
			updateStudio = verStudio ~= f:read('*a')
			f:close()
		else
			updateStudio = false
		end
	end

	if fileempty(path(dirPlayer,'ReflectionMetadata.xml')) or updateStudio then
		if not verStudio then
			local b,s = filter(
				"Failed to get latest studio version",
				http.request(setupURL .. 'version')
			)
			if not b then return b,s end
			verStudio = b
		end

		local dirStudio = path(tmpDir,verStudio)
		if not validBuild(dirStudio) then
			local s,err = mkdir(dirStudio)
			if not s then
				return s,"Could not create studio directory: " .. err
			end
			s,err = io.open(path(dirStudio,'INVALID'),'wb')
			if not s then
				return s,"Could not create placeholder file: " .. err
			end
			s:close()

			s,err = unzip(setupURL .. verStudio .. '-RobloxStudio.zip',dirStudio)
			if not s then return s,err end

			s,err = os.remove(path(dirStudio,'INVALID'))
			if not s then
				return s,"Could not remove placeholder file: " .. err
			end
		end

		local a,err = io.open(path(dirStudio,'ReflectionMetadata.xml'),'rb')
		if not a then
			return nil,"Could not open ReflectionMetadata for reading: " .. err
		end

		local f = io.open(path(dirPlayer,'STUDIO'),'wb')
		if f then
			f:write(verStudio)
			f:flush()
			f:close()
		end

		local b,err = io.open(path(dirPlayer,'ReflectionMetadata.xml'),'wb')
		if not b then
			a:close()
			return nil,"Could not open ReflectionMetadata for writing: " .. err
		end
		b:write(a:read('*a'))
		b:flush()
		a:close()
		b:close()
	end

	local apiDump do
		if fileempty(path(dirPlayer,dumpName)) or updateStudio then
			local command = {
				{[[RobloxPlayerBeta.exe]],[[--API]],dumpName};
				{[[RobloxPlayer.exe]],[[-API]],dumpName};
				{[[RobloxApp.exe]],[[-API]],dumpName};
			}

			local manifest,err = readManifest(verPlayer)
			if not manifest then return manifest,err end

			local dir = lfs.currentdir()
			lfs.chdir(dirPlayer)
			for i = 1,#command do
				if manifest[command[i][1]] then
					local cmd = table.concat(command[i],' ')
					if os.execute(cmd) == 0 then
						break
					end
				end
			end
			lfs.chdir(dir)
		end

		local f = io.open(path(dirPlayer,dumpName),'rb')
		if not f then
			return nil,"Could not get API dump"
		end

		apiDump = f:read('*a')
		f:close()
	end

	local rmd do
		local f,err = io.open(path(dirPlayer,'ReflectionMetadata.xml'),'rb')
		if not f then
			return f,"Could not open ReflectionMetadata: " .. err
		end
		rmd = f:read('*a')
		f:close()
	end

	local explorerIndex = {}
	for props in rmd:gmatch('<Item class="ReflectionMetadataClass">.-<Properties>(.-)</Properties>') do
		local class,index = props:match('<string name="Name">(.-)</string>.-<string name="ExplorerImageIndex">(.-)</string>')
		if class and index then
			explorerIndex[class] = tonumber(index)
		end
	end

	return apiDump,explorerIndex,dirPlayer
end
