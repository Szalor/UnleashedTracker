local _, class = UnitClass("player")
if class ~= "WARLOCK" then return end

--------------------------------------------------
--  STATE
--------------------------------------------------
local playerName    = UnitName("player")
local currentStacks = 0
local upTimer       = 0
local upDuration    = 20
local timerActive   = false

local checkTimer 	= 0
local funnelActive = false      -- true while channeling Health Funnel
local funnelTickElapsed = 0     -- time accumulator for 1s simulated ticks

local iconLocked = false

-- Function to check if Unleashed Potential is talented
local function HasUnleashedPotential()
    local numTabs = GetNumTalentTabs()
    for t = 1, numTabs do
        local numTalents = GetNumTalents(t)
        for i = 1, numTalents do
            local name, iconTexture, tier, column, rank, maxRank = GetTalentInfo(t, i)
            if name == "Unleashed Potential" and rank > 0 then
                return true
            end
        end
    end
    return false
end

--------------------------------------------------
--  DISPLAY FRAME (UI)
--------------------------------------------------
local warningFrame = CreateFrame("Button", "UPWarningFrame", UIParent)
warningFrame:SetPoint("CENTER", UIParent, "CENTER")
warningFrame:SetFrameStrata("HIGH")

-- 🔹 Icon
local icon = warningFrame:CreateTexture(nil, "OVERLAY")
icon:SetAllPoints(warningFrame)
icon:SetTexture("Interface\\Icons\\Ability_Warlock_DemonicPower") -- UP icon
icon:SetDesaturated(true)

-- 🔹 Stack text (above icon)
local stackText = warningFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
stackText:SetPoint("BOTTOM", warningFrame, "TOP", 0, 4)
stackText:SetFont("Fonts\\FRIZQT__.TTF", 18, "THICKOUTLINE") -- bold with thick black outline
stackText:SetTextColor(0.8, 0.9, 1)
stackText:SetText("")

-- 🔹 Timer text (center of icon)
local timerText = warningFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
timerText:SetPoint("CENTER", warningFrame, "CENTER", 0, 0)
timerText:SetFont("Fonts\\FRIZQT__.TTF", 16, "THICKOUTLINE") -- bold with thick black outline
timerText:SetTextColor(1, 1, 1)
timerText:SetText("")

--------------------------------------------------
--  DISPLAY HELPERS
--------------------------------------------------
local function UpdateDisplay()
    if currentStacks > 0 then
        icon:SetDesaturated(false)
        icon:Show()
        stackText:SetText(tostring(currentStacks))  -- show only number
        stackText:Show()
		timerText:Show()
    else
        icon:SetDesaturated(true)
		if iconLocked then icon:Hide() end
        stackText:Hide()
        timerText:Hide()
    end
end

local function ActivateOrRefreshUP(stacks)
    if stacks then
        currentStacks = tonumber(stacks) or currentStacks
    end
    if currentStacks > 3 then currentStacks = 3 end

    -- ALWAYS refresh the timer, even at max stacks
    upTimer = upDuration
    timerActive = true

    UpdateDisplay()
end

--------------------------------------------------
--  SAVED VARIABLES
--------------------------------------------------
-- Function to save frame's data
local function Save()
    local point, _, relativePoint, xOfs, yOfs = warningFrame:GetPoint()
	local size = warningFrame:GetWidth()
    UnleashedPotentialDB.point = point
    UnleashedPotentialDB.relativePoint = relativePoint
    UnleashedPotentialDB.xOfs = xOfs
    UnleashedPotentialDB.yOfs = yOfs
	UnleashedPotentialDB.iconLocked = iconLocked
	UnleashedPotentialDB.size = size
end

-- Function to load frame's data
local function Load()
	-- Declare a table for saved data
	UnleashedPotentialDB = UnleashedPotentialDB or {}
	
    if UnleashedPotentialDB.point then
        warningFrame:ClearAllPoints()
        warningFrame:SetPoint(
            UnleashedPotentialDB.point,
            UIParent,
            UnleashedPotentialDB.relativePoint,
            UnleashedPotentialDB.xOfs,
            UnleashedPotentialDB.yOfs
        )
    else
        warningFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
	
	if UnleashedPotentialDB.size then
		warningFrame:SetWidth(UnleashedPotentialDB.size)
		warningFrame:SetHeight(UnleashedPotentialDB.size)
		stackText:SetFont("Fonts\\FRIZQT__.TTF", math.floor(16 * UnleashedPotentialDB.size / 40)+2, "THICKOUTLINE")
		timerText:SetFont("Fonts\\FRIZQT__.TTF", math.floor(16 * UnleashedPotentialDB.size / 40), "THICKOUTLINE")
	else
		warningFrame:SetWidth(40)
		warningFrame:SetHeight(40)
		stackText:SetFont("Fonts\\FRIZQT__.TTF", 18, "THICKOUTLINE")
		timerText:SetFont("Fonts\\FRIZQT__.TTF", 16, "THICKOUTLINE")
	end
	
	iconLocked = UnleashedPotentialDB.iconLocked or false
	warningFrame:EnableMouse(not iconLocked)
	warningFrame:SetMovable(not iconLocked)		
	warningFrame:EnableMouseWheel(not iconLocked)
