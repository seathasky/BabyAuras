local _, addon = ...

local Solo = addon.Solo
local Defaults = addon.Defaults
local GetBarDimensions = addon.SoloUtilities.GetBarDimensions

function Solo:GetScale(entry, copyIndex)
    local settings = entry and addon:GetEntrySettings(entry.cooldownID, false)
    local value = copyIndex == 2 and settings and settings.secondarySoloScale
        or settings and settings.soloScale
    return Clamp(tonumber(value) or Defaults.soloScale, 50, 200) / 100
end

function Solo:ApplyDisplayScale(display)
    display:SetScale(self:GetScale(display.entry, display.copyIndex))
    if display.NativeItem then self:PositionNativeItem(display.NativeItem, display) end
end

function Solo:SetSecondaryScale(entry, percent)
    if not entry then return end
    local settings = addon:GetEntrySettings(entry.cooldownID, true)
    settings.secondarySoloScale = Clamp(
        math.floor((tonumber(percent) or Defaults.soloScale) + 0.5), 50, 200)
    local display = self.displays[self:GetDisplayKey(entry.cooldownID, 2)]
    if display then
        self:ApplyDisplayScale(display)
        self:ApplyDisplayPosition(display)
        self:RefreshDisplay(display)
    end
end

function Solo:SetScale(entry, percent)
    local settings = addon:GetEntrySettings(entry.cooldownID, true)
    settings.soloScale = Clamp(math.floor((tonumber(percent) or Defaults.soloScale) + 0.5), 50, 200)
    local display = self.displays[entry.cooldownID]
    if display then
        self:ApplyDisplayScale(display)
        if display.NativeItem then self:PositionNativeItem(display.NativeItem, display) end
    end
end

function Solo:SetBarDimension(entry, settingKey, value)
    local limits = {
        soloBarIconSize = { 16, 96 },
        soloBarWidth = { 80, 400 },
        soloBarHeight = { 4, 80 },
        soloBarTextSize = { 8, 32 },
    }
    local range = limits[settingKey]
    if not entry or not range then return end
    local settings = addon:GetEntrySettings(entry.cooldownID, true)
    settings[settingKey] = Clamp(math.floor((tonumber(value) or range[1]) + 0.5), range[1], range[2])
    local display = self.displays[entry.cooldownID]
    if not display or not display.isBar then return end
    local item = addon.Runtime and addon.Runtime:GetLiveItem(entry.cooldownID)
    local iconSize, barWidth, barHeight = GetBarDimensions(entry, item)
    display:SetSize(iconSize + barWidth, math.max(iconSize, barHeight))
    display.Icon:ClearAllPoints()
    display.Icon:SetPoint("LEFT", display, "LEFT", 0, 0)
    display.Icon:SetSize(iconSize, iconSize)
    display.BarBackground:ClearAllPoints()
    display.BarBackground:SetPoint("LEFT", display.Icon, "RIGHT", 0, 0)
    display.BarBackground:SetSize(barWidth, barHeight)
    local cooldown = display.LiveCooldown or display.Cooldown
    cooldown:ClearAllPoints()
    cooldown:SetAllPoints(display.Icon)
    self:ApplyTextLayout(display)
    self:RefreshDisplay(display)
end
