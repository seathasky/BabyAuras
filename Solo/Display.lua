local _, addon = ...

local Solo = addon.Solo
local Utilities = addon.SoloUtilities
local GetBarDimensions = Utilities.GetBarDimensions
local GetSoloBaseDimensions = Utilities.GetSoloBaseDimensions
local GetScreenCenter = Utilities.GetScreenCenter
local ScreenToUIParent = Utilities.ScreenToUIParent

local function OnDisplayDragUpdate(display)
    Solo:UpdateSnap(display)
    Solo:UpdateLinkedDrag(display)
end

function Solo:CreateDisplay(entry, item, copyIndex)
    local display = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    display.copyIndex = copyIndex == 2 and 2 or 1
    display.isSecondary = display.copyIndex == 2
    local isBar = item and self:IsTrackedBarItem(item) or false
    local width, height = GetSoloBaseDimensions(entry, item, isBar)
    display:SetSize(width, height)
    display.isBar = isBar
    display:SetFrameStrata("MEDIUM")
    display:SetMovable(true)
    display:SetClampedToScreen(true)
    display:RegisterForDrag("LeftButton")
    display:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    display:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
    })
    display.entry = entry

    local editOutline = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    editOutline:SetPoint("TOPLEFT", display, "TOPLEFT", -7, 7)
    editOutline:SetPoint("BOTTOMRIGHT", display, "BOTTOMRIGHT", 7, -7)
    editOutline:SetFrameStrata("MEDIUM")
    editOutline:SetFrameLevel(math.max(0, display:GetFrameLevel() - 1))
    editOutline:EnableMouse(false)
    editOutline:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
    })
    editOutline:SetBackdropColor(0.35, 0.82, 1, 0.08)
    editOutline:SetBackdropBorderColor(0.55, 0.9, 1, 0.55)
    editOutline:Hide()
    display.EditOutline = editOutline

    local icon = display:CreateTexture(nil, "ARTWORK")
    if isBar then
        local iconSize = GetBarDimensions(entry, item)
        icon:SetPoint("LEFT")
        icon:SetSize(iconSize, iconSize)
    else
        icon:SetAllPoints()
    end
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    display.Icon = icon

    if isBar then
        local _, barWidth, barHeight = GetBarDimensions(entry, item)
        local barBackground = CreateFrame("StatusBar", nil, display)
        barBackground:SetPoint("LEFT", icon, "RIGHT", 0, 0)
        barBackground:SetSize(barWidth, barHeight)
        barBackground:SetFrameLevel(display:GetFrameLevel() + 1)
        barBackground:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
        barBackground:SetStatusBarColor(0.35, 0.65, 1, 1)
        local barBase = barBackground:CreateTexture(nil, "BACKGROUND")
        barBase:SetAllPoints()
        barBase:SetColorTexture(0.08, 0.08, 0.1, 0.92)
        display.BarBackground = barBackground
        display.BarBase = barBase
        display.BarProgress = barBackground

        local barTextOverlay = CreateFrame("Frame", nil, display)
        barTextOverlay:SetAllPoints(barBackground)
        barTextOverlay:SetFrameLevel(display:GetFrameLevel() + 6)
        barTextOverlay:EnableMouse(false)
        display.BarTextOverlay = barTextOverlay

        local barName = barTextOverlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        barName:SetPoint("LEFT", barBackground, "LEFT", 5, 0)
        barName:SetPoint("RIGHT", barBackground, "RIGHT", -32, 0)
        barName:SetJustifyH("LEFT")
        display.BarName = barName

        local barDuration = barTextOverlay:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        barDuration:SetPoint("RIGHT", barBackground, "RIGHT", -6, 0)
        display.BarDuration = barDuration
    end

    local cooldown = CreateFrame("Cooldown", nil, display, "CooldownFrameTemplate")
    if isBar then
        cooldown:SetPoint("TOPLEFT", icon, "TOPLEFT")
        cooldown:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT")
    else
        cooldown:SetAllPoints()
    end
    -- Match Blizzard/CMC's normal cooldown direction. Aura-specific updates may
    -- override this later, but spell cooldowns must not inherit a reversed swipe.
    cooldown:SetReverse(false)
    cooldown:SetDrawEdge(false)
    cooldown:SetDrawBling(false)
    cooldown:SetHideCountdownNumbers(false)
    cooldown:SetUseAuraDisplayTime(true)
    display.Cooldown = cooldown

    local visualOverlay = CreateFrame("Frame", nil, display)
    visualOverlay:SetAllPoints()
    visualOverlay:SetFrameLevel(display:GetFrameLevel() + 5)
    display.VisualOverlay = visualOverlay

    local pixelBorder = CreateFrame("Frame", nil, display)
    if isBar then
        pixelBorder:SetAllPoints(icon)
    else
        pixelBorder:SetAllPoints()
    end
    pixelBorder:EnableMouse(false)
    pixelBorder:SetFrameLevel(display:GetFrameLevel() + 7)
    pixelBorder.edges = {}
    for index = 1, 4 do
        local edge = pixelBorder:CreateTexture(nil, "OVERLAY")
        edge:SetColorTexture(0, 0, 0, 1)
        pixelBorder.edges[index] = edge
    end
    display.PixelBorder = pixelBorder

    -- Native cooldown/stack FontStrings are reparented here while an item is
    -- hosted. This keeps Blizzard as the source of the live text while giving
    -- the text a BabyAuras-owned layer above the pixel border.
    local nativeTextOverlay = CreateFrame("Frame", nil, display)
    nativeTextOverlay:SetAllPoints()
    nativeTextOverlay:SetFrameLevel(display:GetFrameLevel() + 10)
    nativeTextOverlay:EnableMouse(false)
    display.NativeTextOverlay = nativeTextOverlay

    if DoesTemplateExist and DoesTemplateExist("ActionBarButtonSpellActivationAlert") then
        -- Blizzard's alert manager sizes its effect from the frame passed to
        -- ShowAlert, not from the alert child. Give tracked bars a dedicated
        -- icon-sized target; custom Pixel/Extended glows still use `display`.
        local procTarget = display
        if isBar then
            procTarget = CreateFrame("Frame", nil, display)
            procTarget:SetAllPoints(display.Icon)
            procTarget:SetFrameLevel(display:GetFrameLevel() + 7)
            procTarget:EnableMouse(false)
            display.ProcGlowTarget = procTarget
        end
        local procAlert = CreateFrame("Frame", nil, procTarget, "ActionBarButtonSpellActivationAlert")
        procAlert:SetAllPoints(procTarget)
        procAlert:SetFrameLevel(display:GetFrameLevel() + 8)
        procAlert:Hide()
        procTarget.SpellActivationAlert = procAlert
        display.SpellActivationAlert = procAlert
    end

    local badgeFrame = CreateFrame("Frame", nil, display)
    badgeFrame:SetSize(15, 15)
    badgeFrame:SetPoint("TOPLEFT", display, "TOPLEFT", -4, 4)
    badgeFrame:SetFrameLevel(display:GetFrameLevel() + 12)
    badgeFrame:EnableMouse(false)
    display.BadgeFrame = badgeFrame

    local badge = badgeFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    badge:SetSize(15, 15)
    badge:SetAllPoints()
    badge:SetTexture("Interface\\AddOns\\BabyAuras\\Media\\Images\\ba.png")
    display.Badge = badge

    local badgeLetter = badgeFrame:CreateFontString(nil, "OVERLAY")
    badgeLetter:SetFont(STANDARD_TEXT_FONT, 12, "THICKOUTLINE")
    badgeLetter:SetPoint("CENTER", badgeFrame, "CENTER", 0, 0)
    badgeLetter:SetText(display.isSecondary and "2" or "B")
    badgeLetter:SetTextColor(0.20, 0.72, 1, 1)
    display.BadgeLetter = badgeLetter

    local stackMover = self:CreateTextMover(display, "soloStackPosition", "Stacks")
    local count = stackMover:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("CENTER")
    count:SetText("")
    display.Count = count
    local stackPreview = stackMover:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    stackPreview:SetPoint("CENTER")
    stackPreview:SetText("3")
    stackPreview:Hide()
    display.StackPreview = stackPreview
    display.StackMover = stackMover

    local cooldownMover = self:CreateTextMover(display, "soloCooldownPosition", "Cooldown")
    local cooldownPreview = cooldownMover:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    cooldownPreview:SetPoint("CENTER")
    cooldownPreview:SetText("12")
    cooldownPreview:Hide()
    display.CooldownPreview = cooldownPreview
    display.CooldownMover = cooldownMover

    local hotkeyMover = self:CreateTextMover(display, "soloHotkeyPosition", "Hotkey")
    local hotkey = hotkeyMover:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    hotkey:SetPoint("CENTER")
    hotkey:SetText("")
    display.Hotkey = hotkey
    display.HotkeyMover = hotkeyMover
    display.TextMovers = { stackMover, cooldownMover, hotkeyMover }

    display.entry = entry
    display.active = false
    display.activeState = false
    self:ApplyDisplayScale(display)
    self:ApplyTextLayout(display)

    display:SetScript("OnDragStart", function(self)
        if Solo:IsPositioningMode() and not Solo:IsLinkMode() and not InCombatLockdown() then
            Solo:ClearSnap(self)
            if not self.isSecondary then Solo:BeginLinkedDrag(self) end
            self:StartMoving()
            self.isDragging = true
            self.wasDragged = true
            self:SetScript("OnUpdate", OnDisplayDragUpdate)
        end
    end)
    display:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:StopMovingOrSizing()
        self.isDragging = nil
        local screenX, screenY = GetScreenCenter(self)
        local centerX, centerY = ScreenToUIParent(screenX, screenY)
        local snapX, snapY = ScreenToUIParent(self.snapX, self.snapY)
        local rootX, rootY = UIParent:GetCenter()
        if centerX and centerY and rootX and rootY and (snapX or snapY) then
            local scale = self:GetScale()
            if not scale or scale == 0 then scale = 1 end
            self:ClearAllPoints()
            self:SetPoint(
                "CENTER", UIParent, "CENTER",
                ((snapX or centerX) - rootX) / scale,
                ((snapY or centerY) - rootY) / scale
            )
        end
        Solo:SaveDisplayPosition(self)
        if not self.isSecondary then Solo:FinishLinkedDrag(self) end
        Solo:ClearSnap(self)
        C_Timer.After(0, function() self.wasDragged = nil end)
    end)
    display:SetScript("OnClick", function(self, button)
        if self.wasDragged or not Solo:IsPositioningMode() then return end
        if not self.isSecondary and button == "RightButton" and Solo:UnlinkDisplay(self) then return end
        if button ~= "LeftButton" then return end
        if not self.isSecondary and Solo:ToggleLinkSelection(self) then return end
        if addon.GUI then addon.GUI:OpenEntry(self.entry) end
    end)
    display:SetScript("OnEnter", function(self)
        if BabyAurasDB and BabyAurasDB.hideSoloTooltips then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.entry.name)
        GameTooltip:AddLine(self.isSecondary and "Baby Auras secondary Solo display"
            or "Baby Auras Solo display", 0.3, 0.85, 1)
        if Solo:IsPositioningMode() then
            GameTooltip:AddLine("Drag to move | Click to configure", 0.75, 0.85, 1)
        end
        GameTooltip:Show()
    end)
    display:SetScript("OnLeave", GameTooltip_Hide)

    local key = self.GetDisplayKey and self:GetDisplayKey(entry.cooldownID, display.copyIndex)
        or entry.cooldownID
    self.displays[key] = display
    self:ApplyDisplayPosition(display)
    return display
end
