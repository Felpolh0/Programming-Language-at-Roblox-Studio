local Lex = require(script.Lexer)
local Parse = require(script.Parser)
local Interpret = require(script.Interpreter)

local Console = require(script.Parent.Parent.Console.Console)

return function(Code: string, Parameters: {}) -- Extra arguments will be passed to the code.
	Console.Clear()
	Console.SendReminder("Program started", " - LANGUAGE")
	Console.SendReminder("Processing tokens...", " - LANGUAGE")
	
	local Start = os.clock()
	local Tokens, Error = Lex(Code.. " ")
	local Lexing = os.clock() - Start
	
	if table.find(Parameters, "-l") then
		print(Tokens)
	end
	
	if Error then Console.Clear() Console.SendError(Error, " - Lexer") return end
	
	Console.SendReminder("Tokens processed!.", " - LANGUAGE")
	Console.SendReminder("Parsing tokens...", " - LANGUAGE")
	
	local Start = os.clock()
	local Cleaned, Error = Parse(Tokens)
	local Parsing = os.clock() - Start
	
	if table.find(Parameters, "-p") then
		print(Cleaned)
	end
	
	if Error then Console.Clear() Console.SendError(Error, " - Parser") return end
	
	Console.Clear()
	
	local Start = os.clock()
	local C, M = Interpret(Cleaned)
	local Interpreting = os.clock() - Start
	
	
	if table.find(Parameters, "-m") then
		print(M)
	end


  -- Console benchmark output
	Console.NewLine()
	Console.NewLine()
	Console.NewLine()
	
	Console.SendReminder("Benchmarking:")
	Console.SendReminder(string.format("Lexer: %sms | %ss", Lexing * 1000, Lexing))
	Console.SendReminder(string.format("Parser: %sms | %ss", Parsing * 1000, Parsing))
	Console.SendReminder(string.format("Interpreter: %sms | %ss", Interpreting * 1000, Interpreting))
end