end

--------------------------------------------------
--  MOVEMENT / SLASH CMD
--------------------------------------------------
warningFrame:SetMovable(true)
warningFrame:EnableMouse(true)
warningFrame:RegisterForClicks("LeftButtonUp", "RightButtonUp")
warningFrame:EnableMouseWheel(true)

warningFrame:SetScript("OnMouseDown", function()
    if IsShiftKeyDown() then
        warningFrame:StartMoving()
    end
end)

warningFrame:SetScript("OnMouseUp", function()
    warningFrame:StopMovingOrSizing()
	Save()
end)

warningFrame:SetScript("OnMouseWheel", function()
    if IsShiftKeyDown() then
        -- Current size
        local size = warningFrame:GetWidth()

        -- Adjust size by delta arg1
        local newSize = math.max(20, math.min(200, size + arg1 * 5))  -- min 20, max 200
		local scale = newSize / 40
		local fontSize = math.floor(16 * scale)

        -- Apply to both width and height
        warningFrame:SetWidth(newSize)
		warningFrame:SetHeight(newSize)
		
		stackText:SetFont("Fonts\\FRIZQT__.TTF", fontSize+2, "THICKOUTLINE")
		timerText:SetFont("Fonts\\FRIZQT__.TTF", fontSize, "THICKOUTLINE")
    end
	Save()
end)

SLASH_LOCKUP1 = "/unleashed"
SlashCmdList["LOCKUP"] = function()
	iconLocked = not iconLocked
	warningFrame:EnableMouse(not iconLocked)
    warningFrame:SetMovable(not iconLocked)
	warningFrame:EnableMouseWheel(not iconLocked)
	if iconLocked then
		icon:Hide()
	else
		icon:Show()
	end
    Save()
	
    if iconLocked then
        DEFAULT_CHAT_FRAME:AddMessage("Unleashed Potential Tracker: Icon locked.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("Unleashed Potential Tracker: Icon unlocked. Hold Shift + Drag to move. Hold Shift + Scroll Wheel to resize.")
    end
end

--------------------------------------------------
--  RESTORE POSITION ON LOGIN / RELOAD
--------------------------------------------------
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function()
    Load()
end)

--------------------------------------------------
--  LOGIC FRAME (EVENTS)
--------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("CHARACTER_POINTS_CHANGED")
frame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
frame:RegisterEvent("UNIT_PET")
frame:RegisterEvent("UNIT_AURA") -- needed for funnels' stop channel detection
frame:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

local function CheckFunnel()
    if not UnitExists("pet") or UnitIsDead("pet") or currentStacks==0 then
        funnelActive = false
        return
    end

    local funnelFound = false
    for i = 1, 32 do
        local texture = UnitBuff("pet", i)
        if texture and (string.find(texture, "Spell_Shadow_LifeDrain") or string.find(texture, "Spell_Shadow_UnsummonBuilding")) then
            funnelFound = true
            break
        end
    end

    if funnelFound then
		funnelActive = true
    else
		funnelActive = false
		funnelTickElapsed = 0
    end
end

frame:SetScript("OnEvent", function()
	if HasUnleashedPotential() and UnitExists("pet") and not UnitIsDead("pet") and UnitName("pet")~="Unknown" then
		local msg = arg1
		if not msg then return end
		
		if event == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS" then 
			-- rely on logs to gain an accurate number of UP stacks
			local s, e, demonName, warlockName, stacks = string.find(msg, "(.+)%s%((.+)%) gains Unleashed Potential %((%d)%)")
			if s and warlockName == playerName and stacks then
				ActivateOrRefreshUP(stacks)
				return
			end
		end
		
		-- 🟣 Critical spell hit refresh once already at 3 stacks and no more logs
		if event == "CHAT_MSG_SPELL_SELF_DAMAGE" and string.find(msg, "^Your .- crits ") and not string.find(msg, "Shoot") then
			ActivateOrRefreshUP(currentStacks)
			return
		end
		
		if event == "UNIT_AURA" and msg == "pet" then
			CheckFunnel() 
		end
	else
		currentStacks = 0
		UpdateDisplay()
	end
end)

--------------------------------------------------
--  ONUPDATE TIMER (text countdown)
--------------------------------------------------
warningFrame:SetScript("OnUpdate", function()
    if timerActive then
        upTimer = upTimer - arg1 -- arg1 is delta time in 1.12/SuperWoW
        if upTimer > 0 then
            timerText:SetText(string.format("%.1f", upTimer))
        else
            currentStacks = 0
            timerActive = false
            UpdateDisplay()
        end
    end
	
	if funnelActive then
		funnelTickElapsed = funnelTickElapsed + arg1
		if funnelTickElapsed >= 1 then  -- 1 second per tick
			funnelTickElapsed = funnelTickElapsed - 1
			ActivateOrRefreshUP(currentStacks)
		end
	end
end)

