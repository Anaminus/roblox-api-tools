--[[

Return a table of properties and their value types, per class.

{
	ClassName = {
		PropertyName = ValueType
		...
	}
	...
}

]]

local function getProperties(path)
	local dump do
		local f = io.open(path)
		dump = require 'ParseAPI' (f:read('*a'))
		f:close()
	end
	local propertySet = {}
	for i = 1,#dump do
		local item = dump[i]
		if item.type == 'Property'
		and not item.tags.readonly
		and not item.tags.hidden
		and not item.tags.deprecated
		then
			local class = propertySet[item.Class]
			if not class then
				class = {}
				propertySet[item.Class] = class
			end
			class[item.Name] = item.ValueType
		end
	end
	return propertySet
end

for class,properties in pairs(getProperties('api.txt')) do
	print(class)
	for name,type in pairs(properties) do
		print(string.format('\t%-35s = %s',name,type))
	end
end
