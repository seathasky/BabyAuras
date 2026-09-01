local _, addon = ...

local GUI = addon.GUI
local SetButtonTextWhite = addon.GUIWidgets.SetButtonTextWhite

function GUI:IsEditorSectionCollapsed(sectionKey)
    if self.temporaryExpandedSections and self.temporaryExpandedSections[sectionKey] then return false end
    local sections = BabyAurasDB and BabyAurasDB.editorCollapsedSections
    if sections and sections[sectionKey] ~= nil then return sections[sectionKey] == true end
    return true
end

function GUI:AreAllEditorSectionsCollapsed()
    if not self.selected or not self.frame or not self.frame.EditorSections then return true end
    for _, section in ipairs(self.frame.EditorSections) do
        if not self:IsEditorSectionCollapsed(section.key) then return false end
    end
    return true
end

function GUI:UpdateAllSectionsButton()
    local button = self.frame and self.frame.AllSectionsButton
    if not button then return end
    local available = self.selected ~= nil
    button:SetEnabled(available)
    button:SetAlpha(available and 1 or 0.4)
    button:SetText(self:AreAllEditorSectionsCollapsed() and "Expand All" or "Collapse All")
    SetButtonTextWhite(button)
end

function GUI:ToggleAllEditorSections()
    if not self.selected or not self.frame or not self.frame.EditorSections then return end
    local collapse = not self:AreAllEditorSectionsCollapsed()
    BabyAurasDB.editorCollapsedSections = type(BabyAurasDB.editorCollapsedSections) == "table"
        and BabyAurasDB.editorCollapsedSections or {}
    for _, section in ipairs(self.frame.EditorSections) do
        BabyAurasDB.editorCollapsedSections[section.key] = collapse
        if self.temporaryExpandedSections then self.temporaryExpandedSections[section.key] = nil end
        if not collapse then
            for _, element in ipairs(section.elements) do element:Show() end
        end
    end
    self:RefreshEditor()
    self:SetStatus((collapse and "Collapsed" or "Expanded")
        .. " all sections globally. Saved settings were not changed.")
end

function GUI:ApplyEditorSectionLayout()
    local frame = self.frame
    if not frame or not frame.EditorSections then return end
    local previous
    for _, section in ipairs(frame.EditorSections) do
        local active = section.title:IsShown()
        if section.toggle then section.toggle:SetShown(active) end
        if active and previous then
            local anchor = self:IsEditorSectionCollapsed(previous.key) and previous.title or previous.bottom
            section.title:ClearAllPoints()
            section.title:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0,
                self:IsEditorSectionCollapsed(previous.key) and -27 or (previous.gap - 8))
        end
        local collapsed = self:IsEditorSectionCollapsed(section.key)
        if section.toggle then section.toggle.Symbol:SetText(collapsed and "+" or "-") end
        if active and collapsed then
            for _, element in ipairs(section.elements) do element:Hide() end
        end
        if active then previous = section end
    end
    for index, section in ipairs(frame.EditorSections) do
        if section.background then
            local active = section.title:IsShown()
            local expanded = active and not self:IsEditorSectionCollapsed(section.key)
            section.background:SetShown(expanded)
            if expanded then
                local nextTitle
                for nextIndex = index + 1, #frame.EditorSections do
                    if frame.EditorSections[nextIndex].title:IsShown() then
                        nextTitle = frame.EditorSections[nextIndex].title
                        break
                    end
                end
                local panel = section.background.frame
                panel:ClearAllPoints()
                panel:SetPoint("TOPLEFT", section.title, "BOTTOMLEFT", -10, -2)
                panel:SetPoint("TOPRIGHT", section.title, "BOTTOMLEFT", 390, -2)
                if nextTitle then
                    panel:SetPoint("BOTTOMLEFT", nextTitle, "TOPLEFT", -10, 15)
                else
                    panel:SetPoint("BOTTOMLEFT", section.bottom, "BOTTOMLEFT", -10, -14)
                end
                local leftDivider = section.background.leftDivider
                leftDivider:ClearAllPoints()
                leftDivider:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -1)
                leftDivider:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 0, 1)
            end
        end
    end
    local height = 1718
    for _, section in ipairs(frame.EditorSections) do
        if not section.title:IsShown() or self:IsEditorSectionCollapsed(section.key) then
            height = height - section.collapseHeight
        end
    end
    if frame.ActiveTrackedBar and not self:IsEditorSectionCollapsed("display") then height = height + 98 end
    if frame.ActiveTrackedBar and not self:IsEditorSectionCollapsed("theme") then height = height + 77 end
    frame.Editor:SetHeight(math.max(400, height))
    self:UpdateAllSectionsButton()
end

function GUI:ResetEditorSectionVisibility()
    local frame = self.frame
    if not frame or not frame.EditorSections then return end
    BabyAurasDB.editorCollapsedSections = type(BabyAurasDB.editorCollapsedSections) == "table"
        and BabyAurasDB.editorCollapsedSections or {}
    for _, section in ipairs(frame.EditorSections) do
        if BabyAurasDB.editorCollapsedSections[section.key] == nil then
            BabyAurasDB.editorCollapsedSections[section.key] = true
        end
    end
    for _, section in ipairs(frame.EditorSections) do
        local shown = not self:IsEditorSectionCollapsed(section.key)
        for _, element in ipairs(section.elements) do element:SetShown(shown) end
    end
end

function GUI:ToggleEditorSection(sectionKey)
    if not self.selected or not self.frame or not self.frame.EditorSections then return end
    local collapsed = not self:IsEditorSectionCollapsed(sectionKey)
    BabyAurasDB.editorCollapsedSections = type(BabyAurasDB.editorCollapsedSections) == "table"
        and BabyAurasDB.editorCollapsedSections or {}
    BabyAurasDB.editorCollapsedSections[sectionKey] = collapsed
    if not collapsed then
        for _, section in ipairs(self.frame.EditorSections) do
            if section.key == sectionKey then
                for _, element in ipairs(section.elements) do element:Show() end
                break
            end
        end
        self:RefreshEditor()
    end
    self:ApplyEditorSectionLayout()
end

function GUI:ExpandEditorSection(sectionKey, temporary)
    if not self:IsEditorSectionCollapsed(sectionKey) then return end
    if temporary then
        self.temporaryExpandedSections = self.temporaryExpandedSections or {}
        self.temporaryExpandedSections[sectionKey] = true
        for _, section in ipairs(self.frame.EditorSections or {}) do
            if section.key == sectionKey then
                for _, element in ipairs(section.elements) do element:Show() end
                break
            end
        end
        self:RefreshEditor()
        return
    end
    self:ToggleEditorSection(sectionKey)
end
