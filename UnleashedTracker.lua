local _, class = UnitClass("player")
if class ~= "WARLOCK" then return end

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
--  STATE
--------------------------------------------------
-- Declare a table for saved data
UnleashedPotentialDB = UnleashedPotentialDB or {}

local playerName    = UnitName("player")
local currentStacks = 0
local upTimer       = 0
local upDuration    = 20
local timerActive   = false

local checkTimer 	= 0
local funnelActive = false      -- true while channeling Health Funnel
local funnelTickElapsed = 0     -- time accumulator for 1s simulated ticks

local iconLocked = UnleashedPotentialDB.iconLocked or false

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
icon:Hide()

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
        icon:Hide()
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
    UnleashedPotentialDB.point = point
    UnleashedPotentialDB.relativePoint = relativePoint
    UnleashedPotentialDB.xOfs = xOfs
    UnleashedPotentialDB.yOfs = yOfs
	UnleashedPotentialDB.iconLocked = iconLocked
end

-- Function to load frame's data
local function Load()
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
	
	local size = UnleashedPotentialDB.size or 40
	local fontSize = UnleashedPotentialDB.size or 16
	warningFrame:SetWidth(size)
	warningFrame:SetHeight(size)
	
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

        -- Save to DB
        UnleashedPotentialDB.size = newSize
    end
end)

SLASH_LOCKUP1 = "/unleashed"
SlashCmdList["LOCKUP"] = function()
	iconLocked = not iconLocked
	warningFrame:EnableMouse(not iconLocked)
    warningFrame:SetMovable(not iconLocked)
	warningFrame:EnableMouseWheel(not iconLocked)
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
frame:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
frame:RegisterEvent("UNIT_AURA")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("CHARACTER_POINTS_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

local function CheckFunnel()
    if not UnitExists("pet") or UnitIsDead("pet") then
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
        if not funnelActive then
            funnelActive = true
            funnelTickElapsed = 0
        end
    else
        if funnelActive then
            funnelActive = false
            funnelTickElapsed = 0
        end
    end
end

frame:SetScript("OnEvent", function(self, event)
	if HasUnleashedPotential() and UnitExists("pet") then
		local msg = arg1
		if not msg then return end
		-- 🟣 Critical spell hit refresh/increment
		if string.find(msg, "^Your .- crits ") then
			if currentStacks < 3 then
				currentStacks = currentStacks + 1
			end
			ActivateOrRefreshUP(currentStacks)
			return
		end
		
		CheckFunnel()
	else
		currentStacks = 0
		UpdateDisplay()
	end
end)

--------------------------------------------------
--  ONUPDATE TIMER (text countdown)
--------------------------------------------------
warningFrame:SetScript("OnUpdate", function(self)
    if timerActive then
        upTimer = upTimer - arg1 -- arg1 is delta time in 1.12/SuperWoW
        if upTimer > 0 then
            timerText:SetText(string.format("%.1f", upTimer))
        else
            currentStacks = 0
            timerActive = false
            upTimer = 0
            timerText:SetText("")
            UpdateDisplay()
        end
    end
	
	if funnelActive then
		funnelTickElapsed = funnelTickElapsed + arg1
		if funnelTickElapsed >= 1 then  -- 1 second per tick
			funnelTickElapsed = funnelTickElapsed - 1
			if currentStacks > 0 then
				ActivateOrRefreshUP(currentStacks)
			end
		end
	end
end)

