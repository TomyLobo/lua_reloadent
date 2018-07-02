---------------------------------------------------------------
-- Usage:                                                    --
--   lua_reloadent{,_sv,_cl} sent <sent_class>               --
--   lua_reloadent{,_sv,_cl} swep <swep_class>               --
--   lua_reloadent{,_sv,_cl} tool <toolmode>                 --
--   lua_reloadent{,_sv,_cl} <sent/swep/tool>                --
--   lua_loadent <sent_class>                                --
--   lua_loadent <swep_class>                                --
--                                                           --
-- lua_reloadent_sv reloads on the client.                   --
-- lua_reloadent_cl reloads on the server.                   --
-- lua_reloadent    reloads on the server and all clients.   --
-- lua_loadent      registers a new entity class             --
--                                                           --
-- lua_reloadent, lua_reloadent_sv and lua_reloadent_cl can  --
-- be told whether to look for a SENT, a SWEP or a tool.     --
-- To do so, write "sent ", "swep " or "tool " before the    --
-- sent/swep/tool name.                                      --
--                                                           --
---------------------------------------------------------------
-- Examples:                                                 --
--   lua_reloadent lol_bomb                                  --
--   lua_reloadent baby_gun                                  --
--   lua_reloadent tool explode_tool                         --
--                                                           --
---------------------------------------------------------------
-- Pitfalls:                                                 --
--   Make sure your code replaces all hooks it may have      --
--   placed, or the previous code might handle those hooks   --
--   instead. Same goes for timers.                          --
--                                                           --
--   Special care should be taken for timer.Simple:          --
--   Make sure there is no timer.Simple still running from   --
--   your code while using lua_reloadent.                    --
--                                                           --
--   The client-side portion of this doesn't work well,      --
--   since gmod doesn't reload the files from the disk when  --
--   doing "include" on the client.                          --
--   An exception to this is single-player mode, so you      --
--   should use that to develop client-side code.            --
--                                                           --
--   The InitPostEntity event will not be called by          --
--   lua_reloadent. This means you cannot use it to fill     --
--   locals with globals from other components.              --
--                                                           --
--   lua_reloadent does not call ENT:Initialize() or any     --
--   function you might have called from tool code, like     --
--   ENT:Setup. It relies on the existing entity state and   --
--   merely replaces the functions.                          --
--                                                           --
---------------------------------------------------------------
-- Version history:                                          --
--   1.5.2 - You can now choose whether to reload a tool,    --
--           SENT or SWEP. See "Usage" for how.              --
--   1.5.1 - Fixed an error in gmod13 support for weapons.   --
--   1.5.0 - Added support for current GMod 12/13 versions.  --
--   1.4.1 - Auto-complete is now case-insensitive.          --
--         - Fixed a Lua error in lua_loadent.               --
--   1.4   - Added autocomplete for lua_reloadent* commands  --
--   1.3   - lua_(re)loadent now looks into the gamemode too --
--   1.2.1 - lua_loadent now fills all ENT/SWEP fields       --
--   1.2   - Made lua_loadent work with SWEPs as well        --
--   1.1   - Added lua_loadent                               --
--   1.0   - First public release                            --
---------------------------------------------------------------

AddCSLuaFile()
local FindInLua = function(path)
	return file.Find(path, "LUA")
end

-- helper functions
local function luaExists(luaname)
	return #FindInLua(luaname) ~= 0
end

local include2 = include

if CLIENT and not game.SinglePlayer() then
	local files = {}

	function include2(filename)
		local contents = files[filename]
		if contents then
			return RunString(contents)
		else
			return include(filename)
		end
	end
	function lua_reloadent_addfile(filename, contents)
		files[filename] = contents
	end
end

local function getent(entname)
	local metatable = scripted_ents.GetStored(entname)
	return metatable and metatable.t
end

local function getwep(entname)
	return weapons.GetStored(entname)
end

local function gettool(toolname, gmod_tool)
	if gmod_tool.Tool[toolname] then return gmod_tool.Tool[toolname] end
	for _,v in pairs(gmod_tool.Tool) do
		if v.WireClass == toolname then return v end
	end
end

