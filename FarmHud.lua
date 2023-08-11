local ADDON_NAME = "FarmHUD"
local FarmHud = CreateFrame("frame")
_G["FarmHud"] = FarmHud

local NPCScan = _NPCScan and _NPCScan.Overlay and _NPCScan.Overlay.Modules.List[ "Minimap" ];
local fh_scale = 1.4
local fh_mapRotation
local indicators = {"N", "NE", "E", "SE", "S", "SW", "W", "NW"}
local directions = {}
local playerDot
local updateRotations
local mousewarn

local print = function(s)
	local str = s
	if s == nil then str = "" end
	DEFAULT_CHAT_FRAME:AddMessage("|cffa0f6aa[".. ADDON_NAME .."]|r: " .. str)
end

---------------------------------------------------------------------------------------------

-- CORE

---------------------------------------------------------------------------------------------


local onShow = function()
	--print("OnShow - called.")
	fh_mapRotation = GetCVar("rotateMinimap")
	SetCVar("rotateMinimap", "1")
	if GatherMate and (FarmHudDB.show_gathermate == true) then
		GatherMate:GetModule("Display"):ReparentMinimapPins(FarmHudMapCluster)
		GatherMate:GetModule("Display"):ChangedVars(nil, "ROTATE_MINIMAP", "1")
	end

	if Gatherer and (FarmHudDB.show_gatherer == true) then
		Gatherer.MiniNotes.SetCurrentMinimap(FarmHudMapCluster)
	end

	if Routes and Routes.ReparentMinimap and (FarmHudDB.show_routes == true) then
		Routes:ReparentMinimap(FarmHudMapCluster)
		Routes:CVAR_UPDATE(nil, "ROTATE_MINIMAP", "1")
	end

	if NPCScan and NPCScan.SetMinimapFrame and (FarmHudDB.show_npcscan == true) then
		NPCScan:SetMinimapFrame(FarmHudMapCluster)
	end

	FarmHud:SetScript("OnUpdate", updateRotations)
	MinimapCluster:Hide()
end

local onHide = function()
	SetCVar("rotateMinimap", fh_mapRotation)
	-- Fix pfQuest icons rotating after farmhud is hidden
	SetCVar("rotateMinimap", "0")
	if GatherMate then
		GatherMate:GetModule("Display"):ReparentMinimapPins(Minimap)
		GatherMate:GetModule("Display"):ChangedVars(nil, "ROTATE_MINIMAP", fh_mapRotation)
	end

	if Gatherer then
		Gatherer.MiniNotes.SetCurrentMinimap(Minimap)
	end

	if Routes and Routes.ReparentMinimap then
		Routes:ReparentMinimap(Minimap)
		Routes:CVAR_UPDATE(nil, "ROTATE_MINIMAP", fh_mapRotation)
	end

	if NPCScan and NPCScan.SetMinimapFrame then
		NPCScan:SetMinimapFrame(Minimap)
	end

	FarmHud:SetScript("OnUpdate", nil)
	MinimapCluster:Show()
end


function FarmHud:SetScales()
	FarmHudMinimap:ClearAllPoints()
	FarmHudMinimap:SetPoint("CENTER", UIParent, "CENTER")

	FarmHudMapCluster:ClearAllPoints()
	FarmHudMapCluster:SetPoint("CENTER")

	local size = UIParent:GetHeight() / fh_scale
	FarmHudMinimap:SetWidth(size)
	FarmHudMinimap:SetHeight(size)
	FarmHudMapCluster:SetHeight(size)
	FarmHudMapCluster:SetWidth(size)
	gatherCircle:SetWidth(size * 0.45)
	gatherCircle:SetHeight(size * 0.45)

	if FarmHudDB.show_gather_circle then
		gatherCircle:Show()
	else
		gatherCircle:Hide()
	end

	FarmHudMapCluster:SetScale(fh_scale)
	playerDot:SetWidth(15)
	playerDot:SetHeight(15)

	local size = UIParent:GetHeight() * FarmHudDB.fh_scale -- Use multiplication
	FarmHudMinimap:SetWidth(size)
	FarmHudMinimap:SetHeight(size)
	FarmHudMapCluster:SetHeight(size)
	FarmHudMapCluster:SetWidth(size)

	for _, v in ipairs(directions) do
		if FarmHudDB.enable_directions then
			v:Show()
			v.radius = FarmHudMinimap:GetWidth() * 0.214
		else
			v:Hide()
		end
	end
