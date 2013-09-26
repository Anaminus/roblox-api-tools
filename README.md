## Roblox API Dump

An API dump file is created when a Roblox executable is run using the
following options:

    RobloxPlayer -API api.txt
    RobloxPlayerBeta --API api.txt

These dump the API to a file named `api.txt`. Note that Studio does not 
currently support this command. However, the ReflectionMetadata.xml file is 
required to generate the dump (otherwise a parsing error is reported), but is 
currently only distributed with studio and needs to be copied to 
RobloxPlayerBeta.exe's folder.

This repo contains Lua functions for parsing the contents of the dump into a
Lua table, so that it may be manipulated more easily.

The first function, ParseAPI, uses regular expressions for parsing. It is
small and fast, but will crash and burn if the contents of the dump are
malformed. It is pretty much safe to use on an unmodified dump file taken
directly from the Roblox exe.

In comparison, the second function, LexAPI, is larger and slower, but
significantly more accurate. If the dump is malformed in any way, this
function will tell you the exact location of the error, down to the character.
Use this if you're making modifications to the dump file, and need to verify
that it is correct.

### Usage

Both functions expect a string, which is the contents of the dump file. They
both return a table containing the parsed data, in the exact same format.
Here's an example:

    local ParseAPI = require 'ParseAPI'

    local f = io.open('api.txt')
    local data = f:read('*a')
    f:close()

    local database = ParseAPI(data)


### Table Contents

The returned table is a list of "items", which are tables. All items contain
the following fields:

- *string* **type**: The type of item. Used to indicate what other fields are available in the item.
- *table* **tags**:  A set of tags attached to the item. Each entry is a `["tagname"]=true` pair.

Each item has a specific type with its own additional fields:

- **Class**
	- *string* **Name**:         The name of the class.
	- *string* **Superclass**:   The class this class inherits from. Will be nil if the class does not inherit.
- **Property**
	- *string* **Name**:         The name of the member.
	- *string* **Class** :       The class this item is a member of.
	- *string* **ValueType**:    The type of the property's value.
- **Function**
	- *string* **Name**:         The name of the member.
	- *string* **Class**:        The class this item is a member of.
	- *string* **ReturnType**:   The type of the value returned by the function.
	- *table* **Arguments**:     A list of arguments passed to the function. Each argument is a table containing the following fields:
		- *string* **Name**:     The name of the argument.
		- *string* **Type**:     The value type of the argument.
		- *string* **Default**:  The default value if the argument is not given. Will be nil if the argument does not have default value.
- **Event**
	- *string* **Name**:         The name of the member.
	- *string* **Class**:        The class this item is a member of.
	- *table* **Parameters**:    A list of parameters received by the event listener. Each parameter is a table containing the following fields:
		- *string* **Name**:     The name of the parameter.
		- *string* **Type**:     The value type of the parameter.
- **Callback**
	- *string* **Name**:         The name of the member.
	- *string* **Class**:        The class this item is a member of.
	- *string* **ReturnType**:   The type of the value that should be returned by the callback.
	- *table* **Parameters**:    A list of parameters received by the callback. Each parameter is a table containing the following fields:
		- *string* **Name**:     The name of the parameter.
		- *string* **Type**:     The value type of the parameter.
- **YieldFunction**
	- *string* **Name**:         The name of the member.
	- *string* **Class**:        The class this item is a member of.
	- *string* **ReturnType**:   The type of the value returned by the function.
	- *table* **Arguments**:     A list of arguments passed to the function. Each argument is a table containing the following fields:
		- *string* **Name**:     The name of the argument.
		- *string* **Type**:     The value type of the argument.
		- *string* **Default**:  The default value if the argument is not given. Will be nil if the argument does not have default value.
- **Enum**
	- *string* **Name**:         The name of the enum.
- **EnumItem**
	- *string* **Enum**:         The enum this item is a member of.
	- *string* **Name**:         The name associated with the enum item.
	- *int* **Value**:           The enum item's integer value.


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
    		tags = {readonly = true, RobloxPlaceSecurity = true};
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
