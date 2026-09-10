local _, addon = ...

local Solo = addon.Solo
local Defaults = addon.Defaults
local SharedMedia = LibStub and LibStub("LibSharedMedia-3.0", true)
local Utilities = addon.SoloUtilities
local GetEntryAppearance = Utilities.GetEntryAppearance
local GetBarDimensions = Utilities.GetBarDimensions
local GetSoloBaseDimensions = Utilities.GetSoloBaseDimensions
local GetTextColor = Utilities.GetTextColor

local function GetDefaultTextPosition(display, key)
    local width, height = display:GetWidth(), display:GetHeight()
    local iconWidth = display.isBar and height or width
    local iconCenterX = display.isBar and ((-width + iconWidth) / 2) or 0
    if key == "soloStackPosition" then
        return iconCenterX + (iconWidth / 2) - 7, (-height / 2) + 7
    elseif key == "soloHotkeyPosition" then
        return iconCenterX + (iconWidth / 2) - 10, (height / 2) - 7
    end
    return iconCenterX, 0
end

function Solo:ApplyTextMoverPosition(display, mover)
    local settings = GetEntryAppearance(display.entry)
    local position = settings[mover.positionKey]
    local x, y
    if type(position) == "table" then
        x, y = tonumber(position.x), tonumber(position.y)
    end
    if display.isBar then
        local iconWidth, iconHeight = display.Icon:GetWidth(), display.Icon:GetHeight()
        if not x or not y then
            if mover.positionKey == "soloStackPosition" then
                x, y = (iconWidth / 2) - 7, (-iconHeight / 2) + 7
            elseif mover.positionKey == "soloHotkeyPosition" then
                x, y = (iconWidth / 2) - 10, (iconHeight / 2) - 7
            else
                x, y = 0, 0
            end
        end
        mover:ClearAllPoints()
        mover:SetPoint("CENTER", display.Icon, "CENTER", x, y)
        return
    end
    if not x or not y then x, y = GetDefaultTextPosition(display, mover.positionKey) end
    mover:ClearAllPoints()
    mover:SetPoint("CENTER", display, "CENTER", x, y)
end

function Solo:CreateTextMover(display, positionKey, placeholderText)
    local mover = CreateFrame("Frame", nil, display)
    mover:SetSize(48, 22)
    mover:SetFrameLevel(display:GetFrameLevel() + 10)
    mover.positionKey = positionKey
    self:ApplyTextMoverPosition(display, mover)
    return mover
end

function Solo:GetTextPosition(entry, positionKey)
    local settings = GetEntryAppearance(entry)
    local position = settings[positionKey]
    if type(position) == "table" and tonumber(position.x) and tonumber(position.y) then
        return tonumber(position.x), tonumber(position.y)
    end
    local display = entry and self.displays[entry.cooldownID]
    if display then
        if display.isBar then
            local iconWidth, iconHeight = display.Icon:GetWidth(), display.Icon:GetHeight()
            if positionKey == "soloStackPosition" then
                return (iconWidth / 2) - 7, (-iconHeight / 2) + 7
            elseif positionKey == "soloHotkeyPosition" then
                return (iconWidth / 2) - 10, (iconHeight / 2) - 7
            end
            return 0, 0
        end
        return GetDefaultTextPosition(display, positionKey)
    end
    local item = entry and addon.Runtime and addon.Runtime:GetLiveItem(entry.cooldownID)
    local isBar = item and self:IsTrackedBarItem(item) or false
    local width, height = GetSoloBaseDimensions(entry, item, isBar)
    local dimensions = {
        isBar = isBar,
        GetWidth = function() return width end,
        GetHeight = function() return height end,
    }
    if isBar then
        local iconSize = GetBarDimensions(entry, item)
        if positionKey == "soloStackPosition" then
            return (iconSize / 2) - 7, (-iconSize / 2) + 7
        elseif positionKey == "soloHotkeyPosition" then
            return (iconSize / 2) - 10, (iconSize / 2) - 7
        end
        return 0, 0
    end
    return GetDefaultTextPosition(dimensions, positionKey)
end