end


---------------------------------------------------------------------------------------------

-- TOGGLE HUD & MOUSE

---------------------------------------------------------------------------------------------

function FarmHud:Toggle(flag)
	if flag == nil and not FarmHudDB.show_mounted then
		if FarmHudMapCluster:IsVisible() then
			FarmHudMapCluster:Hide()
		else
			FarmHudMapCluster:Show()
			FarmHud:SetScales()
			FarmHud:MouseToggle(false)
		end
	else
		if flag then
			FarmHudMapCluster:Show()
			FarmHud:SetScales()
			FarmHud:MouseToggle(false)
		else
			FarmHudMapCluster:Hide()
		end
	end
end


local MouseToggled = false

-- Register events
local FarmHudFrame = CreateFrame("Frame")
FarmHudFrame:RegisterEvent("MODIFIER_STATE_CHANGED") -- Entered combat

-- Set up event handlers
FarmHudFrame:SetScript("OnEvent", function(_, event, ...)
	if event == "MODIFIER_STATE_CHANGED" then
		if IsModifierKeyDown() then
			FarmHud:MouseToggle(true)
			MouseToggled = true
		else
			FarmHud:MouseToggle(false)
			MouseToggled = false
		end
	end
end)

function FarmHud:MouseToggle(enableMouse)
	if enableMouse then
		FarmHudMinimap:EnableMouse(true)
		FarmHudMinimap:SetScript("OnMouseDown", function (_, button)
			if button == 'RightButton' then
				MouselookStart()
			end
		end)
		mousewarn:Show()

	else
		FarmHudMinimap:EnableMouse(false)
		mousewarn:Hide()
	end
end



do
	local target = 1 / 90
	local total = 0

	function updateRotations(_, t)
		total = total + t
		if total < target then return end
		while total > target do total = total - target end
		if MinimapCluster:IsVisible() then MinimapCluster:Hide() end
		local bearing = -MiniMapCompassRing:GetFacing()
		for _, v in ipairs(directions) do
			local x, y = math.sin(v.rad + bearing), math.cos(v.rad + bearing)
			v:ClearAllPoints()
			v:SetPoint("CENTER", FarmHudMapCluster, "CENTER", x * v.radius, y * v.radius)
		end
	end
end

---------------------------------------------------------------------------------------------

-- INTERFACE OPTIONS

---------------------------------------------------------------------------------------------