-- STOOLs
local function lua_reloadtool(toolmode, nofallback)
	local gmod_tool = getwep("gmod_tool")
	local metatable = gettool(toolmode, gmod_tool)
	if metatable then
		Msg("Reloading tool '"..toolmode.."'...\n")
	elseif nofallback then
		Msg("Tool '"..toolmode.."' not found.")
		return
	else
		Msg("Entity/weapon/tool '"..toolmode.."' not found.")
		return
	end

	SWEP = gmod_tool TOOL = metatable ToolObj = getmetatable(metatable)
	--TOOL = ToolObj:Create()
	TOOL.Mode = toolmode
	if metatable.SourceFile then
		include2(metatable.SourceFile)
		--TODO: maybe include sv_ variant as well?
	elseif luaExists("weapons/gmod_tool/stools/"..toolmode..".lua") then
		include2("weapons/gmod_tool/stools/"..toolmode..".lua")
	else
		Msg("No source file for tool '"..toolmode.."' found.")
		return
	end

	--TOOL:CreateConVars()
	--gmod_tool.Tool[ toolmode ] = TOOL
	metatable = gettool(toolmode, gmod_tool)
	TOOL = nil SWEP = nil ToolObj = nil

	for _,ent in ipairs(ents.FindByClass("gmod_tool")) do
		local table = gettool(toolmode, ent)
		for k,v in pairs(metatable) do
			table[k] = v
		end
	end
end

-- SWEPs
local function lua_reloadwep(entname, filename, nofallback)
	local metatable = getwep(entname)
	if metatable then
		Msg("Reloading weapon '"..entname.."'...\n")
	elseif nofallback then
		Msg("Weapon '"..entname.."' not found.")
		return
	else
		return lua_reloadtool(entname)
	end

	SWEP = metatable
	if entname == "gmod_tool" or luaExists(metatable.Folder..filename) then
		include2(metatable.Folder..filename)
	elseif luaExists(metatable.Folder.."/shared.lua") then
		include2(metatable.Folder.."/shared.lua")
	elseif file.Exists(metatable.Folder..".lua","LUA") then
		include2(metatable.Folder..".lua")
	else
		Msg("No source file for weapon '"..entname.."' found.")
		return
	end
	SWEP = nil

	for _,ent in ipairs(ents.FindByClass(entname)) do
		local table = ent:GetTable()
		for k,v in pairs(metatable) do
			table[k] = v
		end
	end
end

-- SENTs
local function lua_reloadent(entname, filename, nofallback)
	local metatable = getent(entname)
	if metatable then
		Msg("Reloading entity '"..entname.."'...\n")
	elseif nofallback then
		Msg("Entity "..entname.." not found.")
		return
	else
		return lua_reloadwep(entname, filename)
	end

	ENT = metatable
	if luaExists(metatable.Folder) then
		include2(metatable.Folder..filename)
	elseif luaExists(metatable.Folder.."/shared.lua") then
		include2(metatable.Folder.."/shared.lua")
	elseif file.Exists(metatable.Folder..".lua","LUA") then
		include2(metatable.Folder..".lua")
	else
		Msg("No source file for entity '"..entname.."' found.")
		return
	end
	ENT = nil

	for _,ent in ipairs(ents.FindByClass(entname)) do
		local table = ent:GetTable()
		if table then
			for k,v in pairs(metatable) do
				table[k] = v
			end
		end
	end
end

local build_ent_index
if SERVER then

	---------------------- Register server-side lua_reloadent ----------------------
	-- The client is supposed to register less ugly proxy commands for these, which support auto-completition
	concommand.Add("_lua_reloadentity_sv", function(ply,command,args)
		if ply:IsValid() and not ply:IsSuperAdmin() then return end

		if args[2] then
			if args[1] == "tool" then
				lua_reloadtool(args[2], true)
				return
			end
			if args[1] == "swep" then
				lua_reloadwep(args[2], "/init.lua", true)
				return
			end
			if args[1] == "sent" then
				lua_reloadent(args[2], "/init.lua", true)
				return
			end
		end

		lua_reloadent(args[1], "/init.lua")
	end)

	concommand.Add("_lua_reloadent", function(ply,command,args)
		if ply:IsValid() and not ply:IsSuperAdmin() then return end

		-- reload on the server
		lua_reloadent(args[1], "/init.lua")

		-- reload on the clients
		umsg.Start("lua_reloadent")
			umsg.String(args[1])
		umsg.End()
	end)

