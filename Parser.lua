--[[

	Entry point:
		Program

]]


type Token = {
	Type: string,
	Value: any
}

type Pool = {
	Type: string,
	Key: string
}


local OperatorLevels = {
	["+"] = 1,
	["-"] = 1,
	
	["*"] = 2,
	["/"] = 2,
	
	["^"] = 3,
	
	[">>"] = 4
}


local Parser = {}


function Parser:Program(Tokens: {})	
	local P = {
		Index = 0,
		Type = "Program",
		Stream = Tokens,
		Error = nil,
		Body = {}
	}
	
	
	
	--------------------------------------------------------------------------------------------
	-- HELPING FUNCTIONS
	--------------------------------------------------------------------------------------------
	
	
	
	local function Comparator(CMP: string, Left: {}, Right: {})
		local Expression = {
			Type = "Comparison",
			Comparator = CMP,
			
			Left = Left,
			Right = Right,
			
			True = 0,
			False = 0
		}
		
		return Expression
	end
	
	local function TestValue(Value: {})
		local Expression = {
			Type = "TestValue",
			TestValue = Value,

			True = 0,
			False = 0
		}

		return Expression
	end
	
	local function GetValuesUntilPool(PoolKey: string)
		local V1 = {}
		local V2 = {}
		local CMP = {}

		local CMPPos = 0
		local KeyPos = 0

		local Single = false

		for i = P.Index + 1, #P.Stream do
			local Current = P:Peek(i)
			if Current.Type == "COMPARATOR" then
				CMP = Current
				CMPPos = i
				V1 = table.pack(table.unpack(P.Stream, P.Index + 1, i - 1))
				break
			end

			if Current.Type == "Pool" and Current.Key == PoolKey then
				V1 = table.pack(table.unpack(P.Stream, P.Index + 1, i - 1))
				KeyPos = i
				Single = true
				break
			end
		end

		if not Single then
			for i = CMPPos + 1, #P.Stream do
				local Current = P:Peek(i)
				if Current.Type == "Pool" and Current.Key == PoolKey then
					V2 = table.pack(table.unpack(P.Stream, CMPPos + 1, i - 1))
					KeyPos = i
					break
				end
			end

			if not V2 then
				P.Error = "Bolinha2"
				return
			end
		end

		if Single then
			V1 = P:Pool(V1)[1]
			return V1, nil, nil, KeyPos - P.Index - 1
		end

		V1 = P:Pool(V1)
		V2 = P:Pool(V2)

		if #V1 > 1 or #V2 > 1 then
			P.Error = "Invalid values"
			return
		end

		V1 = V1[1]
		V2 = V2[1]

		return V1, V2, CMP, KeyPos - P.Index - 1
	end
	
	
	
	--------------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------
	
	
	
	function P:Next(): Token
		self.Index += 1
		return self.Stream[self.Index]
	end
	
	function P:Back(): Token
		self.Index -= 1
		return self.Stream[self.Index]
	end
	
	function P:Skip(N: number)
		self.Index += N
		return self.Stream[self.Index]
	end
	
	function P:Jump(N: number)
		self.Index = N
		return self.Stream[self.Index]
	end
	
	function P:Peek(N): Token
		return self.Stream[N]
	end
	
	
	
	function P:IDENTIFIER(Token: Token)
		local NextToken = P:Peek(P.Index + 1)
		if not NextToken then
			table.insert(P.Body, Token)
			return
		end
		
		if NextToken.Type == "Pool" and NextToken.Key == "(" then --> Function call
			local Arguments = {}
			for i = 1, #NextToken do
				table.insert(Arguments, NextToken[i])
			end
			
			Arguments = P:Pool(Arguments)
			
			local Expression = {
				Type = "Call",
				CallName = Token.Value,
				Passed = Arguments
			}
			
			table.insert(P.Body, Expression)
			P:Next()
			return
		end
		
		return Token
	end
	
	
	
	function P:STRING(Token: Token)
		table.insert(P.Body, Token)
	end
	
	
	
	function P:NUMBER(Token: Token)
		local NextToken = P:Peek(P.Index + 1)
		if not NextToken then
			table.insert(P.Body, Token)
			return
		end
		
		--if NextToken.Type == "OPERATOR" then
		--	if NextToken.Value == "=" then
		--		P.Error = "Bla1"
		--		return
		--	end
			
		--	--[[
			
		--		Expects:
		--			Number or identifier
			
		--	]]
			
		--	local V2 = P:Peek(P.Index + 2)
			
		--	local Passes = {
		--		["NUMBER"] = true,
		--		["IDENTIFIER"] = true
		--	}
			
		--	if not Passes[V2.Type] then
		--		P.Error = "Bla2"
		--		return
		--	end
			
		--	local Expression = {
		--		Type = "BinaryOperation",
		--		Operator = NextToken.Value,
				
		--		Left = Token,
		--		Right = V2,
		--	}
			
		--	table.insert(P.Body, Expression)
		--	P:Skip(2)
		--	return
		--end
		
		table.insert(P.Body, Token)
	end
	
	
	function P:AUTO_OPERATOR(Token: Token)
		--[[
		
			LastExpression must be an IDENTIFIER
		
		]]
		
		local LastExpression = P.Body[#P.Body]
		if LastExpression.Type ~= "IDENTIFIER" then
			P.Error = string.format('Expected identifier when parsing expression, got "%s"', LastExpression.Value)
			return
		end
		
		
		local Pass = {
			["NUMBER"] = true,
			["OPERATOR"] = true,
			["IDENTIFIER"] = true
		}

		local End = 0

		local Current = P.Index + 1
		while true do
			if Current > #P.Stream then
				End = #P.Stream + 1
				break
			end
			local C = P:Peek(Current)
			if C.Type == "IDENTIFIER" then
				local Next = P:Peek(Current + 1)
				if Next.Type == "Pool" and Next.Key == "(" then End = Current break end
			end
			if not Pass[C.Type] then End = Current break end
			Current += 1
		end
		
		local V = table.pack(table.unpack(P.Stream, P.Index + 1, End - 1))
		V.n = nil

		V = P:Pool(V)
		V = V[1]
		
		V = {
			Type = "BinaryOperation",
			Operator = Token.Value:sub(1, 1),
			
			Left = LastExpression,
			Right = V
		}
		
		local Expression = {
			Type = "WriteToMemory",
			Slot = LastExpression.Value,
			Value = V
		}

		table.insert(P.Body, Expression)
		P:Jump(End - 1)
	end
	
	
	
	function P:OPERATOR(Token: Token)
		local LastExpression = P.Body[#P.Body]
		
		if LastExpression.Type == "IDENTIFIER" or LastExpression.Type == "NUMBER" then
			local V = P:Peek(P.Index + 1)

			local Passes = {
				["NUMBER"] = true,
				["IDENTIFIER"] = true
			}

			if not Passes[V.Type] then
				P.Error = "Must be a number or identifier"
				return
			end
			
			local Expression = {
				Type = "BinaryOperation",
				Operator = Token.Value,

				Left = LastExpression,
				Right = V
			}

			P.Body[#P.Body] = Expression
			P:Next()
			return
		end
		
		if LastExpression.Type == "Pool" and LastExpression.Key == "(" then --> Highest possible importance
			--> LastExpression will be engulfed by the current expression, but at the left instead of right
			local V = P:Peek(P.Index + 1)
			
			local Passes = {
				["NUMBER"] = true,
				["IDENTIFIER"] = true
			}

			if not Passes[V.Type] then
				P.Error = "Must be a number or identifier"
				return
			end
			
			local Expression = {
				Type = "BinaryOperation",
				Operator = Token.Value,

				Left = LastExpression,
				Right = V
			}

			P.Body[#P.Body] = Expression
			P:Next()
			return
		end
		
		
		if LastExpression.Type ~= "BinaryOperation" then
			P.Error = "Expected a number"
			return
		end
		
		local LastExpressionLevel = OperatorLevels[LastExpression.Operator]
		local CurrentLevel = OperatorLevels[Token.Value]
		
		local V = P:Peek(P.Index + 1)
		--> V must be a number or identifier
		
		local Passes = {
			["NUMBER"] = true,
			["IDENTIFIER"] = true
		}

		if not Passes[V.Type] then
			P.Error = "Must be a number or identifier"
			return
		end
		
		if CurrentLevel <= LastExpressionLevel then --> Both operations are of the same level or current is lower
			--> LastExpression will be engulfed by the current expression
			--> LastExpression needs to be at left
			local Expression = {
				Type = "BinaryOperation",
				Operator = Token.Value,
				
				Left = LastExpression,
				Right = V
			}
			
			P.Body[#P.Body] = Expression
			P:Next()
			return
		end
		
		if CurrentLevel > LastExpressionLevel then --> Current operation is more important than last operation
			local Expression = {
				Type = "BinaryOperation",
				Operator = LastExpression.Operator,
				
				Left = LastExpression.Left,
				Right = {
					Type = "BinaryOperation",
					Operator = Token.Value,
					
					Left = LastExpression.Right,
					Right = V
				}
			}
			
			P.Body[#P.Body] = Expression
			P:Next()
			return
		end
	end
	
	
	
	function P:COMPARATOR(Token: Token)
		local Passes = {
			BinaryOperation = true,
			NUMBER = true,
			IDENTIFIER = true
		}
		
		local V = P.Body[#P.Body]
		local V2 = P:Peek(P.Index + 1)
		if not V or not V2 then
			P.Error = "Attempted to compare with nil"
			return
		end
		
		if not Passes[V.Type] then
			P.Error = "Must be a number or identifier"
			return
		end
		
		if not Passes[V2.Type] then
			P.Error = "Must be a number or identifier"
			return
		end
		
		local Expression = {
			Type = "Comparison",
			Comparator = Token.Value,
			
			Left = V,
			Right = V2,
			
			True = 1,
			False = 1
		}
		
		P.Body[#P.Body] = Expression
		P:Next()
	end
	
	
	--------------------------------------------------------------------- KEYWORD - KEYWORD - KEYWORD - KEYWORD
	
	function P:KEYWORD(Token: Token)
		local Key = Token.Value
		
		--------------------------------------------------------------------- IF - IF - IF - IF
		
		if Key == "if" then
			print(GetValuesUntilPool("then"))
			
			
			local V1 = {}
			local V2 = {}
			local CMP = {}
			
			local CMPPos = 0
			local ThenPos = 0
			
			local Single = false
			
			for i = P.Index + 1, #P.Stream do
				local Current = P:Peek(i)
				if Current.Type == "COMPARATOR" then
					CMP = Current
					CMPPos = i
					V1 = table.pack(table.unpack(P.Stream, P.Index + 1, i - 1))
					break
				end
				
				if Current.Type == "Pool" and Current.Key == "then" then
					V1 = table.pack(table.unpack(P.Stream, P.Index + 1, i - 1))
					ThenPos = i
					Single = true
					break
				end
			end
			
			if not Single then
				if not CMP then
					P.Error = "Bolinha"
					return
				end

				for i = CMPPos + 1, #P.Stream do
					local Current = P:Peek(i)
					if Current.Type == "Pool" and Current.Key == "then" then
						V2 = table.pack(table.unpack(P.Stream, CMPPos + 1, i - 1))
						ThenPos = i
						break
					end
				end

				if not V2 then
					P.Error = "Bolinha2"
					return
				end
			end
			
			if Single then
				V1 = P:Pool(V1)
				
				local TestExpression = TestValue(V1[1])
				TestExpression.True = 1
				TestExpression.False = 2 --> Skips 2 indexes if false, this way the then pool will be ignored
				
				table.insert(P.Body, TestExpression)
				P:Skip(ThenPos - P.Index - 1)
				
				return
			end
			
			V1 = P:Pool(V1)
			V2 = P:Pool(V2)

			if #V1 > 1 or #V2 > 1 then
				P.Error = "Invalid values"
				return
			end

			V1 = V1[1]
			V2 = V2[1]

			local ComparatorExpression = Comparator(CMP.Value, V1, V2)
			ComparatorExpression.True = 1
			ComparatorExpression.False = 2 --> Skips 2 indexes if false, this way the then pool will be ignored

			table.insert(P.Body, ComparatorExpression)
			P:Skip(ThenPos - P.Index - 1)
		end
		
		
		--------------------------------------------------------------------- VAR - VAR - VAR - VAR
		
		
		if Key == "var" then
			--[[
			
				Expects:
					Token <Index + 1> --> Identifier
					Token <Index + 2> --> "=" operator
			
			]]
			
			local Name = P:Peek(P.Index + 1)
			local Equal = P:Peek(P.Index + 2)
			
			if Equal.Value ~= "=" or Equal.Type ~= "OPERATOR" then
				P.Error = 'Expected "="'
				return
			end
			
			if Name.Type ~= "IDENTIFIER" then
				P.Error = ""
				return
			end
			
			--> Pass = {FollowUPs}
			--> Pass = false ( means this is the end no matter what )
			local Pass = {
				["NUMBER"] = {OPERATOR = true},
				["STRING"] = {OPERATOR = true},
				["OPERATOR"] = {},
				["IDENTIFIER"] = {OPERATOR = true},
				["Pool"] = {},
			}
			
			local End = 0
			
			local Current = P.Index + 3
			while true do
				if Current > #P.Stream then
					End = #P.Stream + 1
					break
				end
				local C = P:Peek(Current)
				
				if C.Type == "IDENTIFIER" then
					local Next = P:Peek(Current + 1)
					if Next.Type == "Pool" and Next.Key == "(" then End = Current break end
				end
				
				if C.Type == "Pool" and C.Key == "{" then End = Current + 1 break end
				
				if not Pass[C.Type] then End = Current break end
				Current += 1
			end
			
			local V = table.pack(table.unpack(P.Stream, P.Index + 3, End - 1))
			V.n = nil
			
			V = P:Pool(V)
			V = V[1]
			
			local Expression = {
				Type = "WriteToMemory",
				Slot = Name.Value,
				Value = V
			}
			
			table.insert(P.Body, Expression)
			P:Jump(End - 2)
		end
		
		
		--------------------------------------------------------------------- RETURN - RETURN - RETURN - RETURN
		
		
		if Key == "return" then
			local End = 0

			local Current = P.Index + 1
			local Sep = true
			while true do
				if Current > #P.Stream then
					End = #P.Stream + 1
					break
				end
				local C = P:Peek(Current)

				if C.Type == "SEP" then Sep = true Current += 1 continue end
				if C.Type ~= "SEP" and Sep then Sep = false Current += 1 continue end
				End = Current
				break
			end

			local V = table.pack(table.unpack(P.Stream, P.Index + 1, End - 1))
			V.n = nil

			V = P:Pool(V)
			V.Type = nil

			local Expression = {
				Type = "Return",
				Value = V,
			}

			table.insert(P.Body, Expression)
			P:Jump(End - 2)
		end
		
		
		--------------------------------------------------------------------- WHILE - WHILE - WHILE - WHILE
		
		
		if Key == "while" then
			local V1, V2, CMP, JumpPOS = GetValuesUntilPool("do")
			
			if not CMP then --> Single value
				P:Jump(JumpPOS + 2)
				
				local WhileExpression = {
					Type = "WhileLoop_Single",
					Value = V1,
					Body = P:Peek(P.Index)
				}
				
				table.insert(P.Body, WhileExpression)
				return
			end
			
			P:Jump(JumpPOS + 6)
			
			local ComparatorExpression = Comparator(CMP.Value, V1, V2)
			local Body = P:Pool(P:Peek(P.Index))
			
			local WhileExpression = {
				Type = "WhileLoop",
				Value = ComparatorExpression,
				Body = Body
			}
			
			table.insert(P.Body, WhileExpression)
			return
		end
		
		return
	end
	
	--table.pack(table.unpack(V1, 2, #V1 - 1))
	
	
	function P:SEP(Token: Token)
		table.insert(P.Body, Token)
	end
	
	
	
	function P:BOOL(Token: Token)
		table.insert(P.Body, Token)
	end
	
	
	
	function P:Pool(Token: Pool)
		
		if Token.Key == "{" then --> Tables
			Token.Key = nil
			Token.Type = nil
			
			local Skips = 0
			local Sep = true
			local Final = {Values = {}, Type = "Table"}
			for i, TokenB in pairs(Token) do
				if Skips > 0 then Skips -= 1 continue end
				
				if TokenB.Type ~= "SEP" then
					local Slot = math.ceil(i / 2)
					if not Sep then P.Error = "Did not separate elements" return end
					
					if TokenB.Type == "IDENTIFIER" and Token[i + 1].Type == "OPERATOR" and Token[i + 1].Value == "=" then --> Dict
						
						local ValueStart = i + 2
						if #Token < ValueStart then P.Error = "Expected value after '=' in dictionary" return end
						local ValueEnd = #Token
						
						for x = ValueStart + 1, #Token do
							if Token[x].Type == "SEP" then ValueEnd = x - 1 end
						end
						
						local Value = table.pack(table.unpack(Token, ValueStart, ValueEnd))
						Value = P:Pool(Value)[1]
						
						Slot = TokenB.Value
						Final.Values[Slot] = Value
						
						Skips = 1 + (ValueEnd - i)
						
					else --> Normal indexed value
						
						local ValueEnd = #Token
						
						for x = i, #Token do
							if Token[x].Type == "SEP" then ValueEnd = x - 1 end
						end
						
						local Value = table.pack(table.unpack(Token, i, ValueEnd))
						Value = P:Pool(Value)[1]
						
						Final.Values[Slot] = Value
						
						Skips = ValueEnd - i
						
					end
					
					continue
				end
				
				Sep = true
			end
			
			P:Back()
			return Final
		end
		
		if Token.Key == "[" then --> Indexing
			--local Expression = {
			--	Type = "Index",
			--	Value = PoolContents,
			--}
			
			local LastExpression = P.Body[#P.Body]
			if LastExpression.Type ~= "Table" and LastExpression.Type ~= "IDENTIFIER" then P.Error = "Can only index tables" return end
			
			local Key = Token.Key
			Token.Key = nil
			Token.Type = nil

			local Program = Parser:Program(Token)
			local PoolContents = Program:Run()
			
			LastExpression.Indexed = true
			if LastExpression.IndexFlow then
				table.insert(LastExpression.IndexFlow, PoolContents[1])
			else
				LastExpression.IndexFlow = {PoolContents[1]}
			end
			
			return
		end
		
		if Token.Key == "(" and P.Body[#P.Body].Type == "IDENTIFIER" then --> Call
			local LastExpression = P.Body[#P.Body]

			local Key = Token.Key
			Token.Key = nil
			Token.Type = nil

			local Program = Parser:Program(Token)
			local PoolContents = Program:Run()

			P.Body[#P.Body] = {
				Type = "IndexedCall",
				CallSlot = LastExpression,
				Passed = PoolContents
			}

			return
		end
		
		
		--> Normal Pool
		
		local Key = Token.Key
		Token.Key = nil
		Token.Type = nil
		
		local Program = Parser:Program(Token)
		local PoolContents = Program:Run()
		
		PoolContents.Type = "Pool"
		PoolContents.Key = Key
		
		return PoolContents
	end
	
	
	function P:SPACE()
		return
	end
	
	
	function P:CONNECTOR(OP: {})
		local LastExpression = P.Body[#P.Body]
		if LastExpression.Type ~= "Table" and LastExpression.Type ~= "IDENTIFIER" then P.Error = "Can only index tables" return end
		
		local NextExpression = P:Peek(P.Index + 1)
		if NextExpression.Type ~= "IDENTIFIER" then P.Error = "Tried to index table with ".. P.Type:lower() return end
		
		LastExpression.Indexed = true
		if LastExpression.IndexFlow then
			table.insert(LastExpression.IndexFlow, NextExpression)
		else
			LastExpression.IndexFlow = {NextExpression}
		end
		
		P:Jump(P.Index + 1)
	end
	
	
	
	function P:Run(Base)
		while true do
			if P.Error then break end
			if P.Index > #P.Stream then break end
			
			local Next = P:Next()
			if not Next then break end
			if not Next.Type then continue end
			
			local Return = P[Next.Type](_, Next)
			if Return then
				table.insert(P.Body, Return)
			end
		end
		
		return P.Body, P.Error
	end
	
	return P
end


return function(Tokens: {})
	local Program = Parser:Program(Tokens)
	return Program:Run("A")
end
