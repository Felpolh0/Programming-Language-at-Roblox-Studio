--[[

    Interprets the parsed code. Here is where the stuff actually happens.

]]

local Stack = 0
local MaxStack = 1000 -- For security reasons


local Console = require(script.Parent.Parent.Parent.Console.Console)



local Memory = require(script.BaseMemory)

local Interpreter = {
	Error = nil,
}


local function Test(OP: {})
	local Result = true
	if OP.Type == "BOOL" and OP.Value == "false" then
		Result = false
	end

	if OP.Type == "IDENTIFIER" then
		local Value = Memory[OP.Value]
		if not Value then
			Interpreter.Error = string.format('Unknown global "%s"', OP.Value)
			return
		end

		if Value == "BOOL" and Value == "false" then
			Result = false
		end
	end
	
	return Result
end

local function tobinary( number )
	local str = ""
	if number == 0 then
		return 0
	elseif number < 0 then
		number = - number
		str = "-"
	end
	local power = 0
	while true do
		if 2^power > number then break end
		power = power + 1
	end
	local dot = true
	while true do
		power = power - 1
		if dot and power < 0 then
			str = str .. "."
			dot = false
		end
		if 2^power <= number then
			number = number - 2^power
			str = str .. "1"
		else
			str = str .. "0"
		end
		if number == 0 and power < 1 then break end
	end
	return str
end

local FalseValue = Test({Type = "BOOL", Value = "false"})



local Operators = {
	["+"] = function(N1, N2)
		return N1 + N2
	end,
	
	["-"] = function(N1, N2)
		return N1 - N2
	end,
	
	["*"] = function(N1, N2)
		return N1 * N2
	end,
	
	["/"] = function(N1, N2)
		return N1 / N2
	end,
	
	["^"] = function(N1, N2)
		return math.pow(N1, N2)
	end,
	
	[">>"] = function(N1, N2)
		return bit32.rshift(N1, N2)
	end,
	
	["<<"] = function(N1, N2)
		return bit32.lshift(N1, N2)
	end,
}

local Comparators = {
	[">"] = function(N1, N2)
		return N1 > N2
	end,
	
	[">="] = function(N1, N2)
		return N1 >= N2
	end,
	
	["<"] = function(N1, N2)
		return N1 < N2
	end,
	
	["<="] = function(N1, N2)
		return N1 <= N2
	end,
	
	["=="] = function(N1, N2)
		return N1 == N2
	end,
}


