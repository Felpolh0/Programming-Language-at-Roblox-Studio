--[[

	Lexer:
		Separates the source code into tokens
		The tokens returned should be passed to the parser

]]



local Lexer = {
	Index = 0,
	Stream = "",
	Tokens = {},
	Error = nil
}

-------------------------------------------------------
-- Constants
-------------------------------------------------------

local Token_Id = "IDENTIFIER"
local Token_KW = "KEYWORD"
local Token_String = "STRING"
local Token_Number = "NUMBER"
local Token_Boolean = "BOOL"
local Token_OP = "OPERATOR"
local Token_Comparator = "COMPARATOR"
local Token_Connector = "CONNECTOR"
local Token_AutoOperator = "AUTO_OPERATOR"
local Token_Comment = "COMMENT"
local Token_Sep = "SEP"

local Operators = { --> For fast search-up
	["="] = true,
	["+"] = true,
	["-"] = true,
	["/"] = true,
	["*"] = true,
	["^"] = true,
	[">>"] = true,
	["<<"] = true
}

local Comparators = {
	[">"] = true,
	["<"] = true,
	
	[">="] = true,
	["<="] = true,
	
	["!"] = true, --> So "!=" works.
	["!="] = true,
	
	["=="] = true,
}

local Booleans = {
	["true"] = true,
	["false"] = true
}

local Keywords = require(script.Parent.Keywords)



-------------------------------------------------------
-- Helping functions
-------------------------------------------------------
local function TableToDict(Table: {}, Placeholder: any)
	local Dict = {}
	for _, V in pairs(Table) do
		Dict[V] = Placeholder or 1
	end
	return Dict
end



-------------------------------------------------------
-- Lexer
-------------------------------------------------------

function Lexer:Reset()
	self.Index = 0
	self.Stream = ""
	self.Tokens = {}
end

function Lexer:Next(): string
	self.Index += 1
	return self.Stream:sub(self.Index, self.Index)
end

function Lexer:Jump(N: number)
	self.Index = N
	return self.Stream:sub(self.Index, self.Index)
end

function Lexer:Find(Key: string, Init: number): string
	local Current = Init or 1
	
	while true do
		if Current == #self.Stream then break end
		if self:Peek(Current) == Key then return Current end
		Current += 1
	end
end

function Lexer:Peek(N: number): string
	N = N or self.Index
	return self.Stream:sub(N, N)
end

