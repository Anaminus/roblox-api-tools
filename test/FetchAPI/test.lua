package.path = package.path .. ';../../?.lua'

local versions = {
	{'version-87de5333d4254860'}; -- RobloxApp; first (known) version with API dump
	{'version-38293b7e060d4866'}; -- Switches to RobloxPlayer
	{'version-12cd4783f01a48cf'}; -- Adds RobloxPlayerBeta
	{'version-19c5d0ac8e9b47c4','version-e8936cd10a7748e5'}; -- RobloxPlayer and ReflectionMetadata are removed
}

-- return the contents of a file
local function read(name)
	local f = assert(io.open(name,'rb'))
	local r = f:read('*a')
	f:close()
	return r
end

-- compare the contents of two tables
local function teq(a,b)
	for k,v in pairs(a) do
		if b[k] ~= v then
			return false
		end
	end
	for k,v in pairs(b) do
		if a[k] ~= v then
			return false
		end
	end
	return true
end

local FetchAPI = require 'FetchAPI'

local function test(v)
	local verPlayer = v[1]
	local verStudio = v[2]

	print("Testing",verPlayer,verStudio)

	local aDump = read(verPlayer .. '.rbxapi')
	local aIndex = require(verPlayer)

	local bDump,bIndex,bDir = FetchAPI(verPlayer,verStudio)
	if not bDump then
		print("FetchAPI failed:",bIndex)
	end

	assert(bDump==aDump,"APIDump test failed: Dump does not match")
	assert(teq(bIndex,aIndex),"ExplorerIndex test failed: ExplorerIndex table contents do not match")
	assert(#bDir > 0,"Directory test failed: Path is empty")
	print()
end

print("Uncached test")
for i = 1,#versions do
	test(versions[i])
end

-- rerun the test again; the results should have been cached
print("Cached test")
for i = 1,#versions do
	test(versions[i])
end

print("Test Finished")