local Bin = {
	["print"] = function(Arguments: {})
		--[[
		
			Arguments MUST be strings
            Prints the text at the custom output
		
		]]
		
		if not Arguments then return end
		Arguments["Type"] = nil
		
		local PrintableArguments = {
			["NUMBER"] = true,
			["STRING"] = true,
			["IDENTIFIER"] = true,
			["BOOL"] = true
		}
		
		local FinalText = ""
		local Separated = true
		for _, Argument: {Value: string, Type: string} in pairs(Arguments) do
			if Separated then
				Separated = false
			else
				if Argument.Type ~= "SEP" then
					Interpreter.Error = "Invalid syntax"
					return
				end
				Separated = true
				continue
			end
			
			local Value = Argument.Value
			
			if Argument.Type == "IDENTIFIER" then
				local N = Value
				Value = Memory[Value]
				if not Value then
					Interpreter.Error = string.format('Unknown variable "%s"', N)
					return
				end
			end
			
			if not PrintableArguments[Argument.Type] then
				Interpreter.Error = string.format('%s type cannot be printed', string.format("%s%s", Argument.Type:sub(1, 1):upper(), Argument.Type:sub(2, #Argument.Type):lower()))
				return
			end
			
			FinalText = string.format("%s%s", FinalText, tostring(Value))
		end
		
		Console.SendMessage(FinalText, " - Interpreter")
	end,
	
	["printTerminal"] = function(Arguments: {})
		--[[
		
			Arguments MUST be strings
            Prints the text at the roblox's terminal using the built-in print function
		
		]]

		if not Arguments then return end
		Arguments["Type"] = nil

		local PrintableArguments = {
			["NUMBER"] = true,
			["STRING"] = true,
			["IDENTIFIER"] = true,
			["BOOL"] = true
		}

		local FinalText = ""
		local Separated = true
		for _, Argument: {Value: string, Type: string} in pairs(Arguments) do
			if Separated then
				Separated = false
			else
				if Argument.Type ~= "SEP" then
					Interpreter.Error = "Invalid syntax"
					return
				end
				Separated = true
				continue
			end

			local Value = Argument.Value

			if Argument.Type == "IDENTIFIER" then
				local N = Value
				Value = Memory[Value]
				if not Value then
					Interpreter.Error = string.format('Unknown variable "%s"', N)
					return
				end
			end

			--if not PrintableArguments[Argument.Type] then
			--	Interpreter.Error = string.format('%s type can not be printed', string.format("%s%s", Argument.Type:sub(1, 1):upper(), Argument.Type:sub(2, #Argument.Type):lower()))
			--	return
			--end

			FinalText = string.format("%s%s", FinalText, tostring(Value))
		end

		print(FinalText)
	end,
	
	["binary"] = function(Arguments: {})
		--[[
			Uses 1 argument that needs to be a number and returns it's bit representation
		]]
		
		if not Arguments then return end
		Arguments["Type"] = nil
		
		return {
			Type = "NUMBER",
			Value = tobinary(Arguments[1].Value)
		}
	end,
	
	["typeof"] = function(Arguments: {})
        --[[
            Returns the type ( or token type ) of the given variable
        ]]
        
		if not Arguments then return end
		Arguments["Type"] = nil

		return { -- Returns a string token with the variable's type
			Type = "STRING",
			Value = Arguments[1].Type:lower()
		}
	end,
}


local OPs = {}

function OPs:BinaryOperation(OP: {})
	local Left = OP.Left
	local Right = OP.Right

	if Left.Type == "BinaryOperation" then
		Left = OPs:BinaryOperation(Left)
	elseif Left.Type == "IDENTIFIER" then
		local Name = Left.Value
		Left = Memory[Name]
		if not Left then
			Interpreter.Error = string.format('Unknown variable "%s"', Name)
			return
		end
	end
	
	if Right.Type == "BinaryOperation" then
		Right = OPs:BinaryOperation(Right)
	elseif Right.Type == "IDENTIFIER" then
		local Name = Right.Value
		Right = Memory[Name]
		if not Right then
			Interpreter.Error = string.format('Unknown variable "%s"', Name)
			return
		end
	end
	
	local Result = Operators[OP.Operator](Left.Value, Right.Value)
	return {
		Type = "NUMBER",
		Value = Result
	}
end

function OPs:WriteToMemory(OP: {})
	local Value = Interpreter:Run({OP.Value})[1]
	Memory[OP.Slot] = Value
end

function OPs:Call(OP: {})
	if Bin[OP.CallName] then
		return Bin[OP.CallName](Interpreter:Run(OP.Passed))
	end
	
	if not Memory[OP.CallName] then
		Interpreter.Error = 'Attempt to call a nil value'
		return
	end
	
	if typeof(Memory[OP.CallName]) == "function" then
		return Memory[OP.CallName](Interpreter:Run(OP.Passed))
	end
	
	if Memory[OP.CallName].Type ~= "FUNCTION" then
		Interpreter.Error = string.format('Attempt to call a %s value', Memory[OP.CallName].Type:lower())
		return
	end
	
	--> Assigning arguments
	local Arguments = Memory[OP.CallName].Arguments
	local Body = Memory[OP.CallName].Body
	
	Interpreter:Run(OP.Passed) --> Gets values for identifiers
	
	local BeforeValues = {}
	for i, Argument in pairs(Arguments) do
		if i > #OP.Passed then break end
		if Memory[Argument.Value] then BeforeValues[Argument.Value] = Memory[Argument.Value] end
		Memory[Argument.Value] = OP.Passed[i]
	end
	
	local Cache = Interpreter:Run(Body) --> Runs function
	
	--> Unassigning arguments
	for _, Argument in pairs(Arguments) do
		if BeforeValues[Argument.Value] then Memory[Argument.Value] = BeforeValues[Argument.Value] continue end
		Memory[Argument.Value] = nil
	end
	
	return nil, nil, Cache
end

function OPs:IDENTIFIER(OP: {})
	if not Memory[OP.Value] then
		Interpreter.Error = "Incomplete statement: expected assignment or a function call"
		return
	end
	
	local V = Memory[OP.Value]
	if OP.Indexed then
		if V.Type ~= "Table" then Interpreter.Error = "Can only index tables" return end
		local Flow = OP.IndexFlow
		local Current = Memory[OP.Value]

		for _, Index: {Type: string, Value: any} in pairs(Flow) do
			if Current.Type ~= "Table" then return FalseValue end
			if Current.Values[Index.Value] then
				Current = Current.Values[Index.Value]
				continue
			end

			return FalseValue
		end
		
		V = Current
	end
	
	return V
end

function OPs:Comparison(OP: {})
	local Left = OP.Left
	local Right = OP.Right

	if Left.Type == "BinaryOperation" then
		Left = OPs:BinaryOperation(Left)
	elseif Left.Type == "IDENTIFIER" then
		local Name = Left.Value
		Left = Memory[Name]
		if not Left then
			Interpreter.Error = string.format('Unknown variable "%s"', Name)
			return
		end
	end

	if Right.Type == "BinaryOperation" then
		Right = OPs:BinaryOperation(Right)
	elseif Right.Type == "IDENTIFIER" then
		local Name = Right.Value
		Right = Memory[Name]
		if not Right then
			Interpreter.Error = string.format('Unknown variable "%s"', Name)
			return
		end
	end
	
	local Result = Comparators[OP.Comparator](Left.Value, Right.Value)
	
	if Result then
		return {
			Type = "BOOL",
			Value = "true"
		}, OP.True - 1
	end
	return {
		Type = "BOOL",
		Value = "false"
	}, OP.False - 1
end

function OPs:TestValue(OP: {})
	local Result = true
	if OP.TestValue.Type == "BOOL" and OP.TestValue.Value == "false" then
		Result = false
	end
	
	if OP.TestValue.Type == "IDENTIFIER" then
		local Value = Memory[OP.TestValue.Value]
		if not Value then
			Interpreter.Error = string.format('Unknown global "%s"', OP.TestValue.Value)
			return
		end
		
		if Value == "BOOL" and Value == "false" then
			Result = false
		end
	end

	if Result then
		return {
			Type = "BOOL",
			Value = "true"
		}, OP.True - 1
	end
	return {
		Type = "BOOL",
		Value = "false"
	}, OP.False - 1
end

function OPs:Pool(OP: {})
	OP.Type = nil
	return Interpreter:Run(OP)
end

function OPs:CreateFunction(Pool: {})
	local Name = Pool[1].CallName
	
	local Arguments = {}
	for i = 1, #Pool[1].Passed do
		if Pool[1].Passed[i].Type ~= "IDENTIFIER" then
			Interpreter.Error = 'Expected identifier when parsing variable name'
			return
		end
		table.insert(Arguments, Pool[1].Passed[i])
	end
	
	table.remove(Pool, 1)
	table.remove(Pool, #Pool)
	Pool.Key = nil
	Pool.Type = nil
	
	--> Adding function to memory
	local Function = {
		Type = "FUNCTION",
		Arguments = Arguments,
		Body = Pool
	}
	
	Memory[Name] = Function
end

function OPs:WhileLoop_Single(OP: {})
	local CanStart = Test(OP.Value)
	
	if CanStart then
		local Halted = false
		
		OP.Body.Type = nil
		OP.Body.Key = nil
		
		repeat
			OPs:Pool(OP.Body)
			
			if not Test(OP.Value) then Halted = true end
		until Halted
	end
	
	return nil, 1
end

--[[

	var A = 1

	while A < 5 do
		print(A)
		A += 1
		
		printTerminal("Looped!   Value: ", A)
	end

]]

function OPs:WhileLoop(OP: {})
	local CanStart = OPs:Comparison(OP.Value)
	CanStart = Test(CanStart)

	if CanStart then
		local Halted = false
		
		OP.Body.Type = nil
		OP.Body.Key = nil

		repeat
			OPs:Pool(OP.Body)

			local T = OPs:Comparison(OP.Value)
			T = Test(T)
			
			if not T then Halted = true break end
		until Halted
	end

	return nil, 1
end


function OPs:Table(OP: {}, Last: {})
	if not OP.Indexed then return end
	
	local Flow = OP.IndexFlow
	local Current = OP
	
	for _, Index: {Type: string, Value: any} in pairs(Flow) do
		if Current.Type ~= "Table" then return FalseValue end
		if Current.Values[Index.Value] then
			Current = Current.Values[Index.Value]
			continue
		end
		
		return FalseValue
	end
	
	return Current
end


function OPs:IndexedCall(OP: {})
	local Flow = OP.CallSlot.IndexFlow
	local Current = Memory[OP.CallSlot.Value]

	for _, Index: {Type: string, Value: any} in pairs(Flow) do
		--if Current.Type ~= "Table" then return FalseValue end
		if Current.Values[Index.Value] then
			Current = Current.Values[Index.Value]
			continue
		end

		return FalseValue
	end
	
	if typeof(Current) == "function" then
		return Current(Interpreter:Run(OP.Passed))
	end
	
	--> Assigning arguments
	local Arguments = Current.Arguments
	local Body = Current.Body

	Interpreter:Run(OP.Passed) --> Gets values for identifiers

	local BeforeValues = {}
	for i, Argument in pairs(Arguments) do
		if i > #OP.Passed then break end
		if Memory[Argument.Value] then BeforeValues[Argument.Value] = Memory[Argument.Value] end
		Memory[Argument.Value] = OP.Passed[i]
	end

	Interpreter:Run(Body) --> Runs function

	--> Unassigning arguments
	for _, Argument in pairs(Arguments) do
		if BeforeValues[Argument.Value] then Memory[Argument.Value] = BeforeValues[Argument.Value] continue end
		Memory[Argument.Value] = nil
	end
end


function Interpreter:Run(Cleaned: {})
	Interpreter.Error = nil
	local Index = 1
	local Cache = nil
	
	Stack += 1
	if Stack >= MaxStack then
		Interpreter.Error = "NO_CALL"
		Console.SendError("Stack overflow", " - Interpreter")
		Stack -= 1
		return
	end
	
	
	local Last = nil
	while true do
		if Interpreter.Error then break end
		if Index > #Cleaned then break end
		local Clean = Cleaned[Index]
		
		if Clean.Type == "Return" then
			Cache = Clean.Value
			Index += 1

			continue
		end
		
		if not OPs[Clean.Type] then Index += 1 continue end
		
		--[[
		
			function A()
				A()
			end
		
		]]
		
		if Clean.Type == "Pool" and Clean.Key == "function" then
			OPs:CreateFunction(Clean)
			
			Index += 1
			continue
		end
		
		local Return, IndexSkip, BundledReturn = OPs[Clean.Type](nil, Clean, Last)
		
		if Return then
			Cleaned[Index] = Return
		end
		
		if BundledReturn then
			Cleaned[Index] = BundledReturn
		end
		
		Last = Cleaned[Index]
		
		if IndexSkip and typeof(IndexSkip) == "number" then
			Index += IndexSkip
		end
		
		Index += 1
	end
	
	Stack -= 1
	if Interpreter.Error then
		if Interpreter.Error ~= "NO_CALL" then Console.SendError(Interpreter.Error, " - Interpreter") end
	end
	
	return Cache, Memory
end

return function(Cleaned: {})
	Stack = 0
	Memory = require(script.BaseMemory)
	return Interpreter:Run(Cleaned)
end