function Lexer:Process(Key: string, Index: number)
	if Key == "" then return end
	local First = Key:sub(1, 1)
	
	
	--------------- SEPARATOR
	if Key == "," then
		return self:CreateToken(Token_Sep)
	end


	--------------- CONNECTOR
	if Key == "." then
		return self:CreateToken(Token_Connector)
	end
	
	
	--------------- BOOLS
	if Booleans[Key] then
		return self:CreateToken(Token_Boolean, Key)
	end
	
	
	--------------- KEYWORD
	if Keywords[Key] then
		return self:CreateToken(Token_KW, Key)
	end
	
	
	--------------- STRING
	if First == '"' or First == "'" then
		local End = Key:sub(#Key, #Key)
		if End ~= First then
			self.Error = string.format('Expected %s at index %s ( %s )', First, Index, Key)
			return
		end
		
		return {
			Type = Token_String,
			Value = Key:sub(2, #Key - 1),
			Entry = First
		}
	end
	
	
	--------------- NUMBER
	if tonumber(First) then
		if not tonumber(Key) then
			self.Error = "Malformed number"
			return
		end
		
		return self:CreateToken(Token_Number, tonumber(Key))
	end
	
	
	--------------- OPERATOR
	if Operators[Key] then
		return self:CreateToken(Token_OP, Key)
	end
	
	
	--------------- COMPARATOR
	if Comparators[Key] then
		return self:CreateToken(Token_Comparator, Key)
	end
	
	
	--------------- VAR
	if not tonumber(First) then
		return self:CreateToken(Token_Id, Key)
	end
end

function Lexer:CreateToken(Type: string, Value: any) --> Creates token but does not add it to self.Tokens
	local Token = {
		Type = Type,
		Value = Value
	}

	return Token
end

function Lexer:Pool(Parent: {}, Key: string)
	local Pool = {
		Type = "Pool",
		Key = Key
	}
	
	table.insert(Parent, Pool)
	return #Parent
end

function Lexer:Pack(i: number, j: number): string
	return self.Stream:sub(i, j)
end




function Lexer:Run(Code: string, RegisterSpaces: boolean, RegisterLineBreaks: boolean): ({}, string)
	Lexer:Reset()
	Lexer.Stream = Code
	
	local TXT = ""
	local Pools = {}
	
	local PoolCreators = {
		["("] = ")",
		["["] = "]",
		["{"] = "}",
		
		["then"] = "end",
		["do"] = "end",
		["function"] = "end"
	}
	
	local function CreatePool(Key: string, EnclosureKey: string, Parent: {})
		if not Pools[EnclosureKey] then Pools[EnclosureKey] = {} end
		
		local Index = self:Pool(Parent, Key)
		local IsString = false
		
		while true do
			if Lexer.Error then break end
			if Lexer.Index >= #Lexer.Stream then break end
			
			local Next = Lexer:Next()

			if Next == EnclosureKey then
				local Token = Lexer:Process(TXT, Lexer.Index)
				table.insert(Parent[Index], Token)
				TXT = ""
				break
			end

			if TXT == EnclosureKey then
				local Token = Lexer:Process(TXT, Lexer.Index)
				table.insert(Parent[Index], Token)
				TXT = ""
				break
			end

			if Next == '"' or Next == "'" then
				if IsString then --> String finished
					local Token = Lexer:Process(string.format("%s%s%s", Next, TXT, Next), Lexer.Index)
					table.insert(Parent[Index], Token)
					TXT = ""
				end

				IsString = not IsString
				continue
			end

			if PoolCreators[TXT] and not IsString then --> Big ones
				local EnclosureKey = PoolCreators[TXT]
				local Key = TXT
				TXT = ""

				CreatePool(Key, EnclosureKey, Parent[Index])
				continue
			end

			if PoolCreators[Next] and not IsString then --> Small ones
				local Token = Lexer:Process(TXT, Lexer.Index)
				table.insert(Parent[Index], Token)
				TXT = ""

				CreatePool(Next, PoolCreators[Next], Parent[Index])
				continue
			end

			if Operators[Next] and not Comparators[TXT] and not IsString then
				if Next == "=" and Lexer:Peek(Lexer.Index + 1) == "=" then --> Comparator "=="
					local Token = Lexer:Process(TXT, Lexer.Index)
					table.insert(Parent[Index], Token)
					TXT = ""

					local Token = Lexer:Process("==", Lexer.Index)
					table.insert(Parent[Index], Token)

					Lexer:Next()
					continue
				end

				if Operators[Lexer:Peek(Lexer.Index + 1)] then --> "+=" "-=" "/=" "*="
					local Token = Lexer:Process(TXT, Lexer.Index)
					table.insert(Parent[Index], Token)
					TXT = ""

					local Token = Lexer:CreateToken(Token_AutoOperator, string.format("%s%s", Next, "="))
					table.insert(Parent[Index], Token)
					TXT = ""

					Lexer:Next()
					continue
				end

				local Token = Lexer:Process(TXT, Lexer.Index)
				table.insert(Parent[Index], Token)
				TXT = ""

				local Token = Lexer:Process(Next, Lexer.Index)
				table.insert(Parent[Index], Token)

				continue
			end

			if Comparators[Next] and not IsString then
				local Comparator = Next

				local Jumbled = string.format("%s%s", Comparator, Lexer:Peek(Lexer.Index + 1) or "")
				if Comparators[Jumbled] then
					Comparator = Jumbled
					Lexer:Jump(Lexer.Index + 2)
				end

				if Operators[Jumbled] then
					local Token = Lexer:Process(TXT, Lexer.Index)
					table.insert(Parent[Index], Token)
					TXT = ""

					local Token = Lexer:CreateToken(Token_OP, Jumbled)
					table.insert(Parent[Index], Token)

					Lexer:Jump(Lexer.Index + 2)
					continue
				end

				if Comparator == "!" then
					Lexer.Error = '"!" is not a valid operator'
					break
				end

				local Token = Lexer:Process(TXT, Lexer.Index)
				table.insert(Parent[Index], Token)
				TXT = ""

				local Token = Lexer:Process(Comparator, Lexer.Index)
				table.insert(Parent[Index], Token)

				continue
			end
			
			if Next == "." and not IsString and not tonumber(TXT) then
				local Token = Lexer:Process(TXT, Lexer.Index)
				table.insert(Parent[Index], Token)
				TXT = ""

				local Token = Lexer:Process(Next, Lexer.Index)
				table.insert(Parent[Index], Token)

				continue
			end

			if Next == "," and not IsString then
				local Token = Lexer:Process(TXT, Lexer.Index)
				table.insert(Parent[Index], Token)
				TXT = ""

				local Token = Lexer:Process(Next, Lexer.Index)
				table.insert(Parent[Index], Token)

				continue
			end

			if Next == " " and not IsString then
				if TXT == "!" then
					Lexer.Error = '"!" is not a valid operator'
					break
				end

				local Token = Lexer:Process(TXT, Lexer.Index)
				table.insert(Parent[Index], Token)
				TXT = ""

				if RegisterSpaces then
					local Token = {
						Type = "SPACE",
						Value = " "
					}
					table.insert(Parent[Index], Token)
				end

				continue
			end

			if Next == "	" and not IsString then
				if TXT == "!" then
					Lexer.Error = '"!" is not a valid operator'
					break
				end

				local Token = Lexer:Process(TXT, Lexer.Index)
				table.insert(Parent[Index], Token)
				TXT = ""

				if RegisterSpaces then
					local Token = {
						Type = "TAB",
						Value = " "
					}
					table.insert(Parent[Index], Token)
				end

				continue
			end

			TXT = string.format("%s%s", TXT, Next)
		end
	end
	
	local IsString = false
	
	while true do
		if Lexer.Error then break end
		if Lexer.Index >= #Lexer.Stream then break end
		
		local Next = Lexer:Next()
		
		if Next == '"' or Next == "'" then
			if IsString then --> String finished
				local Token = Lexer:Process(string.format("%s%s%s", Next, TXT, Next), Lexer.Index)
				table.insert(self.Tokens, Token)
				TXT = ""
			end
			
			IsString = not IsString
			continue
		end
		
		if PoolCreators[TXT] and not IsString then --> Big ones
			local EnclosureKey = PoolCreators[TXT]
			local Key = TXT
			TXT = ""
			
			CreatePool(Key, EnclosureKey, Lexer.Tokens)
			continue
		end
		
		if PoolCreators[Next] and not IsString then --> Small ones
			local Token = Lexer:Process(TXT, Lexer.Index)
			table.insert(self.Tokens, Token)
			TXT = ""

			CreatePool(Next, PoolCreators[Next], Lexer.Tokens)
			continue
		end
		
		if Operators[Next] and not Comparators[TXT] and not IsString then
			if Next == "=" and Lexer:Peek(Lexer.Index + 1) == "=" then --> Comparator "=="
				local Token = Lexer:Process(TXT, Lexer.Index)
				table.insert(self.Tokens, Token)
				TXT = ""
				
				local Token = Lexer:Process("==", Lexer.Index)
				table.insert(self.Tokens, Token)
				
				Lexer:Next()
				continue
			end
			
			if Operators[Lexer:Peek(Lexer.Index + 1)] then --> "+=" "-=" "/=" "*="
				local Token = Lexer:Process(TXT, Lexer.Index)
				table.insert(self.Tokens, Token)
				TXT = ""

				local Token = Lexer:CreateToken(Token_AutoOperator, string.format("%s%s", Next, "="))
				table.insert(self.Tokens, Token)
				TXT = ""

				Lexer:Next()
				continue
			end
			
			local Token = Lexer:Process(TXT, Lexer.Index)
			table.insert(self.Tokens, Token)
			TXT = ""
			
			local Token = Lexer:Process(Next, Lexer.Index)
			table.insert(self.Tokens, Token)
			
			continue
		end
		
		if Comparators[Next] and not IsString then
			local Comparator = Next
			
			local Jumbled = string.format("%s%s", Comparator, Lexer:Peek(Lexer.Index + 1) or "")
			if Comparators[Jumbled] then
				Comparator = Jumbled
				Lexer:Jump(Lexer.Index + 2)
			end
			
			if Operators[Jumbled] then
				local Token = Lexer:Process(TXT, Lexer.Index)
				table.insert(self.Tokens, Token)
				TXT = ""
				
				local Token = Lexer:CreateToken(Token_OP, Jumbled)
				table.insert(self.Tokens, Token)
				
				Lexer:Jump(Lexer.Index + 2)
				continue
			end
			
			if Comparator == "!" then
				Lexer.Error = '"!" is not a valid operator'
				break
			end
			
			local Token = Lexer:Process(TXT, Lexer.Index)
			table.insert(self.Tokens, Token)
			TXT = ""

			local Token = Lexer:Process(Comparator, Lexer.Index)
			table.insert(self.Tokens, Token)
			
			continue
		end
		
		if Next == "," and not IsString then
			local Token = Lexer:Process(TXT, Lexer.Index)
			table.insert(self.Tokens, Token)
			TXT = ""
			
			local Token = Lexer:Process(Next, Lexer.Index)
			table.insert(self.Tokens, Token)

			continue
		end
		
		if Next == "." and not IsString and not tonumber(TXT) then
			local Token = Lexer:Process(TXT, Lexer.Index)
			table.insert(self.Tokens, Token)
			TXT = ""

			local Token = Lexer:Process(Next, Lexer.Index)
			table.insert(self.Tokens, Token)

			continue
		end
		
		if Next == " " and not IsString then
			if TXT == "!" then
				Lexer.Error = '"!" is not a valid operator'
				break
			end
			
			local Token = Lexer:Process(TXT, Lexer.Index)
			table.insert(self.Tokens, Token)
			TXT = ""
			
			if RegisterSpaces then
				local Token = {
					Type = "SPACE",
					Value = " "
				}
				table.insert(self.Tokens, Token)
			end
			
			continue
		end
		
		if Next == "	" and not IsString then
			if TXT == "!" then
				Lexer.Error = '"!" is not a valid operator'
				break
			end

			local Token = Lexer:Process(TXT, Lexer.Index)
			table.insert(self.Tokens, Token)
			TXT = ""

			if RegisterSpaces then
				local Token = {
					Type = "TAB",
					Value = " "
				}
				table.insert(self.Tokens, Token)
			end

			continue
		end
		
		TXT = string.format("%s%s", TXT, Next)
	end
	
	if RegisterSpaces then
		Lexer.Tokens[#Lexer.Tokens] = nil --> Removes last space as it's false
	end
	
	return Lexer.Tokens, Lexer.Error
end













return function(Code: string, RegisterSpaces: boolean, RegisterLineBreaks: boolean)
	return Lexer:Run(Code, RegisterSpaces, RegisterLineBreaks)
end