local FarmHUD_Options = LibStub("LibSimpleOptions-1.0")
function FarmHud:CreateOptions()
	local panel = FarmHUD_Options.AddOptionsPanel("FarmHUD", function() end)
	local i,option_toggles = 1, {}

	local title, subText = panel:MakeTitleTextAndSubText("FarmHUD Addon", "General settings")

	local show_mounted = panel:MakeToggle(
			'name', 'Toggle FarmHUD when mounted',
			'description', 'This will enable FarmHUD when mounted and disable when unmounted. You\'ll be unable to toggle FarmHUD with /fh anymore.',
			'default', false,
			'getFunc', function() return FarmHudDB.show_mounted end,
			'setFunc', function(value) FarmHudDB.show_mounted = value end)
	show_mounted:SetPoint("TOPLEFT",subText,"BOTTOMLEFT", 10, -10)
	option_toggles[i] = show_mounted

	if FarmHUD_Options then

		-- directions NE SW etc...

		local directionOption = panel:MakeToggle(
				'name', 'Toggle Direction Showing',
				'description', 'Toggle to disable direction showing on the FarmHUD minimap.',
				'default', true,
				'getFunc', function() return FarmHudDB.enable_directions end,
				'setFunc', function(value) FarmHudDB.enable_directions = value
					FarmHud:SetScales()
				end)
		directionOption:SetPoint("TOPLEFT", option_toggles[i], "BOTTOMLEFT")
		i = i + 1
		option_toggles[i] = directionOption

		-- gather green circle

		local gatherCircleOption = panel:MakeToggle(
				'name', 'Toggle Gather Circle',
				'description', 'Show gather circle on the FarmHUD minimap.',
				'default', true,
				'getFunc', function() return FarmHudDB.show_gather_circle end,
				'setFunc', function(value)
					FarmHudDB.show_gather_circle = value
					FarmHud:SetScales()  -- Call the function to update scales immediately
				end)
		gatherCircleOption:SetPoint("TOPLEFT", option_toggles[i], "BOTTOMLEFT")
		i = i + 1
		option_toggles[i] = gatherCircleOption

	end


	if GatherMate then
		local gathermate = panel:MakeToggle(
				'name', 'Show Gathermate Nodes',
				'description', 'Show Gathermate Nodes',
				'default', true,
				'getFunc', function() return FarmHudDB.show_gathermate end,
				'setFunc', function(value)
					FarmHudDB.show_gathermate = value
				end)
		gathermate:SetPoint("TOPLEFT",option_toggles[i],"BOTTOMLEFT")
		i = i + 1
		option_toggles[i] = gathermate
	end

	if Gatherer then
		local gatherer = panel:MakeToggle(
				'name', 'Show Gatherer Nodes',
				'description', 'Show Gatherer Nodes',
				'default', true,
				'getFunc', function() return FarmHudDB.show_gatherer end,
				'setFunc', function(value) FarmHudDB.show_gatherer = value end)
		gatherer:SetPoint("TOPLEFT",option_toggles[i],"BOTTOMLEFT")
		i = i + 1
		option_toggles[i] = gatherer
	end

	if Routes then
		local routes = panel:MakeToggle(
				'name', 'Show Routes',
				'description', 'Show Routes',
				'default', true,
				'getFunc', function() return FarmHudDB.show_routes end,
				'setFunc', function(value) FarmHudDB.show_routes = value end)
		routes:SetPoint("TOPLEFT",option_toggles[i],"BOTTOMLEFT")
		i = i + 1
		option_toggles[i] = routes
	end

	local scaleSlider = panel:MakeSlider(
			'name', 'FarmHUD Scale',
			'description', 'Adjust the scale of FarmHUD on the minimap.',
			'minText', '0.5x',
			'maxText', '2x',
			'minValue', 0.5, -- Adjust these values
			'maxValue', 2.0, -- Adjust these values
			'step', 0.05,
			'default', 1.4,
			'getFunc', function() return FarmHudDB.fh_scale end,
			'setFunc', function(value)
				FarmHudDB.fh_scale = value
				FarmHud:SetScales() -- Update scales immediately
			end
	)

	scaleSlider:SetPoint("TOPLEFT", option_toggles[i], "BOTTOMLEFT", 0, -20)
	i = i + 1
	option_toggles[i] = scaleSlider


end

---------------------------------------------------------------------------------------------

-- EVENT HANDLERS

---------------------------------------------------------------------------------------------

