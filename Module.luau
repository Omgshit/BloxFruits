local importer = ...
assert(type(importer) == "table", "package importer not found")
assert(type(importer.Import) == "function", "Import not found")

local RobloxServices = importer:Import("RobloxServices")
local Connections = importer:Import("Connections")
local Obfuscated = importer:Import("Obfuscated")
local Settings = importer:Import("Settings")

local _ENV = (getgenv or getrenv or getfenv)()

local VirtualInputManager: VirtualInputManager = RobloxServices.VirtualInputManager
local CollectionService: CollectionService = RobloxServices.CollectionService
local ReplicatedStorage: ReplicatedStorage = RobloxServices.ReplicatedStorage
local TeleportService: TeleportService = RobloxServices.TeleportService
local TweenService: TweenService = RobloxServices.TweenService
local RunService: RunService = RobloxServices.RunService
local Players: Players = RobloxServices.Players

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GunValidator: RemoteEvent = Remotes:WaitForChild("Validator2")
local CommF: RemoteFunction = Remotes:WaitForChild("CommF_")
local CommE: RemoteEvent = Remotes:WaitForChild("CommE")

local ChestModels: Folder = workspace:WaitForChild("ChestModels")
local WorldOrigin: Folder = workspace:WaitForChild("_WorldOrigin")
local Characters: Folder = workspace:WaitForChild("Characters")
local SeaBeasts: Folder = workspace:WaitForChild("SeaBeasts")
local Enemies: Folder = workspace:WaitForChild("Enemies")
local Boats: Folder = workspace:WaitForChild("Boats")
local Map: Model = workspace:WaitForChild("Map")

local EnemySpawns: Folder = WorldOrigin:WaitForChild("EnemySpawns")
local Locations: Folder = WorldOrigin:WaitForChild("Locations")

local RenderStepped = RunService.RenderStepped
local Heartbeat = RunService.Heartbeat
local Stepped = RunService.Stepped
local Player = Players.LocalPlayer

local Data: Folder = Player:WaitForChild("Data")
local Level: IntValue = Data:WaitForChild("Level")
local Fragments: IntValue = Data:WaitForChild("Fragments")
local Money: IntValue = Data:WaitForChild("Beli")

local Modules: Folder? = ReplicatedStorage:WaitForChild("Modules")
local Net: ModuleScript = Modules:WaitForChild("Net")

local BLACKLISTED_EXECUTORS: { string } = {"NULL"}

local EXECUTOR_NAME: string = string.upper(if identifyexecutor then identifyexecutor() else "NULL")
local IS_BLACKLISTED_EXECUTOR: boolean = if table.find(BLACKLISTED_EXECUTORS, EXECUTOR_NAME) then true else false

local hookmetamethod = (not IS_BLACKLISTED_EXECUTOR and hookmetamethod) or (function(...) return ... end)
local hookfunction = (not IS_BLACKLISTED_EXECUTOR and hookfunction) or (function(...) return ... end)
local sethiddenproperty: (Instance, string, any?) -> (nil) = sethiddenproperty or (function(...) return ... end)

local setupvalue: (any, number, any?) -> (nil) = setupvalue or (debug and debug.setupvalue)
local getupvalue: (any, number) -> any = getupvalue or (debug and debug.getupvalue)

local ServerOwnerId: IntValue? = ReplicatedStorage:FindFirstChild("PrivateServerOwnerId")
local IsPrivateServer: boolean = if ServerOwnerId then ServerOwnerId.Value ~= 0 else true

local function CreateDictionary(array: { string? }, value: any?): { [string]: any? }
	local Dictionary = {}
	
	for _, string in ipairs(array) do
		Dictionary[string] = if type(value) == "table" then {} else value
	end
	
	return Dictionary
end

-- HookManager: responsável por proteger objetos, manipular propriedades hookadas
-- e gerenciar comportamento de noclip (CanTouch/CanCollide).

local function NewHookManager()
	local HookManager = {}

	local hookedProperties = {}
	local protectedObjects = {}
	local noclipObjects = {}
	local noclipProperties = {}

	local SafeObject = Obfuscated.SafeObject
	local cloneObject = SafeObject.Clone
	local originalCloneProperties = CreateDictionary(Obfuscated.OriginalProperties, true)

	local function isString(index)
		return type(index) == "string"
	end

	local originalIndex
	local originalNamecall

	originalIndex = hookmetamethod(game, "__index", function(object, index)
		local clone = protectedObjects[object]
		if clone and isString(index) and not originalCloneProperties[index] then
			object = clone
		else
			local isNoclip = noclipObjects[object]
			if isNoclip and noclipProperties[index] then
				return noclipProperties[index][object] or originalIndex(object, index)
			end
		end
		
		local hooked = hookedProperties[object]
		if hooked and hooked[index] ~= nil then
			return hooked[index]
		end
		
		return originalIndex(object, index)
	end)

	originalNamecall = hookmetamethod(game, "__namecall", function(self, ...)
		if protectedObjects[self] then
			return originalNamecall(SafeObject, ...)
		end
		return originalNamecall(self, ...)
	end)

	function HookManager.ProtectObject(object: Instance)
		assert(object, `ProtectObject -> Instance expeted, got {typeof(object)}`)
		
		object.Name = SafeObject.Name
		protectedObjects[object] = cloneObject(SafeObject)
	end

	function HookManager.UnprotectObject(object: Instance)
		if HookManager.IsProtected(object) then return end
		assert(object, `UnprotectObject -> Instance expeted, got {typeof(object)}`)
		
		local safeObject = protectedObjects[object]
		if safeObject then
			protectedObjects[object] = nil
			safeObject:Destroy()
		end
	end

	function HookManager.IsProtected(object: Instance): boolean
		return protectedObjects[object] ~= nil
	end

	function HookManager.HookProperty(object: Instance, property: string, value: any?)
		if not hookedProperties[object] then
			hookedProperties[object] = {}
		end
		hookedProperties[object][property] = value
	end

	function HookManager.UnhookProperty(object: Instance, property: string)
		local hooked = hookedProperties[object]
		if hooked then
			hooked[property] = nil
			
			if next(hooked) == nil then
				hookedProperties[object] = nil
			end
		end
	end

	function HookManager.SetCanTouchObjects(list)
		noclipProperties.CanTouch = list
	end

	function HookManager.SetCanCollideObjects(list)
		noclipProperties.CanCollide = list
	end
	
	function HookManager.ClearNoclipObjects()
		table.clear(noclipObjects)
	end
	
	function HookManager.AddNoclipObject(object: Instance)
		noclipObjects[object] = true
	end
	
	function HookManager.Clear()
		table.clear(protectedObjects)
		table.clear(hookedProperties)
		HookManager.ClearNoclipObjects()
	end
	
	HookManager.OriginalIndex = originalIndex
	HookManager.OriginalNamecall = originalNamecall
	
	return HookManager
end

local HookManager = (function()
	local manager = _ENV.rz_hook_manager or NewHookManager()
	_ENV.rz_hook_manager = manager
	return manager
end)()

local HIDDEN_SETTINGS: { [string]: any } = {
	SKILL_COOLDOWN = 0.5,
	CLEAR_AFTER = 50,
	
	SILENT_AIM_ENABLED = true,
	WALKSPEED_BYPASS_ENABLED = true,
}

local function GetEnemyName(text: string): string
	return text:gsub(if text:find("Lv. ") then " %pLv. %d+%p" else " %pBoss%p", "")
end

local function CheckPlayerAlly(__Player: Player): boolean
	if __Player.Parent == Characters then
		__Player = Players:GetPlayerFromCharacter(__Player)
	end
	
	if tostring(__Player.Team) == "Marines" and __Player.Team == Player.Team then
		return false
	elseif __Player:HasTag(`Ally{Player.Name}`) or Player:HasTag(`Ally{__Player.Name}`) then
		return false
	end
	
	return true
end

