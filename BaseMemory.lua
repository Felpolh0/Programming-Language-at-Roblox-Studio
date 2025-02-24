--[[

	Here is where we store built-in libraries

]]


local Memory = {
	["math"] = {
		Type = "Table",
		Values = {
			sqrt = function(Arguments: {})
				if not Arguments then return end
				Arguments["Type"] = nil

				return {
					Type = "NUMBER",
					Value = math.sqrt(Arguments[1].Value)
				}
			end,
			
			sin = function(Arguments: {})
				if not Arguments then return end
				Arguments["Type"] = nil

				return {
					Type = "NUMBER",
					Value = math.sin(Arguments[1].Value)
				}
			end,
			
			cos = function(Arguments: {})
				if not Arguments then return end
				Arguments["Type"] = nil

				return {
					Type = "NUMBER",
					Value = math.cos(Arguments[1].Value)
				}
			end,
			
			rad = function(Arguments: {})
				if not Arguments then return end
				Arguments["Type"] = nil

				return {
					Type = "NUMBER",
					Value = math.rad(Arguments[1].Value)
				}
			end,
			
			random = function(Arguments: {})
				if not Arguments then return end
				Arguments["Type"] = nil

				return {
					Type = "NUMBER",
					Value = math.random(Arguments[1].Value, Arguments[3].Value)
				}
			end,
			
			exp = function(Arguments: {})
				if not Arguments then return end
				Arguments["Type"] = nil

				return {
					Type = "NUMBER",
					Value = math.exp(Arguments[1].Value)
				}
			end,
			
			e = {
				Type = "NUMBER",
				Value = math.exp(1)
			},
			
			pi = {
				Type = "NUMBER",
				Value = math.pi
			},
		}
	},
	
	
	
	
	
	
	["string"] = {
		Type = "Table",
		Values = {
			
			sub = function(Arguments: {})
				if not Arguments then return end
				Arguments["Type"] = nil

				return {
					Type = "STRING",
					Value = string.sub(Arguments[1].Value, Arguments[3].Value, Arguments[5].Value)
				}
			end,
			
			lower = function(Arguments: {})
				if not Arguments then return end
				Arguments["Type"] = nil

				return {
					Type = "STRING",
					Value = string.lower(Arguments[1].Value)
				}
			end,
			
			upper = function(Arguments: {})
				if not Arguments then return end
				Arguments["Type"] = nil

				return {
					Type = "STRING",
					Value = string.upper(Arguments[1].Value)
				}
			end,
			
		}
	}
}

return Memory