function Solo:SetTextPosition(entry, positionKey, x, y)
    local settings = addon:GetEntrySettings(entry.cooldownID, true)
    settings[positionKey] = {
        x = Clamp(math.floor((tonumber(x) or 0) + 0.5), -500, 500),
        y = Clamp(math.floor((tonumber(y) or 0) + 0.5), -500, 500),
    }
    local display = self.displays[entry.cooldownID]
    if display then self:ApplyTextLayout(display) end
end


local function GetNativeStackFontString(item)
    if not item then return nil end
    if item.Applications and item.Applications.Applications then
        return item.Applications.Applications
    end
    if item.Icon and item.Icon.Applications then
        return item.Icon.Applications
    end
    if item.ChargeCount and item.ChargeCount.Current then
        return item.ChargeCount.Current
    end
    return item.count
end

local function GetNativeCooldownFontString(item)
    local cooldown = item and item.Cooldown
    if not cooldown or type(cooldown.GetCountdownFontString) ~= "function" then return nil end
    local ok, text = pcall(cooldown.GetCountdownFontString, cooldown)
    return ok and text or nil
end

local hookedNativeCooldowns = setmetatable({}, { __mode = "k" })

local function QueueNativeTextRefresh(item)
    local state = Solo.nativeHostStates and Solo.nativeHostStates[item]
    if not state or state.applyingText or state.textRefreshPending or Solo.suspended then return end
    state.textRefreshPending = true
    C_Timer.After(0, function()
        state.textRefreshPending = nil
        local hostState = Solo.nativeHostStates and Solo.nativeHostStates[item]
        local display = hostState and hostState.display
        if hostState == state and display and display.NativeItem == item and not Solo.suspended then
            Solo:ApplyTextLayout(display)
        end
    end)
end

local function EnsureNativeCooldownTextHooks(item)
    local cooldown = item and item.Cooldown
    if not cooldown or hookedNativeCooldowns[cooldown] then return end
    hookedNativeCooldowns[cooldown] = true

    -- Blizzard creates the countdown FontString lazily when its native Cooldown
    -- widget receives timer data. Reapply presentation after that exact update;
    -- deliberately ignore all arguments because cooldown values may be secret.
    for _, method in ipairs({ "SetCooldown", "SetCooldownFromDurationObject",
        "SetCooldownDuration", "SetCooldownUNIX", "SetCountdownFont", "SetHideCountdownNumbers" }) do
        if type(cooldown[method]) == "function" then
            hooksecurefunc(cooldown, method, function()
                QueueNativeTextRefresh(item)
            end)
        end
    end
end