local function CreateNewClear()
	local COUNT_NEWINDEX = 0
	
	return {
		__newindex = function(self, index, value)
			if COUNT_NEWINDEX >= HIDDEN_SETTINGS.CLEAR_AFTER then
				for key, cache in self do
					if typeof(cache) == "Instance" and not cache:IsDescendantOf(game) then
						rawset(self, key, nil)
					end
				end
				COUNT_NEWINDEX = 0
			end
			
			COUNT_NEWINDEX += 1
			return rawset(self, index, value)
		end
	}
end

local function CreateDefaultDictionary(Value: any?): table
	return setmetatable({}, { __index = function() return Value end })
end

local HumanoidsCache do
	local Metatable = CreateNewClear()
	Metatable.__index = function(self, Character)
		local Humanoid = Character:FindFirstChild(if Character.Parent == SeaBeasts then "Health" else "Humanoid")
		
		if Humanoid then
			self[Character] = Humanoid
			return Humanoid
		end
	end
	
	HumanoidsCache = setmetatable({}, Metatable)
end

local function GetHuamnoidHealth(Humanoid: Humanoid): number
	return Humanoid[if Humanoid.ClassName == "Humanoid" then "Health" else "Value"]
end

local function DistanceFromCharacter(Value: CFrame | BasePart | Vector3): number
	if typeof(Value) ~= "Vector3" then
		Value = Value.Position
	end
	return Player:DistanceFromCharacter(Value)
end

local function IsAlive(Character: Model, _Humanoid: Humanoid): boolean
	if _Humanoid then
		return GetHuamnoidHealth(_Humanoid) > 0
	elseif Character then
		local Humanoid = HumanoidsCache[Character]
		
		if Humanoid then
			return GetHuamnoidHealth(Humanoid) > 0
		else
			return Character.Parent == Boats
		end
	end
	
	return false
end

local function NewErrorMessage(Message)
	-- local CoreGui = gethui and gethui() or game:GetService("CoreGui")
	
	return error(Message, 2)
end

local function ConvertVersionToNumber(Version: string): number
	local CurrentVersion;
	
	for Number in string.gmatch(string.sub(Version, 2, -1), "[^%.]+") do
		if not CurrentVersion then
			CurrentVersion = `{ Number }.`
		else
			CurrentVersion ..= Number
		end
	end
	
	return tonumber(CurrentVersion) or 0
end

local function NewConnection(Event: RBX, Action): (nil)
	table.insert(Connections, Event:Connect(Action))
end

local function NewCollection(Tag: string): { Instance }
	local Objects = CollectionService:GetTagged(Tag)
	
	NewConnection(CollectionService:GetInstanceAddedSignal(Tag), function(Object)
		table.insert(Objects, Object)
	end)
	
	return Objects
end

