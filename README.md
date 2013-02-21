## ParserRbxAPI

An API dump file is created when RobloxPlayer.exe is run using the following options:

    RobloxPlayer -API api.txt

This dumps the API to a file named "api.txt".

The purpose of this module is to parse the contents of the dump file to a Lua table, so that it may be manipulated more easily.


### Usage

The ParseRbxAPI function expects a string, which is the contents of the dump file.
It returns a table containing the parsed data. Here's an example:

    local ParseRbxAPI = require 'ParseRbxAPI'

    local f = io.open('api.txt')
    local data = f:read('*a')
    f:close()

    local database = ParseRbxAPI(data)


### Table Contents

The returned table is a list of "items", which are tables. All items contain the following fields:
	string `type`  The type of item. Used to indicate what other fields are available in the item.
	table `tags`   A list of tags attached to the item. Each tag is a string.

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


### Example

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