local function SaveNativeFontState(hostState, key, fontString)
    if not hostState or not fontString then return nil end
    hostState.textDefaults = hostState.textDefaults or {}
    if hostState.textDefaults[key] then return hostState.textDefaults[key] end
    local saved = { region = fontString, points = {} }
    pcall(function()
        saved.parent = fontString:GetParent()
        saved.drawLayer = { fontString:GetDrawLayer() }
        saved.font = { fontString:GetFont() }
        saved.color = { fontString:GetTextColor() }
        saved.alpha = fontString:GetAlpha()
        for i = 1, fontString:GetNumPoints() do
            saved.points[#saved.points + 1] = { fontString:GetPoint(i) }
        end
    end)
    hostState.textDefaults[key] = saved
    return saved
end

local function HostNativeText(display, saved, fontString)
    if not saved or not fontString then return end
    pcall(function()
        -- Keep native text with its owning widget. Moving it into our shell
        -- disconnects it from Blizzard's hide/reset/reuse lifecycle.
        if saved.parent and fontString:GetParent() ~= saved.parent then fontString:SetParent(saved.parent) end
        fontString:SetDrawLayer("OVERLAY", 7)
    end)
end

local function ApplyNativeTextLayout(self, display, stackSize, cooldownSize, fontPath,
        stackR, stackG, stackB, stackA, cooldownR, cooldownG, cooldownB, cooldownA)
    local item = display and display.NativeItem
    if not item then return end
    local hostState = self.nativeHostStates and self.nativeHostStates[item]
    if not hostState then return end
    EnsureNativeCooldownTextHooks(item)
    local settings = GetEntryAppearance(display.entry)
    if item.Cooldown then
        pcall(item.Cooldown.SetHideCountdownNumbers, item.Cooldown, settings.soloShowNumbers == false)
    end

    -- These are Blizzard-owned FontStrings, but changing font/anchor properties is
    -- the same presentation-only technique used by CMC. We never copy or inspect
    -- Blizzard's secret cooldown/aura values.
    local stackText = GetNativeStackFontString(item)
    if stackText then
        local saved = SaveNativeFontState(hostState, "stack", stackText)
        HostNativeText(display, saved, stackText)
        pcall(stackText.SetFont, stackText, fontPath or STANDARD_TEXT_FONT, stackSize, "OUTLINE")
        pcall(stackText.SetTextColor, stackText, stackR, stackG, stackB, stackA)
        pcall(stackText.SetAlpha, stackText, settings.soloShowStacks == true and 1 or 0)
        local position = settings.soloStackPosition
        if type(position) == "table" and tonumber(position.x) and tonumber(position.y) then
            pcall(function()
                stackText:ClearAllPoints()
                stackText:SetPoint("CENTER", item, "CENTER", tonumber(position.x), tonumber(position.y))
            end)
        end
    end

    local cooldownText = GetNativeCooldownFontString(item)
    if not cooldownText and settings.soloShowNumbers ~= false then
        -- Cooldown's countdown FontString is created lazily by Blizzard. If this
        -- appearance pass lands before that creation, retry after Blizzard's
        -- cooldown update has settled instead of waiting for a UI reload. Keep
        -- one bounded retry batch per hosted item so an idle cooldown cannot
        -- create a perpetual timer loop.
        if not hostState.cooldownTextRetryPending then
            hostState.cooldownTextRetryPending = true
            for index, delay in ipairs({ 0.05, 0.25, 1.00 }) do
                local finalRetry = index == 3
                C_Timer.After(delay, function()
                    local current = Solo.nativeHostStates and Solo.nativeHostStates[item]
                    if current ~= hostState or current.display ~= display
                        or display.NativeItem ~= item or Solo.suspended then return end
                    Solo:ApplyTextLayout(display)
                    if finalRetry then
                        current.cooldownTextRetryPending = nil
                    end
                end)
            end
        end
    elseif cooldownText then
        hostState.cooldownTextRetryPending = nil
        local saved = SaveNativeFontState(hostState, "cooldown", cooldownText)
        HostNativeText(display, saved, cooldownText)
        pcall(cooldownText.SetFont, cooldownText, fontPath or STANDARD_TEXT_FONT, cooldownSize, "OUTLINE")
        pcall(cooldownText.SetTextColor, cooldownText, cooldownR, cooldownG, cooldownB, cooldownA)
        pcall(cooldownText.SetAlpha, cooldownText, settings.soloShowNumbers == false and 0 or 1)
        local position = settings.soloCooldownPosition
        if type(position) == "table" and tonumber(position.x) and tonumber(position.y) then
            pcall(function()
                cooldownText:ClearAllPoints()
                cooldownText:SetPoint("CENTER", item.Cooldown, "CENTER", tonumber(position.x), tonumber(position.y))
            end)
        end
    end
end

function Solo:ApplyNativeTextLayout(display, ...)
    local item = display and display.NativeItem
    local state = item and self.nativeHostStates and self.nativeHostStates[item]
    if not state or state.applyingText then return end
    state.applyingText = true
    local ok, err = pcall(ApplyNativeTextLayout, self, display, ...)
    state.applyingText = nil
    if not ok then error(err, 0) end
end

local function FindCooldownText(frame, depth)
    if not frame or (depth or 0) > 3 then return nil end
    local ok, regions = pcall(function() return { frame:GetRegions() } end)
    if ok then
        for _, region in ipairs(regions) do
            if region.IsObjectType and region:IsObjectType("FontString") then return region end
        end
    end
    local childrenOK, children = pcall(function() return { frame:GetChildren() } end)
    if childrenOK then
        for _, child in ipairs(children) do
            local text = FindCooldownText(child, (depth or 0) + 1)
            if text then return text end
        end
    end
    return nil
end

function Solo:ApplyCooldownTextLayout(display, size, x, y)
    local cooldown = display.LiveCooldown or display.Cooldown
    if not cooldown then return end
    local settings = GetEntryAppearance(display.entry)
    local fontNameSetting = settings.soloFont or Defaults.soloAppearance.font
    local fontPath = SharedMedia and SharedMedia:Fetch("font", fontNameSetting) or STANDARD_TEXT_FONT
    local mediaKey = tostring(fontNameSetting or "Default"):gsub("[^%w]", "")
    local fontName = "BabyAurasCooldownFont"
        .. tostring(display.entry.cooldownID):gsub("[^%w]", "") .. mediaKey .. tostring(size)
    local font = _G[fontName] or CreateFont(fontName)
    pcall(font.SetFont, font, fontPath or STANDARD_TEXT_FONT, size, "OUTLINE")
    if type(cooldown.SetCountdownFont) == "function" then
        pcall(cooldown.SetCountdownFont, cooldown, fontName)
    end
    local text
    if type(cooldown.GetCountdownFontString) == "function" then
        local ok, countdownString = pcall(cooldown.GetCountdownFontString, cooldown)
        if ok then text = countdownString end
    end
    text = text or FindCooldownText(cooldown)
    if not text then return end
    pcall(function()
        local r, g, b, a = GetTextColor(settings, "soloCooldownColor", "cooldownColor")
        text:SetFont(fontPath or STANDARD_TEXT_FONT, size, "OUTLINE")
        text:SetTextColor(r, g, b, a)
        text:ClearAllPoints()
        text:SetPoint("CENTER", display.isBar and display.Icon or display, "CENTER", x, y)
    end)
end

function Solo:ApplyTextLayout(display)
    if not display or not display.StackMover then return end
    local settings = GetEntryAppearance(display.entry)
    for _, mover in ipairs(display.TextMovers) do self:ApplyTextMoverPosition(display, mover) end
    local stackSize = Clamp(math.floor(tonumber(settings.soloStackFontSize) or Defaults.soloAppearance.stackFontSize), 8, 32)
    local cooldownSize = Clamp(math.floor(tonumber(settings.soloCooldownFontSize) or Defaults.soloAppearance.cooldownFontSize), 8, 32)
    local hotkeySize = Clamp(math.floor(tonumber(settings.soloHotkeyFontSize) or Defaults.soloAppearance.hotkeyFontSize), 8, 32)
    local fontNameSetting = settings.soloFont or Defaults.soloAppearance.font
    local fontPath = SharedMedia and SharedMedia:Fetch("font", fontNameSetting) or STANDARD_TEXT_FONT
    fontPath = fontPath or STANDARD_TEXT_FONT
    local stackR, stackG, stackB, stackA = GetTextColor(settings, "soloStackColor", "stackColor")
    local cooldownR, cooldownG, cooldownB, cooldownA = GetTextColor(settings, "soloCooldownColor", "cooldownColor")
    local hotkeyR, hotkeyG, hotkeyB, hotkeyA = GetTextColor(settings, "soloHotkeyColor", "hotkeyColor")
    display.Count:SetFont(fontPath, stackSize, "OUTLINE")
    display.StackPreview:SetFont(fontPath, stackSize, "OUTLINE")
    display.CooldownPreview:SetFont(fontPath, cooldownSize, "OUTLINE")
    display.Hotkey:SetFont(fontPath, hotkeySize, "OUTLINE")
    display.Count:SetTextColor(stackR, stackG, stackB, stackA)
    display.StackPreview:SetTextColor(stackR, stackG, stackB, stackA)
    display.CooldownPreview:SetTextColor(cooldownR, cooldownG, cooldownB, cooldownA)
    display.Hotkey:SetTextColor(hotkeyR, hotkeyG, hotkeyB, hotkeyA)
    display.Hotkey:SetText(settings.soloHotkey or Defaults.soloAppearance.hotkey)
    if display.NativeItem then
        self:ApplyNativeTextLayout(display, stackSize, cooldownSize, fontPath,
            stackR, stackG, stackB, stackA, cooldownR, cooldownG, cooldownB, cooldownA)
    end
    local x, y = GetDefaultTextPosition(display, "soloCooldownPosition")
    local saved = settings.soloCooldownPosition
    if type(saved) == "table" then
        x = tonumber(saved.x) or x
        y = tonumber(saved.y) or y
    end
    self:ApplyCooldownTextLayout(display, cooldownSize, x, y)
end