function FarmHud:PLAYER_LOGIN()

	if not FarmHudDB then
		FarmHudDB = {}
	end

	if FarmHudDB then
		if FarmHudDB.fh_scale == nil then
			FarmHudDB.fh_scale = 1.4 -- Set a default scale value
		end

		-- FIXME: GatherMate Not persists through logout.

		if FarmHudDB.show_gathermate == nil then
			FarmHudDB.show_gathermate = true
		end

		if FarmHudDB.show_routes == nil then
			FarmHudDB.show_routes = true
		end

		if FarmHudDB.show_gatherer == nil then
			FarmHudDB.show_gatherer = true
		end

		if FarmHudDB.show_mounted == nil then
			FarmHudDB.show_mounted = false
		end

		if FarmHudDB.show_npcscan == nil then
			FarmHudDB.show_npcscan = true
		end
	end

	if LDBIcon then
		LDBIcon:Register("FarmHud", LDB, FarmHudDB.MinimapIcon)
	end

	FarmHudMinimap:SetPoint("CENTER", UIParent, "CENTER")
	FarmHudMapCluster:SetFrameStrata("BACKGROUND")
	FarmHudMapCluster:SetAlpha(0.7)
	FarmHudMinimap:SetAlpha(0)
	FarmHudMinimap:EnableMouse(false)

	setmetatable(FarmHudMapCluster, { __index = FarmHudMinimap })

	FarmHudMapCluster._GetScale = FarmHudMapCluster.GetScale
	FarmHudMapCluster.GetScale = function()
	return 1
	end

	gatherCircle = FarmHudMapCluster:CreateTexture()
	gatherCircle:SetTexture([[SPELLS\CIRCLE.BLP]])
	gatherCircle:SetBlendMode("ADD")
	gatherCircle:SetPoint("CENTER")
	local radius = FarmHudMinimap:GetWidth() * 0.45
	gatherCircle:SetWidth(radius)
	gatherCircle:SetHeight(radius)
	gatherCircle.alphaFactor = 0.5
	gatherCircle:SetVertexColor(0, 1, 0, 1 * (gatherCircle.alphaFactor or 1) / FarmHudMapCluster:GetAlpha())
	--gatherCircle:Hide()

	playerDot = FarmHudMapCluster:CreateTexture()
	playerDot:SetTexture([[Interface\GLUES\MODELS\UI_Tauren\gradientCircle.blp]])
	playerDot:SetBlendMode("ADD")
	playerDot:SetPoint("CENTER")
	playerDot.alphaFactor = 2
	playerDot:SetWidth(15)
	playerDot:SetHeight(15)

	radius = FarmHudMinimap:GetWidth() * 0.214
	for k, v in ipairs(indicators) do
		local rot = (0.785398163 * (k-1))
		local ind = FarmHudMapCluster:CreateFontString(nil, nil, "GameFontNormalSmall")
		local x, y = math.sin(rot), math.cos(rot)
		ind:SetPoint("CENTER", FarmHudMapCluster, "CENTER", x * radius, y * radius)
		ind:SetText(v)
		ind:SetShadowOffset(0.2,-0.2)
		ind.rad = rot
		ind.radius = radius
		tinsert(directions, ind)
	end

	FarmHud:SetScales()

	mousewarn = FarmHudMapCluster:CreateFontString(nil, nil, "GameFontNormalSmall")
	mousewarn:SetPoint("CENTER", FarmHudMapCluster, "CENTER", 0, FarmHudMapCluster:GetWidth()*.05)
	mousewarn:SetText("MOUSE ON")
	mousewarn:Hide()

	FarmHudMapCluster:Hide()
	FarmHudMapCluster:SetScript("OnShow", onShow)
	FarmHudMapCluster:SetScript("OnHide", onHide)
	FarmHud:CreateOptions()
	print("Loaded")
	print("Type '/fh' to toggle FarmHUD")
	print("You can find more options (like disabling GatherMate nodes) in the interface menu.")
end

function FarmHud:PLAYER_LOGOUT()
	FarmHud:Toggle(false)
end

---------------------------------------------------------------------------------------------

-- REGISTER EVENTS

---------------------------------------------------------------------------------------------

FarmHud:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)
FarmHud:RegisterEvent("PLAYER_LOGIN")
FarmHud:RegisterEvent("PLAYER_LOGOUT")

---------------------------------------------------------------------------------------------

-- ON UPDATE TOGGLE WHEN MOUNTED

---------------------------------------------------------------------------------------------

local FarmHUD_OnUpdate = CreateFrame("frame")
FarmHUD_OnUpdate.updateInterval = 0.1;
FarmHUD_OnUpdate.timeSinceLastUpdate = 0
FarmHUD_OnUpdate:SetScript("OnUpdate", function(self, elapsed)
	FarmHUD_OnUpdate.timeSinceLastUpdate = FarmHUD_OnUpdate.timeSinceLastUpdate + elapsed
	if (FarmHUD_OnUpdate.timeSinceLastUpdate > FarmHUD_OnUpdate.updateInterval) then
		if not IsModifierKeyDown() and FarmHudMapCluster:IsVisible() and MouseToggled == true and not MouseToggled == false then
			FarmHud:MouseToggle(false)
			MouseToggled = false
		end

		if FarmHudDB.show_mounted then
			if IsMounted() and not UnitOnTaxi("player") then
				FarmHud:Toggle(true)
			else
				FarmHud:Toggle(false)
			end
		end
		FarmHUD_OnUpdate.timeSinceLastUpdate = 0
	end
end)

---------------------------------------------------------------------------------------------

-- SLASH COMMAND

---------------------------------------------------------------------------------------------

SLASH_FARMHUD1 = "/fh";

local function FarmHudSlashCmd(msg)
	if msg == "" then
		FarmHud:Toggle()
	elseif msg == "mouse" then
		--FarmHud:MouseToggle()
		print("/fh mouse is longer a command. Please use any modifier key to toggle mouse.")
	end
end

SlashCmdList["FARMHUD"] = FarmHudSlashCmd;
