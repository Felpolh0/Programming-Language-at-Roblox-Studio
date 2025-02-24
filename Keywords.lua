--[[
	Store all the keywords here. 
	Functionality should be added at the parser ( Parser:KEYWORD method )
]]

local module = {
	["var"] = true,
	["while"] = true,
	["if"] = true,
	["function"] = true,
	["then"] = true,
	["end"] = true,
	["return"] = true
}

return module
