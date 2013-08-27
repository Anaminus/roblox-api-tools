--[[

ParseRbxAPI

An API dump file is created when RobloxPlayer.exe is run using the following options:

	RobloxPlayer -API api.txt

This dumps the API to a file named "api.txt".

The purpose of this module is to parse the contents of the dump file to a Lua table, so that it may be manipulated more easily.


USAGE

The ParseRbxAPI function expects a string, which is the contents of the dump file.
It returns a table containing the parsed data. Here's an example:

	local ParseRbxAPI = require 'ParseRbxAPI'

	local f = io.open('api.txt')
	local data = f:read('*a')
	f:close()

	local database = ParseRbxAPI(data)


TABLE CONTENTS

The returned table is a list of "items", which are tables. All items contain the following fields:
	string `type`  The type of item. Used to indicate what other fields are available in the item.
	table `tags`   A set of tags attached to the item. Each entry is a ["tagname"]=true pair.

Each item has a specific type with its own additional fields:

Class
	string `Name`         The name of the class.
	string `Superclass`   The class this class inherits from. Will be nil if the class does not inherit.
Property
	string `Name`         The name of the member.
	string `Class`        The class this item is a member of.
	string `ValueType`    The type of the property's value.
Function
	string `Name`         The name of the member.
	string `Class`        The class this item is a member of.
	string `ReturnType`   The type of the value returned by the function.
	table `Arguments`     A list of arguments passed to the function. Each argument is a table containing the following fields:
		string `Name`     The name of the argument.
		string `Type`     The value type of the argument.
		string `Default`  The default value if the argument is not given. Will be nil if the argument does not have default value.
Event
	string `Name`         The name of the member.
	string `Class`        The class this item is a member of.
	table `Parameters`    A list of parameters received by the event listener. Each parameter is a table containing the following fields:
		string `Name`     The name of the parameter.
		string `Type`     The value type of the parameter.
Callback
	string `Name`         The name of the member.
	string `Class`        The class this item is a member of.
	string `ReturnType`   The type of the value that should be returned by the callback.
	table `Parameters`    A list of parameters received by the callback. Each parameter is a table containing the following fields:
		string `Name`     The name of the parameter.
		string `Type`     The value type of the parameter.
YieldFunction
	string `Name`         The name of the member.
	string `Class`        The class this item is a member of.
	string `ReturnType`   The type of the value returned by the function.
	table `Arguments`     A list of arguments passed to the function. Each argument is a table containing the following fields:
		string `Name`     The name of the argument.
		string `Type`     The value type of the argument.
		string `Default`  The default value if the argument is not given. Will be nil if the argument does not have default value.
Enum
	string `Name`         The name of the enum.
EnumItem
	string `Enum`         The enum this item is a member of.
	string `Name`         The name associated with the enum item.
	int `Value`           The enum item's integer value.


EXAMPLE

Dump:

	Class Instance : Root
		Property int Instance.DataCost [readonly] [RobloxPlaceSecurity]
		Function Instance Instance:FindFirstChild(string name, bool recursive = false)

Table:

	return {
		{
			type = "Class";
			tags = {};
			Name = "Instance";
			Superclass = "Root";
		};
		{
			type = "Property";
			tags = {"readonly", "RobloxPlaceSecurity"};
			Name = "DataCost";
			Class = "Instance";
			ValueType = "int";
		};
		{
			type = "Function";
			tags = {};
			Name = "FindFirstChild";
			Class = "Instance";
			ReturnType = "Instance";
			Arguments = {
				{
					Name = "name";
					Type = "string";
				};
				{
					Name = "recursive";
					Type = "bool";
					Default = "false";
				};
			};
		};
	}

]]

-- how to match various names
local mC = '%S+'     -- class name
local mM = '[%w_ ]+' -- member name
local mT = '%S+'     -- value type
local mE = '[%w_ ]+' -- enum item name

-- Parses an item's tags (stuff in square brackets)
local function ParseTags(item,tags)
	local tagSet = {}
	for tag in tags:gmatch("%[(.-)%]") do
		tagSet[tag] = true
	end
	item.tags = tagSet
end

--  Parses comma-separated arguments/parameters
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
		local className,memberName,paramData,tags
		= data:match("^("..mC..")%.("..mM..")(%b())(.*)$")

		local item = {
			Class = className;
			Name = memberName;
			Parameters = {};
		}
		ParseArguments(item.Parameters,paramData)
		ParseTags(item,tags)
		return item
	end;
	Callback = function(data)
		local returnType,className,memberName,paramData,tags
		= data:match("^("..mT..") ("..mC..")%.("..mM..")(%b())(.*)$")

		local item = {
			Class = className;
			Name = memberName;
			ReturnType = returnType;
			Parameters = {};
		}
		ParseArguments(item.Parameters,paramData)
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