local function GetRandomHitboxLimb(Character: Model): BasePart?
	return Character:FindFirstChild(HitboxLimbs[math.random(#HitboxLimbs)])
end

local function CharacterEquipTool(Tool: Tool): boolean
	--[[if Tool:GetAttribute("Locks") then
		Tool:SetAttribute("Locks", nil)
	end]]
	
	if Tool.Parent == Player.Character then
		return true
	elseif Tool.Parent == Player.Backpack then
		Player.Character.Humanoid:EquipTool(Tool)
		return true
	end
	
	return false
end

local function EquipTool(ToolName: string, ByType: boolean?): (nil)
	if not IsAlive(Player.Character) then
		return nil
	end
	
	ByType = ByType or not ToolName
	ToolName = ToolName or Settings.FarmTool
	
	local Equipped = Cached.Equipped
	
	if Equipped and Equipped.Parent and Equipped[if ByType then "ToolTip" else "Name"] == ToolName then
		if CharacterEquipTool(Equipped) then
			return nil
		end
	end
	
	if ToolName and not ByType then
		local OnInventory = Player.Backpack:FindFirstChild(ToolName)
		
		if OnInventory then
			Cached.Equipped = OnInventory
			CharacterEquipTool(OnInventory)
		end
		
		return nil
	end
	
	for _, Tool in Player.Backpack:GetChildren() do
		if Tool:IsA("Tool") and Tool.ToolTip == ToolName then
			Cached.Equipped = Tool
			CharacterEquipTool(Tool)
			return nil
		end
	end
end

local Cached = {
	Closest = nil,
	Equipped = nil,
	
	RealFruitsName = setmetatable({}, CreateNewClear()),
	RealFruitsId = setmetatable({}, CreateNewClear()),
	
	Enemies = {}, -- setmetatable({}, CreateNewClear()),
	Progress = {},
	Bring = {},
	Tools = {}
}

local GameData = {
	Sea = table.find({2753915549, 4442272183, 7449423635}, game.PlaceId) or 0,
	SeasName = { "Main", "Dressrosa", "Zou" },
	MaxMastery = 600,
	MaxLevel = 2650
}

GameData.StringVersion = Obfuscated.GetGameVersion(NewErrorMessage)
GameData.NumberVersion = ConvertVersionToNumber(GameData.StringVersion)

do
	if string.sub(GameData.StringVersion, 1, 1) ~= "v" then return Player:Kick() end
	
	local SplitVersion = string.split(string.sub(GameData.StringVersion, 2, -1), ".")
	local CurrentVersion = `{ SplitVersion[1] or 0 }.`;
	
	for i = 2, #SplitVersion do
		CurrentVersion ..= tostring(SplitVersion[i] or 0)
	end
	
	GameData.NumberVersion =  tonumber(CurrentVersion) or 0
end

local Module = {
	IsAlive = IsAlive,
	GameData = GameData,
	HookManager = HookManager,
	NewConnection = NewConnection,
	DistanceFromCharacter = DistanceFromCharacter
}

Module.CollectionService = (function()
	local CollectionObjects = {}
	
	local Chests = NewCollection("_ChestTagged")
	local Berries = NewCollection("BerryBush")
	
	local GetChestDebounce, CachedChest = 0;
	local GetBerryDebounce, CachedBerry = 0;
	
	CollectionObjects.Chests = Chests
	CollectionObjects.Berries = Berries
	
	local function CanCollectChest(Chest)
		return Chest and not Chest:GetAttribute("IsDisabled")
	end
	
	local function HasBerries(Bush)
		return if next(Bush:GetAttributes()) then true else false
	end
	
	local function GetClosestChest(SelectedIsland)
		if CanCollectChest(CachedChest) and (not SelectedIsland or CachedChest:IsDescendantOf(SelectedIsland)) then
			return CachedChest
		elseif (tick() - GetChestDebounce) < 1 then
			return nil
		end
		
		local Distance, Closest = math.huge
		
		for i = 1, #Chests do
			local Chest = Chests[i]
			if CanCollectChest(Chest) and (not SelectedIsland or CachedChest:IsDescendantOf(SelectedIsland)) then
				local Magnitude = Player:DistanceFromCharacter(Chest:GetPivot().Position)
				
				if Magnitude < Distance then
					Magnitude, Closest = Distance, Chest
				end
			end
		end
		
		GetChestDebounce = tick()
		CachedChest = Closest
		
		return Closest
	end
	
	local function GetClosestBerry()
		if HasBerries(CachedBerry) and CachedBerry:IsDescendantOf(Map) then
			return CachedBerry
		elseif (tick() - GetBerryDebounce) < 1 then
			return nil
		end
		
		local Distance, Closest = math.huge
		
		for i = 1, #Berries do
			local Bush = Berries[i]
			
			if HasBerries(Bush) then
				local Magnitude = Player:DistanceFromCharacter(Bush.Parent:GetPivot().Position)
				
				if Magnitude < Distance then
					Magnitude, Closest = Distance, Bush
				end
			end
		end
		
		GetBerryDebounce = tick()
		CachedBerry = Closest
		
		return Closest
	end
	
	Module.GetClosestChest = GetClosestChest;
	Module.GetClosestBerry = GetClosestBerry;
	Module.HasBerries = HasBerries;
	
	return CollectionObjects
end)()

Module.Services = (function()
	local Services = {}
	
	Services.Network = (function()
		local Network = {}
		
		local InvokeServer = CommF.InvokeServer;
		
		local RF_TAG = "RF/%s";
		local RE_TAG = "RE/%s";
		
		function Network.InvokeCommF(...)
			return InvokeServer(CommF, ...)
		end
		
		function Network:RemoteFunction(RemoteName)
			return Net:WaitForChild(RF_TAG:format(RemoteName))
		end
		
		function Network:RemoteEvent(RemoteName)
			return Net:WaitForChild(RE_TAG:format(RemoteName))
		end
		
		return Network
	end)()
	
	Services.GoodSignal = (function()
		local Signal = {}
		local Connection = {}
		
		Connection.__index = Connection
		Signal.__index = Signal
		
		do
			function Connection:Disconnect(): (nil)
				if not self.Connected then
					return nil
				end
				
				local find = table.find(self.Signal, self)
				
				if find then
					table.remove(self.Signal, find)
				end
				
				self.Function = nil
				self.Connected = false
			end
			
			function Connection:Fire(...): (nil)
				if not self.Function then
					return nil
				end
				
				task.spawn(self.Function, ...)
			end
			
			function Connection.new(): Connection
				return setmetatable({
					Connected = true
				}, Connection)
			end
			
			setmetatable(Connection, {
				__index = function(self, index)
					error(("Attempt to get Connection::%s (not a valid member)"):format(tostring(index)), 2)
				end,
				__newindex = function(tb, key, value)
					error(("Attempt to set Connection::%s (not a valid member)"):format(tostring(key)), 2)
				end
			})
		end
		
		function Signal:Connect(Function): Connection
			assert(type(Function) == "function", "function expected, got " .. type(Function))
			
			local NewConnection = Connection.new()
			NewConnection.Function = Function
			NewConnection.Signal = self
			
			table.insert(self.Connections, NewConnection)
			return NewConnection
		end
		
		function Signal:Once(Function): (nil)
			local Connection;
			Connection = self:Connect(function(...)
				Function(...)
				Connection:Disconnect()
			end)
			return Connection
		end
		
		function Signal:Wait(): any?
			local WaitingCoroutine = coroutine.running()
			local Connection;Connection = self:Connect(function(...)
				Connection:Disconnect()
				task.spawn(WaitingCoroutine, ...)
			end)
			return coroutine.yield()
		end
		
		function Signal:Fire(...): (nil)
			for _, Connection in ipairs(self.Connections) do
				if Connection.Connected then
					Connection:Fire(...)
				end
			end
		end
		
		function Signal.new(): Signal
			return setmetatable({
				Connections = {}
			}, Signal)
		end
		
		Signal.Signals = {
			BvChanged = Signal.new(),
			Notify = Signal.new(),
			Error = Signal.new(),
		}
		
		setmetatable(Signal, {
			__index = function(self, index)
				error(`Attempt to get Signal::{ tostring(index) } (not a valid member)`, 2)
			end,
			__newindex = function(self, index, value)
				error(`Attempt to set Signal::{ tostring(index) } (not a valid member)`, 2)
			end
		})
		
		return Signal
	end)()
	
	Services.PlayerManager = (function()
		local Manager = {
			RootPartPosition = Vector3.zero
		}
		
		local PlayerCharacter = Player.Character
		
		function Manager:CheckIsAlive()
			if not IsAlive(PlayerCharacter) then
				PlayerCharacter = nil
				return false
			end
			
			return true
		end
		
		function Manager:GetCharacter()
			return self:CheckIsAlive() and PlayerCharacter
		end
		
		function Manager:GetRootPartPosition()
			if self:CheckIsAlive() then
				local RootPart = PlayerCharacter.Humanoid.RootPart
				
				if RootPart then
					local Position = RootPart.Position
					self.RootPartPosition = Position
					return Position
				end
			end
			
			return self.RootPartPosition
		end
		
		NewConnection(Player.CharacterAdded, function(...) PlayerCharacter = ... end)
		NewConnection(Player.CharacterRemoving, function() PlayerCharacter = nil end)
		
		return Manager
	end)()
	
	Services.Inventory = (function()
		local Inventory = {
			Unlocked = CreateDefaultDictionary(false),
			Mastery = CreateDefaultDictionary(0),
			Count = CreateDefaultDictionary(0),
			MasteryRequirements = {},
			Items = {}
		}
		
		local NotificationSignal = Services.GoodSignal.Signals.Notify
		
		local function ItemUpdated(self, NewItemData)
			if type(NewItemData) ~= "table" then return end
			if NewItemData.Type == "Wear" then NewItemData.Type = "Acessory" end
			
			local ItemName = NewItemData.Name
			self.Items[ItemName] = NewItemData
			
			if not self.Unlocked[ItemName] then self.Unlocked[ItemName] = true end
			if NewItemData.Count then self.Count[ItemName] = NewItemData.Count end
			if NewItemData.Mastery then self.Mastery[ItemName] = NewItemData.Mastery end
			if NewItemData.MasteryRequirements then self.MasteryRequirements[ItemName] = NewItemData.MasteryRequirements end
		end
		
		local function ItemRemoved(self, ItemName)
			if type(ItemName) == "string" then
				self.MasteryRequirements[ItemName] = nil
				self.Unlocked[ItemName] = nil
				self.Mastery[ItemName] = nil
				self.Count[ItemName] = nil
				self.Items[ItemName] = nil
			end
		end
		
		local Methods = {
			["ItemChanged"] = function(...) ItemUpdated(Inventory, ...) end;
			["ItemAdded"] = function(...) ItemUpdated(Inventory, ...) end;
			["ItemRemoved"] = function(...) ItemRemoved(Inventory, ...) end;
			["Notify"] = function(...) NotificationSignal:Fire(...) end;
		}
		
		local function OnClientEvent(Method, ...)
			if Method and Methods[Method] then
				Methods[Method](...)
			end
		end
		
		local function GetInventory()
			return Services.Network.InvokeCommF("getInventory")
		end
		
		task.spawn(function()
			NewConnection(CommE.OnClientEvent, OnClientEvent)
			local InventoryItems = GetInventory();
			
			while type(InventoryItems) ~= "table" and task.wait(1) do
				InventoryItems = GetInventory()
			end
			
			for index = 1, #InventoryItems do
				ItemUpdated(InventoryItems[index])
			end
		end)
		
		return Inventory
	end)()
	
	Services.Enemies = (function()
		local EnemiesModule = CreateDictionary({
			"__CakePrince", "__PirateRaid", "__TyrantSkies", "__Bones", "__Elite", "__Others"
		}, {})
		
		local TagsMobs = {
			["Deandre"] = "Elite", ["Diablo"] = "Elite", ["Urban"] = "Elite",
			
			["Reborn Skeleton"] = "Bones", ["Living Zombie"] = "Bones",
			["Demonic Soul"] = "Bones", ["Posessed Mummy"] = "Bones",
			
			["Head Baker"] = "CakePrince", ["Baking Staff"] = "CakePrince",
			["Cake Guard"] = "CakePrince", ["Cookie Crafter"] = "CakePrince",
			
			["Sun-kissed Warrior"] = "TyrantSkies", ["Skull Slayer"] = "TyrantSkies",
			["Isle Champion"] = "TyrantSkies", ["Serpent Hunter"] = "TyrantSkies",
		}
		
		local SpawnLocations = Module.SpawnLocations
		local CachedEnemies = Cached.Enemies
		local CachedBring = Cached.Bring
		
		local Attachment = Obfuscated.GetBringAttachment()
		
		local BringMobsCFrames = {}
		local BringMobsLookup = {}
		local IsSuperBring = false
		
		local UnprotectObject = HookManager.UnprotectObject
		local ProtectObject = HookManager.ProtectObject
		local OriginalIndex = HookManager.OriginalIndex
		
		local SpawnLocations = {}
		local EnemyLocations = {}
		
		EnemiesModule.SpawnLocations = SpawnLocations
		EnemiesModule.EnemyLocations = EnemyLocations
		
		do
			local IslandsStartWord = "Island "
			
			local function NewIslandAdded(Island)
				if string.sub(Island.Name, 1, #IslandsStartWord) == IslandsStartWord then
					CurrentRaidIsland = nil
				end
			end
			
			local function NewSpawn(Part)
				local EnemyName = GetEnemyName(Part.Name)
				EnemyLocations[EnemyName] = EnemyLocations[EnemyName] or {}
				
				local EnemySpawn = Part.CFrame + Vector3.one * 25
				SpawnLocations[EnemyName] = Part
				
				if not table.find(EnemyLocations[EnemyName], EnemySpawn) then
					table.insert(EnemyLocations[EnemyName], EnemySpawn)
				end
			end
			
			for _, Spawn in EnemySpawns:GetChildren() do NewSpawn(Spawn) end
			NewConnection(EnemySpawns.ChildAdded, NewSpawn)
			NewConnection(Locations.ChildAdded, NewIslandAdded)
		end
		
		local function CanBringMob(Enemy)
			return not BringMobsLookup[Enemy]
		end
		
		local function GetBringTag(EnemyName)
			return if IsSuperBring then "ALL_MOBS" else EnemyName
		end
		
		local function GetBringMobs(EnemyName)
			return if SuperBring then Enemies:GetChildren() else EnemiesModule:GetTagged(EnemyName)
		end
		
		local function StartBringMob(AlignPosition, Enemy, EnemyName, Humanoid, RootPart)
			while Enemy.Parent == Enemies and IsAlive(_, Humanoid) and RootPart.Parent == Enemy do
				local Target = BringMobsCFrames[GetBringTag(EnemyName)]
				local TargetPosition = Target and Target.Position
				
				if Target and (TargetPosition - RootPart.Position).Magnitude <= Settings.BringDistance then
					if AlignPosition.Position ~= TargetPosition then
						AlignPosition.Position = TargetPosition
					end
				else
					break
				end
				
				task.wait(0.25)
			end
		end
		
		local function BringMob(Enemy)
			if BringMobsLookup[Enemy] then return end
			
			local EnemyName = Enemy.Name
			local Humanoid = Enemy.Humanoid
			local RootPart = Humanoid.RootPart
			
			local CloneAttachment = Attachment:Clone()
			local AlignPosition = CloneAttachment.AlignPosition
			
			ProtectObject(CloneAttachment)
			CloneAttachment.Parent = RootPart
			
			pcall(StartBringMob, AlignPosition, Enemy, EnemyName, Humanoid, RootPart)
			
			BringMobsLookup[Enemy] = nil
			
			if CloneAttachment then
				UnprotectObject(CloneAttachment)
				CloneAttachment:Destroy()
			end
		end
		
		function EnemiesModule.GetEnemy(EnemyName: string): Model?
			if type(EnemyName) == "table" then
				return EnemiesModule:GetClosest(EnemyName)
			else
				return EnemiesModule:GetEnemyByTag(EnemyName)
			end
		end
		
		function EnemiesModule.IsSpawned(EnemyName: string): boolean
			local Cache = SpawnLocations[EnemyName]
			
			return ((Cache and Cache:GetAttribute("Active")) or EnemiesModule:GetEnemyByTag(EnemyName)) and true or false
		end
		
		function EnemiesModule.BringMobs(ToEnemy: Instance, BringType: number?, ToCFrame: CFrame?, Distance: number?): (nil)
			local RootPart = IsAlive(ToEnemy) and ToEnemy.Humanoid.RootPart
			if not RootPart then return end
			
			pcall(sethiddenproperty, Player, "SimulationRadius", math.huge)
			local ToEnemyName = ToEnemy.Name
			BringType = BringType or 0
			
			if not Distance and (not Settings.BringMobs or BringType == 0) then
				if not BringMobsCFrames[ToEnemyName] then
					BringMobsCFrames[ToEnemyName] = RootPart.CFrame
				end
				
				RootPart.CFrame = BringMobsCFrames[ToEnemyName]
				return nil
			end
			
			local MyRootPosition = Services.PlayerManager:GetRootPartPosition()
			IsSuperBring = BringType == 2
			
			local BringTag = GetBringTag(ToEnemyName)
			local Target = ToCFrame or RootPart.CFrame
			local MaxDistance = Distance or Settings.BringDistance
			
			if not BringMobsCFrames[BringTag] or (Target.Position - BringMobsCFrames[BringTag].Position).Magnitude > 25 then
				BringMobsCFrames[BringTag] = Target
			end
			
			for _, Enemy in GetBringMobs(ToEnemyName) do
				if not Enemy:FindFirstChild("CharacterReady") then continue end
				if Enemy.Parent ~= Enemies or not SuperBring and Enemy.Name ~= Name then continue end
				
				local EnemyRootPart = IsAlive(Enemy) and Enemy.Humanoid.RootPart
				if not EnemyRootPart then continue end
				
				if (Position - PrimaryPart.Position).Magnitude < MaxDistance then
					BringMob(Enemy)
				end
			end
		end
		
		function EnemiesModule:GetTagged(TagName: string): table?
			return self[`__{ TagName }`] or self.__Others[TagName]
		end
		
		function EnemiesModule:GetEnemyByTag(TagName: string): Model?
			local CachedEnemy = CachedEnemies[TagName]
			
			if CachedEnemy and IsAlive(CachedEnemy) then
				return CachedEnemy
			end
			
			local Enemies = self:GetTagged(TagName)
			
			if Enemies then
				for index = 1, #Enemies do
					local Enemy = Enemies[index]
					CachedEnemies[TagName] = Enemy
					return Enemy
				end
			end
		end
		
		function EnemiesModule:GetClosest(Enemies: { string }): Model?
			local SpecialTag = table.concat(Enemies, ".")
			local CachedEnemy = CachedEnemies[SpecialTag]
			
			if CachedEnemy and IsAlive(CachedEnemy) then
				return CachedEnemy
			end
			
			local Distance, Nearest = math.huge
			
			for i = 1, #Enemies do
				local Enemy = self:GetClosestByTag(Enemies[i])
				local Magnitude = Enemy and Player:DistanceFromCharacter(Enemy.PrimaryPart.Position)
				
				if Enemy and Magnitude <= Distance then
					Distance, Nearest = Magnitude, Enemy
				end
			end
			
			if Nearest then
				CachedEnemies[SpecialTag] = Nearest
				return Nearest
			end
		end
		
		function EnemiesModule:GetClosestByTag(TagName: string): Model?
			local CachedEnemy = CachedEnemies[TagName]
			
			if CachedEnemy and IsAlive(CachedEnemy) then
				return CachedEnemy
			end
			
			local Enemies = self:GetTagged(TagName)
			
			if RootPart and Enemies and #Enemies > 0 then
				local RootPosition = Services.PlayerManager:GetRootPartPosition()
				local Distance, Nearest = math.huge
				
				for i = 1, #Enemies do
					local Enemy = Enemies[i]
					local PrimaryPart = Enemy.PrimaryPart
					
					if PrimaryPart then
						local Magnitude = (RootPosition - PrimaryPart.Position).Magnitude
						
						if Magnitude <= 50 then
							CachedEnemies[TagName] = Enemy
							return Enemy
						elseif Magnitude <= Distance then
							Distance, Nearest = Magnitude, Enemy
						end
					end
				end
				
				if Nearest then
					CachedEnemies[TagName] = Nearest
					return Nearest
				end
			end
		end
		
		do
			local SeaCastlePosition = Vector3.new(-5556, 314, -2988)
			local OthersEnemies = EnemiesModule.__Others
			local CurrentSea = GameData.Sea
			
			local function NewEnemy(self, Enemy)
				if table.find(self, Enemy) then return end
				
				local Humanoid = Enemy:WaitForChild("Humanoid")
				
				if Humanoid and Humanoid.Health > 0 then
					table.insert(self, Enemy)
					Humanoid.Died:Wait()
					table.remove(self, table.find(self, Enemy))
				end
			end
			
			local function IsFromSeaCastle(Enemy)
				if Enemy.Name == "rip_indra True Form" or Enemy.Name == "Blank Buddy" then return end
				if not Enemy:WaitForChild("Humanoid") or Enemy.Humanoid.Health <= 0 then return end
				
				local RootPart = Enemy:WaitForChild("HumanoidRootPart")
				
				if RootPart and (RootPart.Position - SeaCastlePosition).Magnitude <= 750 then
					task.spawn(NewEnemy, EnemiesModule.__PirateRaid, Enemy)
					EnemiesModule.PirateRaid = tick()
				end
			end
			
			local function NewEnemyAdded(Enemy)
				local EnemyName = Enemy.Name
				local TagName = `__{ EnemyName }`
				
				OthersEnemies[EnemyName] = OthersEnemies[EnemyName] or {}
				task.spawn(NewEnemy, OthersEnemies[EnemyName], Enemy)
				
				if CurrentSea == 3 then
					task.spawn(IsFromSeaCastle, Enemy)
				end
				
				if EnemiesModule[TagName] then
					task.spawn(NewEnemy, EnemiesModule[TagName], Enemy)
				elseif TagsMobs[EnemyName] then
					task.spawn(NewEnemy, EnemiesModule[`__{ TagsMobs[EnemyName] }`], Enemy)
				end
			end
			
			for _, Enemy in CollectionService:GetTagged("BasicMob") do NewEnemyAdded(Enemy) end
			table.insert(Connections, CollectionService:GetInstanceAddedSignal("BasicMob"):Connect(NewEnemyAdded))
		end
		
		return EnemiesModule
	end)()
	
	Services.ToolService = (function()
		local ToolService = {}
		
		local InvokeCommF = Services.Network.InvokeCommF
		local ToolsCache = Cached.Tools
		local BUSO_PRICE = 25000
		
		local function FindFirstType(Tip: string): Tool?
			local Equipped = Player.Character:FindFirstChildOfClass("Tool")
			
			if Equipped and Equipped.ToolTip == Tip then
				return Equipped
			end
			
			for _, Tool in Player.Backpack:GetChildren() do
				if Tool:IsA("Tool") and Tool.ToolTip == Tip then
					return Tool
				end
			end
		end
		
		local function BuyBuso()
			if Money.Value < BUSO_PRICE then return end
			
			InvokeCommF("BuyHaki", "Buso")
		end
		
		local function GetTool(Name: string, ByType: boolean?): Tool?
			local Character = Player.Character
			if not IsAlive(Character) then return end
			
			local CacheTag = if ByType then `toolTip_{Name}` else Name
			local Cache = ToolsCache[CacheTag]
			
			if Cache and (Cache.Parent == Character or Cache.Parent == Player.Backpack) then
				return Cache
			end
			
			local HasTool = if ByType then FindFirstType(Name) else (Character:FindFirstChild(Name) or Player.Backpack:FindFirstChild(Name))
			
			if HasTool then
				ToolsCache[CacheTag] = HasTool
				return HasTool
			end
		end
		
		function ToolService.GetToolMastery(Name: string, ...): number
			local HasTool = GetTool(Name, ...)
			return HasTool and HasTool:GetAttribute("Level") or 0
		end
		
		function ToolService.VerifyTool(Name: string, ...): boolean
			return GetTool(Name, ...) and true or false
		end
		
		function ToolService.EnableBuso()
			local Character = Player.Character
			if IsAlive(Character) and not Character:FindFirstChild("HasBuso") then
				return if Character:HasTag("Buso") then InvokeCommF("Buso") else BuyBuso()
			end
		end
		
		ToolService.EquipTool = EquipTool
		
		return ToolService
	end)()
	
	Module.FastAttack = (function()
		local FastAttack = {}
		
		local ATTACK_RANGE = {
			["Blox Fruit"] = 40,
			["Melee"] = 50,
			["Sword"] = 50,
			["Gun"] = 300,
		}
		
		local SendHitsToServer = Obfuscated.SendHitsToServer
		local GetPartBoundsInBox = Obfuscated.GetPartBoundsInBox
		local GetMaxHits = Obfuscated.GetMaxHits
		
		local RE_ShootGunEvent = Services.Network:RemoteEvent("ShootGunEvent")
		
		Obfuscated.SetRigisterAttackEvent(Services.Network:RemoteEvent("RegisterAttack"))
		Obfuscated.SetRigisterHitEvent(Services.Network:RemoteEvent("RegisterHit"))
		
		local function attack()
			local Character = Player.Character
			if not IsAlive(Character) then return end
			
			local Humanoid = Character.Humanoid
			local RootPart = Humanoid.RootPart
			
			if not RootPart then return end
			
			local Equipped = Character:FindFirstChildOfClass("Tool")
			
			if Equipped then
				
			end
		end
		
		return FastAttack
		
		--[[local FastAttack = {
			Distance = 50,
			attackMobs = true,
			attackPlayers = true,
			Equipped = nil,
			Debounce = 0,
			ComboDebounce = 0,
			ShootDebounce = 0,
			M1Combo = 0,
			
			Overheat = {
				["Dragonstorm"] = {
					MaxOverheat = 3,
					Cooldown = 0,
					TotalOverheat = 0,
					Distance = 400,
					Shooting = false
				}
			},
			ShootsPerTarget = {
				["Dual Flintlock"] = 2
			},
			SpecialShoots = {
				["Skull Guitar"] = "TAP",
				["Bazooka"] = "Position",
				["Cannon"] = "Position",
				["Dragonstorm"] = "Overheat"
			},
			NormalClickFruits = {
				["Light-Light"] = true,
				["Ice-Ice"] = true
			}
		}
		
		local RE_RegisterAttack: RemoteEvent = Net:WaitForChild("RE/RegisterAttack")
		local RE_ShootGunEvent: RemoteEvent = Net:WaitForChild("RE/ShootGunEvent")
		local RE_RegisterHit: RemoteEvent = Net:WaitForChild("RE/RegisterHit")
		local Events: Folder = ReplicatedStorage:WaitForChild("Events")
		
		local SUCCESS_FLAGS, COMBAT_REMOTE_THREAD = pcall(function()
			return rawget(require(Modules.Flags), "COMBAT_REMOTE_THREAD") or false
		end)
		
		local SUCCESS_SHOOT, SHOOT_FUNCTION = pcall(function()
			return getupvalue(rawget(require(ReplicatedStorage.Controllers.CombatController), "Attack"), 9)
		end)
		
		local HIT_FUNCTION; task.defer(function()
			local PlayerScripts = Player:WaitForChild("PlayerScripts")
			local LocalScript = PlayerScripts:FindFirstChildOfClass("LocalScript")
			
			while not LocalScript do
				Player.PlayerScripts.ChildAdded:Wait()
				LocalScript = PlayerScripts:FindFirstChildOfClass("LocalScript")
			end
			
			if getsenv then
				local Success, ScriptEnv = pcall(getsenv, LocalScript)
				
				if Success and ScriptEnv then
					HIT_FUNCTION = rawget(ScriptEnv._G, "SendHitsToServer")
				end
			end
		end)
		
		FastAttack.ShootsFunctions = {
			["Skull Guitar"] = function(self: FastAttack, Equipped: Tool, Position: Vector3): (nil)
				Equipped.RemoteEvent:FireServer("TAP", Position) -- Events.ShootSoulGuitar:Invoke(Position)
			end
		}
		
		local CurrentBladeHits = {};
		local MyRootPartPosition = nil;
		local NoAttackBelowTool = nil;
		local NoAttackBelowDebounce = 0;
		local BelowHealthPercent = 0;
		
		local function ExpandsHitBox(Enemies: { table }): (nil)
			for i = 1, #Enemies do
				Enemies[i][2].Size = Vector3.one * 50
				Enemies[i][2].Transparency = 1
			end
		end
		
		local function CheckStun(ToolTip: string, Character: Character, Humanoid: Humanoid): boolean
			-- local Stun = Character:FindFirstChild("Stun")
			-- local Busy = Character:FindFirstChild("Busy")
			
			if Humanoid.Sit and (ToolTip == "Sword" or ToolTip == "Melee" or ToolTip == "Gun") then
				return false
			-- elseif Stun and Stun.Value > 0 then {{ or Busy and Busy.Value }}
			--	 return false
			end
			
			return true
		end
		
		local function NewBladeHit(RootPart: BasePart, Character: Model): (nil)
			table.insert(CurrentBladeHits, { Character, RootPart })
		end
		
		local function ProcessSeaEventsHits(Distance)
			for _, SeaBeast in SeaBeasts:GetChildren() do
				local BasePart = SeaBeast:FindFirstChildOfClass("MeshPart")
				
				if IsAlive(SeaBeast) and BasePart and (MyRootPartPosition - BasePart.Position).Magnitude < Distance then
					NewBladeHit(BasePart, SeaBeast)
				end
			end
			
			for _, Boat in Enemies:GetChildren() do
				if not Boat:GetAttribute("IsBoat") then continue end
				local BasePart = Boat:FindFirstChildOfClass("MeshPart")
				
				if IsAlive(Boat) and BasePart and (MyRootPartPosition - BasePart.Position).Magnitude < Distance then
					NewBladeHit(BasePart, Boat)
				end
			end
		end
		
		local function CanChangeGunTarget(Target, Enemy)
			if Enemy.Parent == SeaBeasts then
				return true
			elseif Target.Parent ~= SeaBeasts and Enemy:GetAttribute("IsBoat") then
				return true
			end
			
			return false
		end
		
		local function ConvertToGunHits()
			local Target, Hitbox;
			
			for index = 1, #CurrentBladeHits do
				local Hit = CurrentBladeHits[index]
				
				if not Target or CanChangeGunTarget(Target, Hit[1]) then
					Hitbox, Target = Hit[2], Hit[1];
				end
			end
			
			CurrentBladeHits = { Hitbox, math.random() }
			return Hitbox.Position, Hitbox;
		end
		
		local function ProcessHits(List: Folder, Equipped: Tool, Distance: number): (nil)
			local MyCharacter = Player.Character;
			local Targets = List:GetChildren();
			local MaxHits = GetMaxHits(MyCharacter);
			
			for i = 1, #Targets do
				if #CurrentBladeHits >= MaxHits then break end
				
				local Character = Targets[i]
				if Character == MyCharacter or Character:GetAttribute("IsBoat") or not IsAlive(Character) then continue end
				local RootPart = Character.PrimaryPart
				
				if (tick() - NoAttackBelowDebounce) <= 1 then
					local Humanoid = Character.Humanoid
					
					if Humanoid.Health / Humanoid.MaxHealth * 100 <= BelowHealthPercent then
						continue
					end
				end
				
				if RootPart and (Character.Parent ~= Characters or CheckPlayerAlly(Character)) then
					local Hitbox = GetRandomHitboxLimb(Character) or RootPart
					
					if Hitbox and (MyRootPartPosition - RootPart.Position).Magnitude <= Distance then
						NewBladeHit(Hitbox, Character)
					end
				end
			end
		end
		
		function FastAttack:DontAttackBelowPercent(Percent: number): boolean
			if SUCCESS_FLAGS and not COMBAT_REMOTE_THREAD or SUCCESS_FLAGS and COMBAT_REMOTE_THREAD and HIT_FUNCTION then
				BelowHealthPercent = Percent
				NoAttackBelowDebounce = tick()
				
				return true
			end
			
			return false
		end
		
		function FastAttack:UpdateBladeHits(Distance: number?, Anything: boolean?, SeasEvents: boolean?): (nil)
			Distance = Distance or self.Distance;
			CurrentBladeHits = {};
			
			if Anything or self.attackMobs then
				ProcessHits(Enemies, self.Equipped, Distance)
			end
			if Anything or self.attackPlayers then
				ProcessHits(Characters, self.Equipped, Distance)
			end
			if SeasEvents then
				ProcessSeaEventsHits(Distance, self.Equipped)
			end
		end
		
		function FastAttack:ShootInTarget(TargetPosition: Vector3): (nil)
			local Equipped = IsAlive(Player.Character) and Player.Character:FindFirstChildOfClass("Tool")
			
			if Equipped and Equipped.ToolTip == "Gun" then
				if Equipped:FindFirstChild("Cooldown") and (tick() - self.ShootDebounce) >= Equipped.Cooldown.Value then
					if self.ShootsFunctions[Equipped.Name] then
						return self.ShootsFunctions[Equipped.Name](self, Equipped, TargetPosition)
					end
					
					if SUCCESS_SHOOT and SHOOT_FUNCTION then
						local ShootType = self.SpecialShoots[Equipped.Name] or "Normal"
						
						if ShootType == "Position" or (ShootType == "TAP" and Equipped:FindFirstChild("RemoteEvent")) then
							Equipped:SetAttribute("LocalTotalShots", (Equipped:GetAttribute("LocalTotalShots") or 0) + 1)
							GunValidator:FireServer(self:GetValidator2())
							
							if ShootType == "TAP" then
								Equipped.RemoteEvent:FireServer("TAP", TargetPosition)
							else
								RE_ShootGunEvent:FireServer(TargetPosition)
							end
							
							self.ShootDebounce = tick()
						end
					else
						VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1);task.wait(0.05)
						VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1);task.wait(0.05)
						self.ShootDebounce = tick()
					end
				end
			end
		end
		
		function FastAttack:GetClosestEnemy(Distance: number?): (nil)
			self:UpdateBladeHits(Distance, true)
			
			local Distance, Closest = math.huge
			
			for i = 1, #CurrentBladeHits do
				local Magnitude = (MyRootPartPosition - CurrentBladeHits[i][2].Position).Magnitude
				
				if Magnitude <= Distance then
					Distance, Closest = Magnitude, CurrentBladeHits[i][2]
				end
			end
			
			return Closest
		end
		
		function FastAttack:GetCombo(): number
			local Combo = if tick() - self.ComboDebounce <= 0.4 then self.M1Combo else 0
			Combo = if Combo >= 4 then 1 else Combo + 1
			
			self.ComboDebounce = tick()
			self.M1Combo = Combo
			
			return Combo
		end
		
		function FastAttack:UseFruitM1(Character: Character, Equipped: Tool, Combo: number): (nil)
			local MyPosition = Character.Humanoid.RootPart.Position
			local _Enemies = Enemies:GetChildren()
			
			for i = 1, #_Enemies do
				local Enemy = _Enemies[i]
				local RootPart = IsAlive(Enemy) and Enemy.PrimaryPart
				
				if RootPart and (RootPart.Position - MyPosition).Magnitude <= 50 then
					Equipped.LeftClickRemote:FireServer((RootPart.Position - MyPosition).Unit, Combo)
				end
			end
		end
		
		function FastAttack:SuperFastAttack(EnemyHitBox, BladeHits, Cooldown)
			if Module.SuperFastAttack and Settings.FastAttack then
				local Enemy = EnemyHitBox.Parent
				local Times = if Enemy:GetAttribute("IsBoss") then 25 elseif Enemy:GetAttribute("RaidBoss") then 40 else 6
				
				self.Debounce = tick() + 9e9;
				local Overheat = 0;
				
				table.insert(BladeHits, { EnemyHitBox.Parent, EnemyHitBox })
				table.insert(BladeHits, math.random())
				
				while Overheat <= 0.4 do
					for i = 1, Times do
						RE_RegisterAttack:FireServer(self:GetCombo())
						HIT_FUNCTION(EnemyHitBox, BladeHits)
					end
					Overheat += task.wait(if Times > 10 then 0.07 else 0)
				end
				
				self.Debounce = 0;
				return true;
			end
		end
		
		function FastAttack:UseNormalClick(Cooldown: number): (nil)
			self:UpdateBladeHits()
			
			if #CurrentBladeHits > 0 then
				local PrimaryRootPart = table.remove(CurrentBladeHits)[2]
				
				if SUCCESS_FLAGS and COMBAT_REMOTE_THREAD and HIT_FUNCTION then
					if not self:SuperFastAttack(PrimaryRootPart, CurrentBladeHits, Cooldown) then
						RE_RegisterAttack:FireServer(Cooldown)
						HIT_FUNCTION(PrimaryRootPart, CurrentBladeHits)
					end
				elseif SUCCESS_FLAGS and not COMBAT_REMOTE_THREAD then
					RE_RegisterAttack:FireServer(Cooldown)
					RE_RegisterHit:FireServer(PrimaryRootPart, CurrentBladeHits)
				else
					table.insert(CurrentBladeHits, { Enemy, PrimaryRootPart })
					ExpandsHitBox(CurrentBladeHits)
					
					VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1);task.wait(0.05)
					VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
				end
			end
		end
		
		function FastAttack:GetValidator2()
			local v1 = getupvalue(SHOOT_FUNCTION, 15) -- v40, 15
			local v2 = getupvalue(SHOOT_FUNCTION, 13) -- v41, 13
			local v3 = getupvalue(SHOOT_FUNCTION, 16) -- v42, 16
			local v4 = getupvalue(SHOOT_FUNCTION, 17) -- v43, 17
			local v5 = getupvalue(SHOOT_FUNCTION, 14) -- v44, 14
			local v6 = getupvalue(SHOOT_FUNCTION, 12) -- v45, 12
			local v7 = getupvalue(SHOOT_FUNCTION, 18) -- v46, 18
			
			local v8 = v6 * v2									-- v133
			local v9 = (v5 * v2 + v6 * v1) % v3 -- v134
			
			v9 = (v9 * v3 + v8) % v4
			v5 = math.floor(v9 / v3)
			v6 = v9 - v5 * v3
			v7 = v7 + 1
			
			setupvalue(SHOOT_FUNCTION, 15, v1) -- v40, 15
			setupvalue(SHOOT_FUNCTION, 13, v2) -- v41, 13
			setupvalue(SHOOT_FUNCTION, 16, v3) -- v42, 16
			setupvalue(SHOOT_FUNCTION, 17, v4) -- v43, 17
			setupvalue(SHOOT_FUNCTION, 14, v5) -- v44, 14
			setupvalue(SHOOT_FUNCTION, 12, v6) -- v45, 12
			setupvalue(SHOOT_FUNCTION, 18, v7) -- v46, 18
			
			return math.floor(v9 / v4 * 16777215), v7
		end
		
		function FastAttack:UseGunShoot(Character, Equipped)
			if not Equipped.Enabled then return end
			
			local ShootType = self.SpecialShoots[Equipped.Name] or "Normal"
			
			if ShootType == "Normal" or ShootType == "Overheat" then
				local Distance = if ShootType == "Overheat" then self.Overheat[Equipped.Name].Distance else 200
				self:UpdateBladeHits(Distance, false, true)
				
				if #CurrentBladeHits == 0 then
					return nil
				end
				
				local Position, PrimaryPart = ConvertToGunHits()
				local PrimaryTarget = PrimaryPart.Parent
				
				if ShootType == "Overheat" then
					self.Debounce = tick() + 9e9
					
					while PrimaryTarget.Parent and IsAlive(PrimaryTarget) and Equipped and Equipped.Parent == Player.Character do
						if PrimaryPart.Parent ~= PrimaryTarget or DistanceFromCharacter(PrimaryPart) > Distance then
							break
						end
						
						Equipped:SetAttribute("LocalTotalShots", (Equipped:GetAttribute("LocalTotalShots") or 0) + 1)
						GunValidator:FireServer(self:GetValidator2())
						RE_ShootGunEvent:FireServer(Position, CurrentBladeHits)
						task.wait()
					end
					
					self.Debounce = 0
				elseif PrimaryTarget then
					Equipped:SetAttribute("LocalTotalShots", (Equipped:GetAttribute("LocalTotalShots") or 0) + 1)
					GunValidator:FireServer(self:GetValidator2())
					
					for i = 1, (self.ShootsPerTarget[Equipped.Name] or 1) do
						RE_ShootGunEvent:FireServer(Position, CurrentBladeHits)
					end
				end
			elseif ShootType == "Position" or (ShootType == "TAP" and Equipped:FindFirstChild("RemoteEvent")) then
				local Target = self:GetClosestEnemy(200)
				
				if Target then
					if self.ShootsFunctions[Equipped.Name] then
						return self.ShootsFunctions[Equipped.Name](self, Equipped, Target.Position)
					end
					
					Equipped:SetAttribute("LocalTotalShots", (Equipped:GetAttribute("LocalTotalShots") or 0) + 1)
					GunValidator:FireServer(self:GetValidator2())
					
					if ShootType == "TAP" then
						Equipped.RemoteEvent:FireServer("TAP", Target.Position)
					else
						RE_ShootGunEvent:FireServer(Target.Position)
					end
				end
			end
		end
		
		table.insert(Connections, Stepped:Connect(function()
			if not Settings.AutoClick or (tick() - Module.AttackCooldown) <= 1 then return end
			if not IsAlive(Player.Character) then return end
			
			local self = FastAttack;
			local Character = Player.Character;
			local Humanoid = Character.Humanoid;
			
			if not Humanoid.RootPart then return end
			
			local Equipped = Character:FindFirstChildOfClass("Tool")
			local ToolTip = Equipped and Equipped.ToolTip
			
			if not Equipped or (ToolTip ~= "Gun" and ToolTip ~= "Melee" and ToolTip ~= "Blox Fruit" and ToolTip ~= "Sword") then
				return nil
			end
			
			local Cooldown = Equipped:FindFirstChild("Cooldown") and Equipped.Cooldown.Value or DEFAULT_COOLDOWN;
			
			if (tick() - self.Debounce) >= Cooldown and CheckStun(ToolTip, Character, Humanoid) then
				local Combo = self:GetCombo();
				if Combo >= 4 then Cooldown += GetCooldownIncrrament(Equipped.Name, ) end;
				
				self.Equipped = Equipped;
				self.Debounce = if Combo >= 4 and ToolTip ~= "Gun" then tick() + 0.05 else tick();
				MyRootPartPosition = Character.Humanoid.RootPart.Position;
				
				if ToolTip == "Blox Fruit" and not self.NormalClickFruits[Equipped.Name] then
					if Equipped:FindFirstChild("LeftClickRemote") then
						self:UseFruitM1(Character, Equipped, Combo)
					end
				elseif ToolTip == "Gun" then
					if SUCCESS_SHOOT and SHOOT_FUNCTION and (Settings.AutoShoot or Settings.dStormSea) then
						self:UseGunShoot(Character, Equipped)
					end
				else
					self:UseNormalClick(Cooldown)
				end
			end
		end))
		
		return FastAttack]]
	end)()
	
	return Services
end)()

local DisableCanTouchDebounce = 0

function Module.DisableCanTouch()
	DisableCanTouchDebounce = tick()
end

Module.TweenBodyVelocity = (function()
	local ClearNoclipParts = HookManager.ClearNoclipParts
	local AddNoclipObject = HookManager.AddNoclipObject
	local UnprotectObject = HookManager.UnprotectObject
	local ProtectObject = HookManager.ProtectObject
	local OriginalIndex = HookManager.OriginalIndex
	
	local BodyVeloChangedSignal = Module.Services.GoodSignal.Signals.BvChanged
	
	local BodyVelocity = Instance.new("BodyVelocity")
	BodyVelocity.Velocity = Vector3.zero
	BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	BodyVelocity.P = 1000
	
	if _ENV.tween_bodyvelocity then
		UnprotectObject(_ENV.tween_bodyvelocity)
		_ENV.tween_bodyvelocity:Destroy()
	end
	
	ProtectObject(BodyVelocity)
	_ENV.tween_bodyvelocity = BodyVelocity
	
	local IsA, FindFirstChild = game.IsA, game.FindFirstChild
	local IsCustomTag = false
	
	local BaseParts, CanCollideObjects, CanTouchObjects = {}, {}, {} do
		HookManager.SetCanCollideObjects(CanCollideObjects)
		HookManager.SetCanTouchObjects(CanTouchObjects)
		
		local function AddObjectToBaseParts(Object)
			if Object ~= BodyVelocity and IsA(Object, "BasePart") and (Object.CanCollide or Object.CanTouch) then
				table.insert(BaseParts, Object)
				AddNoclipObject(Object)
				
				if OriginalIndex(Object, "CanCollide") then CanCollideObjects[Object] = true end
				if OriginalIndex(Object, "CanTouch") then CanTouchObjects[Object] = true end
			end
		end
		
		local function RemoveObjectsFromBaseParts(BasePart)
			local index = table.find(BaseParts, BasePart)
			
			if index then
				table.remove(BaseParts, index)
			end
		end
		
		local function NewCharacter(Character)
			if not Character then return end
			table.clear(BaseParts)
			
			for _, Object in Character:GetDescendants() do AddObjectToBaseParts(Object) end
			Character.DescendantAdded:Connect(AddObjectToBaseParts)
			Character.DescendantRemoving:Connect(RemoveObjectsFromBaseParts)
			
			Character:WaitForChild("Humanoid", 9e9).Died:Wait()
			table.clear(BaseParts)
			ClearNoclipParts()
		end
		
		NewConnection(Player.CharacterAdded, NewCharacter)
		task.spawn(NewCharacter, Player.Character)
	end
	
	local function NoClipOnStepped(Character)
		if not IsCustomTag and _ENV.OnFarm then
			IsCustomTag = true
		end
		
		if _ENV.OnFarm and not Player:HasTag("Teleporting") then
			Player:AddTag("Teleporting")
			IsCustomTag = true
		elseif IsCustomTag and not _ENV.OnFarm and Player:HasTag("Teleporting") then
			Player:RemoveTag("Teleporting")
			IsCustomTag = false
		end
		
		if _ENV.OnFarm then
			for i = 1, #BaseParts do
				local BasePart = BaseParts[i]
				local CanTouchValue = if (tick() - DisableCanTouchDebounce) <= 1 then false else true
				
				if CanTouchObjects[BasePart] and BasePart.CanTouch ~= CanTouchValue then
					BasePart.CanTouch = CanTouchValue
				end
				if CanCollideObjects[BasePart] and BasePart.CanCollide then
					BasePart.CanCollide = false
				end
			end
		elseif Character.PrimaryPart and (not Character.PrimaryPart.CanCollide or not Character.PrimaryPart.CanTouch) then
			for i = 1, #BaseParts do
				local BasePart = BaseParts[i]
				
				if CanCollideObjects[BasePart] then
					BasePart.CanCollide = true
				end
				if CanTouchObjects[BasePart] then
					BasePart.CanTouch = true
				end
			end
		end
	end
	
	local function UpdateVelocityOnStepped(Character)
		local BasePart = FindFirstChild(Character, "UpperTorso")
		local Humanoid = FindFirstChild(Character, "Humanoid")
		local BodyVelocity = _ENV.tween_bodyvelocity
		
		local NewParent = if _ENV.OnFarm and BasePart and Humanoid and Humanoid.Health > 0 then BasePart else nil
		
		if OriginalIndex(BodyVelocity, "Parent") ~= NewParent then
			BodyVelocity.Parent = NewParent
			BodyVeloChangedSignal:Fire(NewParent)
		end
		
		local Velocity = OriginalIndex(BodyVelocity, "Velocity")
		
		if Velocity ~= Vector3.zero and (not Humanoid or not Humanoid.SeatPart or not _ENV.OnFarm) then
			BodyVelocity.Velocity = Vector3.zero
		end
	end
	
	NewConnection(Stepped, function()
		local Character = Player.Character
		if IsAlive(Character) then
			UpdateVelocityOnStepped(Character)
			NoClipOnStepped(Character)
		end
	end)
	
	return BodyVelocity
end)()

Module.RunModules = (function()
	local Modules = {}
	
	local function NewModule(Name, Module)
		Modules[Name] = Module
	end
	
	local ErrorSignal = Module.Services.GoodSignal.Signals.Error
	
	NewModule("FarmQueue", function(Options)
		NewConnection(ErrorSignal, function(Message)
			return error(Message, 2)
		end)
		
		ErrorSignal:Fire(select(2, pcall(function()
			local function GetQueue()
				for _, Option in Options do
					Settings.RunningOption = Option.Name
					local Method = Option.Function()
					
					if Method then
						if type(Method) == "string" then
							Settings.RunningMethod = Method
						end
						return Method
					end
				end
				
				Settings.RunningOption, Settings.RunningMethod = nil, nil
			end
			
			while task.wait(Settings.SmoothMode and 0.25 or 0) do
				if _ENV.teleporting then
					_ENV.OnFarm = true
				elseif Settings.IgnoreErrors then
					local Success, Response = pcall(GetQueue)
					
					_ENV.OnFarm = (not Success and _ENV.OnFarm) or Response
				else
					_ENV.OnFarm = if GetQueue() then true else false
				end
			end
		end)))
	end)
	
	NewModule("Translator", function(Window, Translation)
		local MakeTab = Window.MakeTab
		
		Window.MakeTab = function(self, Configs)
			if Translation[ Configs[1] ] then
				Configs[1] = Translation[ Configs[1] ]
			end
			
			local Tab = MakeTab(self, Configs)
			local NewTab = {}
			
			function NewTab:AddSection(Name)
				return Tab:AddSection(Translation[Name] or Name)
			end
			
			function NewTab:AddButton(Configs)
				local Translator = Translation[ Configs[1] ]
				
				if Translator then
					Configs[1] = type(Translator) == "string" and Translator or Translator[1]
					Configs.Desc = type(Translator) ~= "string" and Translator[2]
				end
				
				return Tab:AddButton(Configs)
			end
			
			function NewTab:AddToggle(Configs)
				local Translator = Translation[ Configs[1] ]
				
				if Translator then
					Configs[1] = type(Translator) == "string" and Translator or Translator[1]
					Configs.Desc = type(Translator) ~= "string" and Translator[2]
				end
				
				return Tab:AddToggle(Configs)
			end
			
			function NewTab:AddSlider(Configs)
				local Translator = Translation[ Configs[1] ]
				
				if Translator then
					Configs[1] = type(Translator) == "string" and Translator or Translator[1]
					Configs.Desc = type(Translator) ~= "string" and Translator[2]
				end
				
				return Tab:AddSlider(Configs)
			end
			
			function NewTab:AddDropdown(Configs)
				local Translator = Translation[ Configs[1] ]
				
				if Translator then
					Configs[1] = type(Translator) == "string" and Translator or Translator[1]
					Configs.Desc = type(Translator) ~= "string" and Translator[2]
				end
				
				return Tab:AddDropdown(Configs)
			end
			
			function NewTab:AddTextBox(Configs)
				local Translator = Translation[ Configs[1] ]
				
				if Translator then
					Configs[1] = type(Translator) == "string" and Translator or Translator[1]
					Configs.Desc = type(Translator) ~= "string" and Translator[2]
				end
				
				return Tab:AddTextBox(Configs)
			end
			
			return setmetatable(NewTab, {
				__index = Tab
			})
		end
	end)
	
	NewModule("OptionsPlugin", function(EnabledOptions, Options)
		local Builder = {}
		
		function Builder.Toggle(Tab, Settings, Flag)
			Options[Flag] = Tab:AddToggle({
				Name = Settings[1],
				Default = if type(Settings[2]) ~= "string" then Settings[2] else nil,
				Description = Settings[if type(Settings[2]) == "string" then 2 else 3],
				Callback = function(Value) EnabledOptions[Flag] = Value end,
				Flag = Flag
			})
		end
		
		return Builder
	end)
	
	NewModule("TweenManager", function()
		local module = {}
		module.__index = module
		
		local tweens = {}
		local EasingStyle = Enum.EasingStyle.Linear
		
		function module.new(obj, time, prop, value)
			local self = setmetatable({}, module)
			
			self.tween = TweenService:Create(obj, TweenInfo.new(time, EasingStyle), { [prop] = value })
			self.tween:Play()
			self.value = value
			self.object = obj
			
			if tweens[obj] then
				tweens[obj]:destroy()
			end
			
			tweens[obj] = self
			return self
		end
		
		function module:destroy()
			self.tween:Pause()
			self.tween:Destroy()
			
			tweens[self.object] = nil
			setmetatable(self, nil)
		end
		
		function module:stopTween(obj)
			if obj and tweens[obj] then
				tweens[obj]:destroy()
			end
		end
		
		return module
	end)
	
	return Modules
end)()

return Module
