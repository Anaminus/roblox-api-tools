--[[

# ParseAPI

An API dump file is created when a Roblox executable is run using the
following options:

    RobloxPlayer -API api.txt
    RobloxPlayerBeta --API api.txt

These dump the API to a file named `api.txt`.

The purpose of this module is to parse the contents of the dump file to a Lua
table, so that it may be manipulated more easily.


## Usage

The ParseAPI function expects a string, which is the contents of the dump
file. It returns a table containing the parsed data. Here's an example:

	local ParseAPI = require 'ParseAPI'

	local f = io.open('api.txt')
	local data = f:read('*a')
	f:close()

	local database = ParseAPI(data)

## More Info

https://github.com/Anaminus/roblox-api-dump

]]

-- how to match various names
local mC = '[%w_<> ]*[%w_<>]' -- class name
local mM = '[%w_ ]*[%w_]'     -- member name
local mT = '[%w_]+'           -- value type
local mE = '[%w_ ]*[%w_]'     -- enum item name

-- Parses an item's tags (stuff in square brackets)
local function ParseTags(item,tags)
	local tagSet = {}
	for tag in tags:gmatch("%[(.-)%]") do
		tagSet[tag] = true
	end
	item.tags = tagSet
end

--  Parses comma-separated arguments
local function ParseArguments(out,data)
	if #data > 2 then
		for arg in data:sub(2,-2):gmatch("[^,]+") do -- make this better
			local type,name,default
			= arg:match("^ ?("..mT..") (%w+)(.*)$")

			if #default > 0 then
				default = default:match("^ = (.*)$")
			else
				default = nil
			end
			out[#out+1] = {
				Type = type;
				Name = name;
				Default = default;
			}
		end
	end
end

local ParseItem = {
	Class = function(data)
		local className,superClass,tags
		= data:match("^("..mC..") : ("..mC..")(.*)$")

		if not className then
			className,tags = data:match("^("..mC..")(.*)$")
		end

		local item = {
			Name = className;
			Superclass = superClass;
		}
		ParseTags(item,tags)
		return item
	end;
	Property = function(data)
		local valueType,className,memberName,tags
		= data:match("^("..mT..") ("..mC..")%.("..mM..")(.*)$")

		local item = {
			Class = className;
			Name = memberName;
			ValueType = valueType;
		}
		ParseTags(item,tags)
		return item
	end;
	Function = function(data)
		local returnType,className,memberName,argumentData,tags
		= data:match("^("..mT..") ("..mC..")%:("..mM..")(%b())(.*)$")

		local item = {
			Class = className;
			Name = memberName;
			ReturnType = returnType;
			Arguments = {};
		}
		ParseArguments(item.Arguments,argumentData)
		ParseTags(item,tags)
		return item
	end;
	Event = function(data)
		local className,memberName,argData,tags
		= data:match("^("..mC..")%.("..mM..")(%b())(.*)$")

		local item = {
			Class = className;
			Name = memberName;
			Arguments = {};
		}
		ParseArguments(item.Arguments,argData)
		ParseTags(item,tags)
		return item
	end;
	Callback = function(data)
		local returnType,className,memberName,argData,tags
		= data:match("^("..mT..") ("..mC..")%.("..mM..")(%b())(.*)$")

		local item = {
			Class = className;
			Name = memberName;
			ReturnType = returnType;
			Arguments = {};
		}
		ParseArguments(item.Arguments,argData)
		ParseTags(item,tags)
		return item
	end;
	YieldFunction = function(data)
		local returnType,className,memberName,argumentData,tags
		= data:match("^("..mT..") ("..mC..")%:("..mM..")(%b())(.*)$")

		local item = {
			Class = className;
			Name = memberName;
			ReturnType = returnType;
			Arguments = {};
		}
		ParseArguments(item.Arguments,argumentData)
		ParseTags(item,tags)
		return item
	end;
	Enum = function(data)
		local enumName,tags
		= data:match("^("..mC..")(.*)$")

		local item = {
			Name = enumName;
		}
		ParseTags(item,tags)
		return item
	end;
	EnumItem = function(data)
		local enumName,itemName,itemValue,tags
		= data:match("^("..mC..")%.("..mE..") : (%d+)(.*)$")

		local item = {
			Enum = enumName;
			Name = itemName;
			Value = tonumber(itemValue) or itemValue;
		}
		ParseTags(item,tags)
		return item
	end;
}

-- Parse API Dump, line by line
return function(source)
	local database = {}
	local nLine = 0
	for line in source:gmatch("[^\r\n]+") do
		nLine = nLine + 1
		local type,data = line:match("^\t*(%w+) (.+)$")
		local parser = ParseItem[type]
		if parser then
			local item,err = parser(data)
			if item then
				item.type = type
				database[#database+1] = item
			else
				print("error parsing line "..nLine..": "..err)
			end
		else
			print("unsupported item type `"..tostring(type).."` on line "..nLine)
		end
	end
	return database
end