elseif CLIENT then

	------------------------------ Auto-completition -------------------------------
	local ent_index

	-- inserts "index" into the trie
	local function assign_index(index, ent_index)
		local prefix, newindex = string.match(index, "^(.-_)(.*)$")
		if newindex then
			if ent_index[prefix] == false then ErrorNoHalt("SENTs/SWEPs/STOOLs ending with an underscore(_) are not supported.\n") end
			ent_index[prefix] = ent_index[prefix] or {}
			return assign_index(newindex, ent_index[prefix])
		end
		ent_index[index] = false
	end

	-- condenses degenerate parts of the trie
	local function condense_table(ent_index)
		local to_insert = {}
		for key,sub_index in pairs(ent_index) do
			if sub_index and condense_table(sub_index) then
				ent_index[key] = nil
				local k,v = next(sub_index)
				to_insert[key..k] = v
			end
		end
		for k,v in pairs(to_insert) do
			ent_index[k] = v
		end
		if table.Count(ent_index) < 2 then return true end
	end

	-- builds a new trie for lookup by autocomplete functions
	function build_ent_index()
		ent_index = {}
		for className,_ in pairs(scripted_ents.GetList()) do
			assign_index(className,ent_index)
			assign_index("sent "..className,ent_index)
		end
		for _,v in pairs(weapons.GetList()) do
			local className = v.Classname or v.ClassName
			if className == "gmod_tool" then gmod_tool = v end
			assign_index(v.ClassName,ent_index)
			assign_index("swep "..v.ClassName,ent_index)
		end
		if gmod_tool then
			for toolmode,_ in pairs(gmod_tool.Tool) do
				assign_index(toolmode,ent_index)
				assign_index("tool "..toolmode,ent_index)
			end
		end

		condense_table(ent_index)
	end

	build_ent_index() -- call now, just in case this script is ever reloaded.
	hook.Add("InitPostEntity", "lua_reloadent_build_ent_index", build_ent_index)

	-- Adds all trie nodes starting with "startswith from the trie "ent_index" to the list "ret" and prefixes them with "prefix"
	local function add_ents(ret, startswith, prefix, ent_index)
		for k,v in pairs(ent_index) do
			if k:sub(1,#startswith):lower() == startswith:sub(1,#k):lower() then
				if v and #startswith >= #k then
					add_ents(ret,startswith:sub(#k+1), prefix..k, v)
				elseif #startswith <= #k then
					table.insert(ret, prefix..k)
				end
			end
		end
	end

	local function autocomplete(commandName,args)
		args = string.match(args,"^%s*(.-)%s*$")
		local ret = {}
		add_ents(ret, args, commandName.." ", ent_index)
		table.sort(ret)
		return ret
	end

	------ Register proxy commands for the server-side lua_reloadent commands ------
	local function proxy(ply,command,args)
		RunConsoleCommand("_"..string.gsub(command,"ent_","entity_"), unpack(args))
	end

	concommand.Add("lua_reloadent", proxy, autocomplete)
	concommand.Add("lua_reloadent_sv", proxy, autocomplete)

	---------------------- Register client-side lua_reloadent ----------------------

	concommand.Add("lua_reloadent_cl", function(ply,command,args)
		lua_reloadent(args[1], "/cl_init.lua")
	end, autocomplete)

	usermessage.Hook("lua_reloadent", function(message)
		lua_reloadent(message:ReadString(), "/cl_init.lua")
	end)

end -- if CLIENT

--------------------------------- lua_loadent ----------------------------------

local function lua_loadwep(entname, filename)
	if weapons.Get(entname) then
		Msg("Weapon '"..entname.."' already registered. Use 'lua_reloadent "..entname.."' to reload it.")
		return
	end

	local folder = "weapons/"..entname

	Msg("Loading weapon '"..entname.."'...\n")

	SWEP = {
		Folder = folder,
		Base = "weapon_base",
		Primary = {},
		Secondary = {},
	}
	if luaExists(folder..filename) then
		include2(folder..filename)
	elseif luaExists(folder.."/shared.lua") then
		include2(folder.."/shared.lua")
	else
		Msg("No source file for entity/weapon '"..entname.."' found.")
		return
	end

	weapons.Register(SWEP, entname, false)

	SWEP = nil

	if CLIENT then build_ent_index() end
end

local function lua_loadent(entname, filename)
	if scripted_ents.Get(entname) then
		Msg("Entity '"..entname.."' already registered. Use 'lua_reloadent "..entname.."' to reload it.")
		return
	end

	local folder = "entities/"..entname

	ENT = { Folder = folder }
	if luaExists(folder..filename) then
		Msg("Loading entity '"..entname.."'...\n")
		include2(folder..filename)
	elseif luaExists(folder.."/shared.lua") then
		Msg("Loading entity '"..entname.."'...\n")
		include2(folder.."/shared.lua")
	else
		ENT = nil
		return lua_loadwep(entname, filename)
		--error("No source file for entity '"..entname.."' found.",0)
	end

	scripted_ents.Register(ENT, entname, false)

	ENT = nil

	if CLIENT then build_ent_index() end
end

if SERVER then
	concommand.Add("lua_loadent", function(ply,command,args)
		if ply:IsValid() and not ply:IsSuperAdmin() then return end

		-- load on the server
		lua_loadent(args[1], "/init.lua")

		-- load on the clients
		local rp = RecipientFilter()
		rp:AddAllPlayers()

		umsg.Start("lua_loadent", rp)
			umsg.String(args[1])
		umsg.End()
 	end)
elseif CLIENT then
	usermessage.Hook("lua_loadent", function(message)
		lua_loadent(message:ReadString(), "/cl_init.lua")
	end)
end
