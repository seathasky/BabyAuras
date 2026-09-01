local _, addon = ...

local Solo = addon.Solo

local GREEN = { r = 0.18, g = 1.00, b = 0.38 }
local GROUP_COLORS = {
    { r = 0.18, g = 1.00, b = 0.38 },
    { r = 0.20, g = 0.78, b = 1.00 },
    { r = 1.00, g = 0.62, b = 0.16 },
    { r = 1.00, g = 0.34, b = 0.72 },
    { r = 0.72, g = 0.48, b = 1.00 },
    { r = 0.96, g = 0.90, b = 0.20 },
}

function Solo:IsLinkMode()
    return self.linkModeActive == true
end

function Solo:IsLinkSelected(display)
    local cooldownID = display and display.entry and display.entry.cooldownID
    return cooldownID and self.linkSelection and self.linkSelection[cooldownID] == true or false
end

function Solo:GetLinkGroupID(entry)
    local settings = entry and addon:GetEntrySettings(entry.cooldownID, false)
    return settings and settings.soloLinkGroup or nil
end

function Solo:GetLinkGroupVisual(entry)
    local groupID = self:GetLinkGroupID(entry)
    if not groupID then return nil, nil, nil end
    local number = tonumber(tostring(groupID):match("(%d+)$")) or 1
    local color = GROUP_COLORS[((number - 1) % #GROUP_COLORS) + 1]
    return groupID, number, color
end

function Solo:GetLinkedDisplays(entry)
    local groupID = self:GetLinkGroupID(entry)
    local displays = {}
    if not groupID then return displays end
    for _, display in pairs(self.displays or {}) do
        if not display.isSecondary and display.entry and self:GetLinkGroupID(display.entry) == groupID then
            displays[#displays + 1] = display
        end
    end
    return displays
end

function Solo:EnsureLinkVisuals(display)
    if not display or display.LinkVisual then return end

    local visual = CreateFrame("Frame", nil, display, "BackdropTemplate")
    visual:SetAllPoints(display)
    visual:EnableMouse(false)
    visual:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
    })
    visual:Hide()
    display.LinkVisual = visual

    local badge = CreateFrame("Frame", nil, display, "BackdropTemplate")
    badge:SetSize(16, 16)
    badge:SetPoint("BOTTOMRIGHT", display.Icon, "BOTTOMRIGHT", 4, -4)
    badge:SetFrameLevel(display:GetFrameLevel() + 21)
    badge:EnableMouse(false)
    badge:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    badge:SetBackdropColor(0.01, 0.08, 0.025, 0.95)
    badge:SetBackdropBorderColor(GREEN.r, GREEN.g, GREEN.b, 1)
    local letter = badge:CreateFontString(nil, "OVERLAY")
    letter:SetFont(STANDARD_TEXT_FONT, 12, "THICKOUTLINE")
    letter:SetPoint("CENTER", 0, 0)
    letter:SetText("L")
    letter:SetTextColor(GREEN.r, GREEN.g, GREEN.b)
    badge:Hide()
    display.LinkBadge = badge
    display.LinkBadgeText = letter
end

function Solo:UpdateLinkVisual(display)
    if not display then return end
    self:EnsureLinkVisuals(display)

    local visual = display.LinkVisual
    local active = not display.isSecondary and self:IsLinkMode() and self:IsPositioningMode()
    local groupID, groupNumber, groupColor
    if not display.isSecondary then
        groupID, groupNumber, groupColor = self:GetLinkGroupVisual(display.entry)
    end
    local borderColor = groupColor or GREEN
    visual:SetFrameLevel(display:GetFrameLevel() + 20)
    display.LinkBadge:SetFrameLevel(display:GetFrameLevel() + 21)
    visual:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, active and 1 or 0)
    if active and self:IsLinkSelected(display) then
        visual:SetBackdropColor(GREEN.r, GREEN.g, GREEN.b, 0.32)
    else
        visual:SetBackdropColor(GREEN.r, GREEN.g, GREEN.b, 0)
    end
    visual:SetShown(active)
    if groupID then
        local badgeText = "L" .. groupNumber
        display.LinkBadge:SetSize(math.max(18, 10 + (#badgeText * 7)), 16)
        display.LinkBadge:SetBackdropColor(borderColor.r * 0.08, borderColor.g * 0.08, borderColor.b * 0.08, 0.95)
        display.LinkBadge:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b, 1)
        display.LinkBadgeText:SetText(badgeText)
        display.LinkBadgeText:SetTextColor(borderColor.r, borderColor.g, borderColor.b)
    end
    display.LinkBadge:SetShown(self:IsPositioningMode() and groupID ~= nil)
end

function Solo:RefreshLinkVisuals()
    for _, display in pairs(self.displays or {}) do
        self:UpdateLinkVisual(display)
    end
end

function Solo:GetLinkSelectionCount()
    local count = 0
    for _, selected in pairs(self.linkSelection or {}) do
        if selected then count = count + 1 end
    end
    return count
end

local function GetLinkGroupListText()
    local groups = {}
    for cooldownID, settings in pairs(addon:GetProfile().entries or {}) do
        if type(settings) == "table" and settings.soloLinkGroup then
            local number = tonumber(tostring(settings.soloLinkGroup):match("(%d+)$")) or 1
            groups[number] = groups[number] or {}
            local entry = addon.Catalog:Get(tonumber(cooldownID) or cooldownID)
            groups[number][#groups[number] + 1] = entry and entry.name or ("Icon " .. tostring(cooldownID))
        end
    end

    local numbers = {}
    for number in pairs(groups) do numbers[#numbers + 1] = number end
    table.sort(numbers)
    if #numbers == 0 then return "No linked groups." end

    local lines = {}
    for _, number in ipairs(numbers) do
        table.sort(groups[number])
        local color = GROUP_COLORS[((number - 1) % #GROUP_COLORS) + 1]
        local colorCode = string.format("|cff%02x%02x%02x",
            math.floor(color.r * 255 + 0.5), math.floor(color.g * 255 + 0.5), math.floor(color.b * 255 + 0.5))
        lines[#lines + 1] = colorCode .. "L" .. number .. ".|r " .. table.concat(groups[number], ", ")
    end
    return table.concat(lines, "\n")
end

function Solo:CreateLinkModePopup(parent)
    if self.linkModePopup or not parent then return end

    local popup = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    popup:SetSize(650, 166)
    popup:SetFrameStrata("TOOLTIP")
    popup:SetFrameLevel(1000)
    popup:SetToplevel(true)
    popup:EnableMouse(true)
    popup:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 2,
    })
    popup:SetBackdropColor(0.015, 0.07, 0.03, 0.97)
    popup:SetBackdropBorderColor(GREEN.r, GREEN.g, GREEN.b, 1)

    local title = popup:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -11)
    title:SetText("LINK ICONS MODE")
    title:SetTextColor(GREEN.r, GREEN.g, GREEN.b)

    local linkingHeader = popup:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    linkingHeader:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    linkingHeader:SetText("LINKING")
    linkingHeader:SetTextColor(0.42, 0.82, 1)

    local instructions = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    instructions:SetPoint("TOPLEFT", linkingHeader, "BOTTOMLEFT", 0, -5)
    instructions:SetWidth(300)
    instructions:SetJustifyH("LEFT")
    instructions:SetText("1. Left-click at least two icons.\n2. Click Create Link.\n3. Repeat for more groups.\n4. Turn Link Icons OFF when finished.\nRight-click an icon to unlink it.")

    local linksHeader = popup:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    linksHeader:SetPoint("TOPLEFT", popup, "TOPLEFT", 335, -43)
    linksHeader:SetText("CURRENT LINKS")
    linksHeader:SetTextColor(0.42, 0.82, 1)

    local linksScroll = CreateFrame("ScrollFrame", nil, popup)
    linksScroll:SetPoint("TOPLEFT", linksHeader, "BOTTOMLEFT", 0, -5)
    linksScroll:SetSize(295, 92)
    linksScroll:EnableMouseWheel(true)
    local linksChild = CreateFrame("Frame", nil, linksScroll)
    linksChild:SetSize(295, 92)
    linksScroll:SetScrollChild(linksChild)
    local links = linksChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    links:SetPoint("TOPLEFT")
    links:SetWidth(290)
    links:SetJustifyH("LEFT")
    links:SetJustifyV("TOP")
    linksScroll:SetScript("OnMouseWheel", function(self, delta)
        local maximum = math.max(0, links:GetStringHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(maximum, self:GetVerticalScroll() - (delta * 24))))
    end)
    popup.LinkList = links
    popup.LinkListChild = linksChild

    local count = popup:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    count:SetPoint("TOPRIGHT", -14, -14)
    count:SetTextColor(0.72, 1, 0.78)
    popup.Count = count

    local create = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
    create:SetSize(112, 24)
    create:SetPoint("BOTTOMLEFT", 12, 10)
    create:SetText("Create Link")
    create:SetScript("OnClick", function() Solo:CreateLinkFromSelection() end)
    popup.Create = create

    popup.Anchor = parent

    popup:Hide()
    self.linkModePopup = popup
end

function Solo:PositionLinkModePopup()
    local popup = self.linkModePopup
    local anchor = popup and popup.Anchor
    if not popup or not anchor then return end

    popup:ClearAllPoints()
    popup:SetPoint("TOP", anchor, "BOTTOM", 0, -12)
end

function Solo:UpdateLinkModePopup()
    local popup = self.linkModePopup
    if not popup then return end
    local active = self:IsLinkMode() and self:IsPositioningMode()
    local selectedCount = self:GetLinkSelectionCount()
    popup.Count:SetText(selectedCount .. " selected")
    popup.LinkList:SetText(GetLinkGroupListText())
    popup.LinkListChild:SetHeight(math.max(92, popup.LinkList:GetStringHeight()))
    popup.Create:SetEnabled(selectedCount >= 2)
    popup.Create:GetFontString():SetTextColor(1, 1, 1)
    if active then self:PositionLinkModePopup() end
    popup:SetShown(active)
end

function Solo:UpdateLinkButton()
    local button = self.linkButton
    if not button then return end

    local active = self:IsLinkMode()
    button:SetText(active and "Link Icons: ON" or "Link Icons: OFF")
    button:SetBackdropColor(active and 0.04 or 0.06, active and 0.30 or 0.16, active and 0.10 or 0.25, 1)
    button:SetBackdropBorderColor(active and GREEN.r or (137 / 255),
        active and GREEN.g or (147 / 255), active and GREEN.b or (210 / 255), 1)
    button:GetFontString():SetTextColor(1, 1, 1)
    self:UpdateLinkModePopup()
end

function Solo:NormalizeLinkGroups()
    local groups = {}
    for _, settings in pairs(addon:GetProfile().entries or {}) do
        if type(settings) == "table" and settings.soloLinkGroup then
            local groupID = settings.soloLinkGroup
            groups[groupID] = groups[groupID] or {}
            groups[groupID][#groups[groupID] + 1] = settings
        end
    end
    for _, members in pairs(groups) do
        if #members < 2 then members[1].soloLinkGroup = nil end
    end
end

function Solo:GetLowestAvailableLinkGroupNumber(excludedSettings)
    excludedSettings = excludedSettings or {}
    local used = {}
    for _, settings in pairs(addon:GetProfile().entries or {}) do
        if type(settings) == "table" and settings.soloLinkGroup and not excludedSettings[settings] then
            local number = tonumber(tostring(settings.soloLinkGroup):match("^link%-(%d+)$"))
            if number then used[number] = true end
        end
    end

    local number = 1
    while used[number] do number = number + 1 end
    return number
end

function Solo:CommitLinkSelection()
    local selected = {}
    for cooldownID, isSelected in pairs(self.linkSelection or {}) do
        if isSelected then
            local settings = addon:GetEntrySettings(cooldownID, false)
            if settings and settings.solo == true then selected[#selected + 1] = settings end
        end
    end
    if #selected < 2 then
        print("|cFFFFCC00Baby Auras:|r Select at least two Solo icons to create a linked group.")
        return false
    end

    if self.selectedLinkGroupID then
        local unchanged = true
        local selectedCount, existingCount = 0, 0
        for cooldownID, isSelected in pairs(self.linkSelection or {}) do
            if isSelected then
                selectedCount = selectedCount + 1
                local settings = addon:GetEntrySettings(cooldownID, false)
                if not settings or settings.soloLinkGroup ~= self.selectedLinkGroupID then unchanged = false end
            end
        end
        for _, settings in pairs(addon:GetProfile().entries or {}) do
            if type(settings) == "table" and settings.soloLinkGroup == self.selectedLinkGroupID then
                existingCount = existingCount + 1
            end
        end
        if unchanged and selectedCount == existingCount then return true end
    end

    self:NormalizeLinkGroups()
    local excludedSettings = {}
    for _, settings in ipairs(selected) do excludedSettings[settings] = true end
    local groupNumber = self:GetLowestAvailableLinkGroupNumber(excludedSettings)
    local groupID = "link-" .. tostring(groupNumber)
    BabyAurasDB.nextSoloLinkGroupID = groupNumber + 1
    for _, settings in ipairs(selected) do settings.soloLinkGroup = groupID end
    self:NormalizeLinkGroups()
    print("|cFF44FF66Baby Auras:|r Linked " .. #selected .. " Solo icons.")
    return true
end

function Solo:CreateLinkFromSelection()
    if not self:IsLinkMode() then return end
    if not self:CommitLinkSelection() then return end
    self.linkSelection = {}
    self.selectedLinkGroupID = nil
    self:RefreshLinkVisuals()
    self:UpdateLinkModePopup()
end

function Solo:UnlinkGroup(groupID)
    if not groupID then return end

    local removed = 0
    for _, settings in pairs(addon:GetProfile().entries or {}) do
        if type(settings) == "table" and settings.soloLinkGroup == groupID then
            settings.soloLinkGroup = nil
            removed = removed + 1
        end
    end
    self.selectedLinkGroupID = nil
    self.linkSelection = {}
    self:NormalizeLinkGroups()
    self:RefreshLinkVisuals()
    self:UpdateLinkModePopup()
    print("|cFF44FF66Baby Auras:|r Unlinked " .. removed .. " Solo icons.")
end

function Solo:UnlinkDisplay(display)
    if not self:IsLinkMode() or not display or not display.entry then return false end
    local groupID = self:GetLinkGroupID(display.entry)
    if not groupID then return false end

    local settings = addon:GetEntrySettings(display.entry.cooldownID, false)
    if settings then settings.soloLinkGroup = nil end
    self.linkSelection = self.linkSelection or {}
    self.linkSelection[display.entry.cooldownID] = nil
    if self.selectedLinkGroupID == groupID then self.selectedLinkGroupID = nil end
    self:NormalizeLinkGroups()
    self:RefreshLinkVisuals()
    self:UpdateLinkModePopup()
    print("|cFF44FF66Baby Auras:|r Removed " .. display.entry.name .. " from its linked group.")
    return true
end

function Solo:RemoveFromLinkGroup(entry)
    local settings = entry and addon:GetEntrySettings(entry.cooldownID, false)
    if not settings or not settings.soloLinkGroup then return end
    settings.soloLinkGroup = nil
    self:NormalizeLinkGroups()
    self:RefreshLinkVisuals()
end

function Solo:SetLinkMode(enabled)
    enabled = enabled == true and self:IsPositioningMode() and not InCombatLockdown()
    self.linkModeActive = enabled
    if not enabled then
        self.linkSelection = {}
        self.selectedLinkGroupID = nil
    end
    self:UpdateLinkButton()
    self:RefreshLinkVisuals()
end

function Solo:ToggleLinkMode()
    self:SetLinkMode(not self:IsLinkMode())
end

function Solo:ToggleLinkSelection(display)
    if not self:IsLinkMode() or not display or not display.entry then return false end

    self.linkSelection = self.linkSelection or {}
    local cooldownID = display.entry.cooldownID
    local groupID = self:GetLinkGroupID(display.entry)
    if groupID then
        local deselect = self.selectedLinkGroupID == groupID and self.linkSelection[cooldownID] == true
        self.linkSelection = {}
        self.selectedLinkGroupID = deselect and nil or groupID
        if not deselect then
            for memberID, settings in pairs(addon:GetProfile().entries or {}) do
                if type(settings) == "table" and settings.soloLinkGroup == groupID then
                    self.linkSelection[tonumber(memberID) or memberID] = true
                end
            end
        end
        self:RefreshLinkVisuals()
    else
        self.linkSelection[cooldownID] = not self.linkSelection[cooldownID] or nil
        self:UpdateLinkVisual(display)
    end
    self:UpdateLinkModePopup()
    return true
end

function Solo:BeginLinkedDrag(display)
    local members = self:GetLinkedDisplays(display.entry)
    if #members < 2 then
        self.linkDrag = nil
        return
    end

    local leaderX, leaderY = addon.SoloUtilities.GetScreenCenter(display)
    leaderX, leaderY = addon.SoloUtilities.ScreenToUIParent(leaderX, leaderY)
    if not leaderX or not leaderY then return end
    local state = { leader = display, leaderX = leaderX, leaderY = leaderY, members = {} }
    for _, member in ipairs(members) do
        if member ~= display then
            local position = self:GetPosition(member.entry, true)
            state.members[#state.members + 1] = {
                display = member,
                x = position.x or 0,
                y = position.y or 0,
            }
        end
    end
    self.linkDrag = state
end

function Solo:UpdateLinkedDrag(display)
    local state = self.linkDrag
    if not state or state.leader ~= display then return end
    local currentX, currentY = addon.SoloUtilities.GetScreenCenter(display)
    currentX, currentY = addon.SoloUtilities.ScreenToUIParent(currentX, currentY)
    if not currentX or not currentY then return end
    local deltaX, deltaY = currentX - state.leaderX, currentY - state.leaderY
    for _, member in ipairs(state.members) do
        local other = member.display
        local scale = other:GetScale()
        if not scale or scale == 0 then scale = 1 end
        other:ClearAllPoints()
        other:SetPoint("CENTER", UIParent, "CENTER", (member.x + deltaX) / scale, (member.y + deltaY) / scale)
    end
end

function Solo:FinishLinkedDrag(display)
    local state = self.linkDrag
    if not state or state.leader ~= display then return end
    self:UpdateLinkedDrag(display)
    for _, member in ipairs(state.members) do self:SaveDisplayPosition(member.display) end
    self.linkDrag = nil
end
