--[[

# LexAPI

An API dump file is created when a Roblox executable is run using the
following options:

    RobloxPlayer -API api.txt
    RobloxPlayerBeta --API api.txt

These dump the API to a file named `api.txt`.

The purpose of this module is to parse the contents of the dump file to a Lua
table, so that it may be manipulated more easily.


## Usage

The LexAPI function expects a string, which is the contents of the dump
file. It returns a table containing the parsed data. Here's an example:

	local LexAPI = require 'LexAPI'

	local f = io.open('api.txt')
	local data = f:read('*a')
	f:close()

	local database = LexAPI(data)

## More Info

https://github.com/Anaminus/roblox-api-dump

]]

return function(data)
	local i = 1

	-- display elaborate error message with exact location of the error
	local function lnerror(msg,lvl)
		-- find start of line
		local a = i
		while true do
			a = a - 1
			if a == 0 or data:sub(a,a) == '\n' or data:sub(a-1,a) == '\r\n' then
				a = a + 1
				break
			end
		end

		-- find end of line
		local b = i
		while true do
			if data:sub(b-1,b) == '\r\n' then
				b = b - 2
				break
			end
			if b == #data+1
			or data:sub(b,b+1) == '\r\n'
			or data:sub(b,b) == '\n'then
				b = b - 1
				break
			end
			b = b + 1
		end

		-- find line number (row)
		local r = 1 do
			local n = i
			while true do
				n = n - 1
				if data:sub(n,n) == '\n' then
					r = r + 1
					local q = n - 1
					if data:sub(q,q) == '\r' then
						n = q
					end
				end
				if n <= 0 then
					break
				end
			end
		end

		-- get line and convert tabs to spaces
		local ln = data:sub(a,b):gsub('\t'," ")
		-- column
		local c = i - a + 1
		-- display exact character where error occurred
		local pt = string.rep(" ",c - 1) .. "^"
		error(msg .. ":" .. r .. ":" .. c .. ":\n" .. ln .. "\n" .. pt,(lvl or 1) + 1)
	end

	local function lnassert(c,msg,lvl)
		if not c then
			lnerror(msg,lvl+1)
		end
		return c
	end

	-- compares the current position with `s`
	local function is(s)
		return data:sub(i,i+#s-1) == s
	end

	-- expect `s` at the current location; errors if it isn't
	local function expect(s,lvl)
		local c = data:sub(i,i+#s-1) == s
		if not c then
			lnerror("`" .. s .. "` expected",lvl+1)
		end
		i = i + #s
	end

	-- skips over whitespace (excluding lines)
	local whiteChars = {[' ']=true,['\t']=true}
	local function white()
		while whiteChars[data:sub(i,i)] do i = i + 1 end
	end

	-- a Word may contain letters, numbers and underscores
	local lexWord do
		local wordChars = {
			['0']=true,['1']=true,['2']=true,['3']=true,['4']=true,['5']=true;
			['6']=true,['7']=true,['8']=true,['9']=true,['a']=true,['b']=true;
			['c']=true,['d']=true,['e']=true,['f']=true,['g']=true,['h']=true;
			['i']=true,['j']=true,['k']=true,['l']=true,['m']=true,['n']=true;
			['o']=true,['p']=true,['q']=true,['r']=true,['s']=true,['t']=true;
			['u']=true,['v']=true,['w']=true,['x']=true,['y']=true,['z']=true;
			['A']=true,['B']=true,['C']=true,['D']=true,['E']=true,['F']=true;
			['G']=true,['H']=true,['I']=true,['J']=true,['K']=true,['L']=true;
			['M']=true,['N']=true,['O']=true,['P']=true,['Q']=true,['R']=true;
			['S']=true,['T']=true,['U']=true,['V']=true,['W']=true,['X']=true;
			['Y']=true,['Z']=true,['_']=true;
		}
		function lexWord()
			local s = i
			while wordChars[data:sub(i,i)] do
				i = i + 1
			end
			if i > s then
				return data:sub(s,i-1)
			else
				return nil
			end
		end
	end

	-- an Int may contain digits 0-9
	local lexInt do
		local digitChars = {
			['0']=true,['1']=true,['2']=true,['3']=true,['4']=true;
			['5']=true,['6']=true,['7']=true,['8']=true,['9']=true;
		}
		function lexInt()
			local s = i
			while digitChars[data:sub(i,i)] do
				i = i + 1
			end
			if i > s then
				return data:sub(s,i-1)
			else
				return nil
			end
		end
	end

	-- Class and member names appear to be unrestricted with the characters
	-- they may contain. So, in order to remain flexible, we'll try to match
	-- the largest feasible occurrence.
	--
	-- Names may contain spaces, but it is not likely they will appear at the
	-- beginning or end of the name, so we'll also trim any trailing
	-- whitespace. Leading whitespace has already been eaten.
	local lexName do
		local char = {['[']=true,['(']=true,[':']=true,['.']=true,['\n']=true,['\r']=true}
		function lexName()
			local s = i
			local n = i
			while not char[data:sub(i,i)] do
				if not whiteChars[data:sub(i,i)] then
					n = i
				end
				i = i + 1
			end
			if i > s then
				return data:sub(s,n)
			else
				return nil
			end
		end
	end

	-- So far, type names appear to be more tame when it comes to characters,
	-- so we'll just treat them as words.
	local function lexType()
		return lexWord()
	end

	-- The exact formatting of default values appears to be undefined, so
	-- we'll try to find as much as possible.
	local function lexDefault()
		local s = i
		while not is',' and not is')' do
			i = i + 1
		end
		-- should not return nil; if blank, the value is probably an empty
		-- string
		return data:sub(s,i-1)
	end

	-- A single argument consists of a type, a name, and a default value,
	-- optionally.
	local function parseArgument(hasDefault)
		local argument = {}
		argument.Type = lnassert(lexType(),"argument type expected",6)
		white()
		argument.Name = lnassert(lexWord(),"argument name expected",6)
		if hasDefault then
			white()
			if is'=' then
				i = i + 1
				white()
				argument.Default = lexDefault()
			end
		end
		return argument
	end

	-- A list of arguments consists of 0 or more comma-separated arguments
	-- enclosed in parentheses.
	local function parseArguments(hasDefault)
		expect('(',5)
		local arguments = {}
		if is')' then
			i = i + 1
		else
			white()
			arguments[#arguments+1] = parseArgument(hasDefault)
			while is',' do
				i = i + 1
				white()
				arguments[#arguments+1] = parseArgument(hasDefault)
			end
			expect(')',5)
		end
		return arguments
	end

	-- Tags are 0 or more bracket-delimited strings that appear after an item.
	local function parseTags()
		local tags = {}
		local s = i
		local open = false
		while not is'\n' and not is'\r\n' do
			if is'[' then
				lnassert(not open,"unexpected tag opener",4)
				open = true
				i = i + 1
				s = i
			elseif is']' then
				lnassert(open,"unexpected tag closer",4)
				open = false
				tags[data:sub(s,i-1)] = true
				i = i + 1
				white()
			elseif i > #data then
				break
			elseif not open then
				lnerror("unexpected character between tags",4)
			else
				i = i + 1
			end
		end
		if open then
			lnerror("tag closer expected",4)
		end
		return tags
	end

	local itemTypes = {
		['Class'] = function()
			local item = {}
			item.Name = lnassert(lexName(),"class name expected",4)
			if is':' then
				i = i + 1
				white()
				item.Superclass = lnassert(lexName(),"superclass name expected",4)
			end
			return item
		end;
		['Property'] = function()
			local item = {}
			item.ValueType = lnassert(lexType(),"type expected",4)
			white()
			item.Class = lnassert(lexName(),"class name expected",4)
			expect('.',4)
			item.Name = lnassert(lexName(),"property name expected",4)
			return item
		end;
		['Function'] = function()
			local item = {}
			item.ReturnType = lnassert(lexType(),"type expected",4)
			white()
			item.Class = lnassert(lexName(),"class name expected",4)
			expect(':',4)
			item.Name = lnassert(lexName(),"function name expected",4)
			item.Arguments = parseArguments(true)
			return item
		end;
		['YieldFunction'] = function()
			local item = {}
			item.ReturnType = lnassert(lexType(),"type expected",4)
			white()
			item.Class = lnassert(lexName(),"class name expected",4)
			expect(':',4)
			item.Name = lnassert(lexName(),"yieldfunction name expected",4)
			item.Arguments = parseArguments(true)
			return item
		end;
		['Event'] = function()
			local item = {}
			item.Class = lnassert(lexName(),"class name expected",4)
			expect('.',4)
			item.Name = lnassert(lexName(),"event name expected",4)
			item.Arguments = parseArguments(false)
			return item
		end;
		['Callback'] = function()
			local item = {}
			item.ReturnType = lnassert(lexType(),"type expected",4)
			white()
			item.Class = lnassert(lexName(),"class name expected",4)
			expect('.',4)
			item.Name = lnassert(lexName(),"callback name expected",4)
			item.Arguments = parseArguments(false)
			return item
		end;
		['Enum'] = function()
			local item = {}
			item.Name = lnassert(lexName(),"enum name expected",4)
			return item
		end;
		['EnumItem'] = function()
			local item = {}
			item.Enum = lnassert(lexName(),"enum name expected",4)
			expect('.',4)
			item.Name = lnassert(lexName(),"enum item name expected",4)
			expect(':',4)
			white()
			item.Value = lnassert(tonumber(lexInt()),"enum value (int) expected",4)
			return item
		end;
	}

	-- An item consists of one line of API data. The contents and formatting
	-- of the item depend on the item's type.
	local function parseItem()
		local type = lnassert(lexWord(),"item type expected",3)
		white()
		lnassert(itemTypes[type],"unknown item type `" .. type .. "`",3)
		local item = itemTypes[type]()
		white()
		item.type = type
		item.tags = parseTags(item)

		-- skip over any lines
		while true do
			if is'\n' then
				i = i + 1
			elseif is'\r\n' then
				i = i + 2
			else
				break
			end
		end

		white()
		return item
	end

	-- Items is a list of all of the items parsed from the whole API dump
	-- string.
	local items = {}
	white()
	items[#items+1] = parseItem()
	while i <= #data do
		white()
		items[#items+1] = parseItem()
	end
	if i <= #data then
		lnerror("unexpected character",2)
	end
	return items
end
