local _, addon = ...

addon.GUISections = addon.GUISections or {}
local Icon = {}
addon.GUISections.Icon = Icon

local Widgets = addon.GUIWidgets

function Icon:Build(editor, anchor, frame)
    local title, line = Widgets.CreateSectionTitle(editor, "ICON CUSTOMIZATION")
    title:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
    frame.IconTestingTitle = title

    local label = editor:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    label:SetText("Custom icon spell ID (blank = Blizzard icon)")
    frame.IconLabel = label

    local spellID = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
    spellID:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 4, -7)
    spellID:SetSize(120, 26)
    spellID:SetAutoFocus(false)
    spellID:SetNumeric(true)
    spellID:SetScript("OnEscapePressed", spellID.ClearFocus)
    spellID:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        addon.GUI:CommitEditor()
    end)
    spellID:SetScript("OnTextChanged", function() addon.GUI:ScheduleAutoSave() end)
    frame.IconSpellID = spellID

    local prismatic, prismaticLabel = Widgets.CreateCheckbox(editor, "Show Prismatic Bolt icon instead", 235)
    prismatic:SetPoint("TOPLEFT", spellID, "BOTTOMLEFT", -4, -5)
    prismatic:SetScript("OnClick", function() addon.GUI:OnPrismaticIconClicked() end)
    frame.PrismaticIcon = prismatic
    frame.PrismaticIconLabel = prismaticLabel

    local secondary, secondaryLabel = Widgets.CreateCheckbox(editor, "Enable second Solo icon", 180)
    -- Most entries do not show the Prismatic option. Anchor to the primary
    -- spell field by default so that hidden special-case control does not leave
    -- a large empty row. RefreshEditor moves this below Prismatic when needed.
    secondary:SetPoint("TOPLEFT", spellID, "BOTTOMLEFT", -4, -8)
    secondary:SetScript("OnClick", function() addon.GUI:OnSecondaryIconClicked() end)
    frame.SecondaryIcon, frame.SecondaryIconLabel = secondary, secondaryLabel

    local secondarySpellLabel = editor:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    secondarySpellLabel:SetPoint("TOPLEFT", secondary, "BOTTOMLEFT", 4, -7)
    secondarySpellLabel:SetText("Second icon spell ID (blank = Blizzard icon)")
    frame.SecondaryIconSpellLabel = secondarySpellLabel
    local secondarySpellID = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
    secondarySpellID:SetPoint("TOPLEFT", secondarySpellLabel, "BOTTOMLEFT", 4, -7)
    secondarySpellID:SetSize(120, 26)
    secondarySpellID:SetAutoFocus(false)
    secondarySpellID:SetNumeric(true)
    secondarySpellID:SetScript("OnEscapePressed", secondarySpellID.ClearFocus)
    secondarySpellID:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        addon.GUI:CommitEditor()
    end)
    secondarySpellID:SetScript("OnTextChanged", function() addon.GUI:ScheduleAutoSave() end)
    frame.SecondaryIconSpellID = secondarySpellID

    local secondarySizeLabel = editor:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    -- Keep this on its own row. The spell-ID label is deliberately descriptive
    -- and cannot safely share the editor's 390px width with a slider/value box.
    secondarySizeLabel:SetPoint("TOPLEFT", secondarySpellID, "BOTTOMLEFT", -4, -10)
    secondarySizeLabel:SetText("Second icon size")
    frame.SecondaryIconSizeLabel = secondarySizeLabel
    local secondarySize = CreateFrame("Slider", nil, editor, "OptionsSliderTemplate")
    secondarySize:SetPoint("TOPLEFT", secondarySizeLabel, "BOTTOMLEFT", 7, -7)
    secondarySize:SetSize(105, 16)
    secondarySize:SetMinMaxValues(50, 200)
    secondarySize:SetValueStep(5)
    secondarySize:SetObeyStepOnDrag(true)
    secondarySize.Low:SetText("")
    secondarySize.High:SetText("")
    secondarySize.Text:SetText("")
    secondarySize:SetScript("OnValueChanged", function(_, value)
        addon.GUI:OnSecondaryIconSizeChanged(value)
    end)
    local secondarySizeValue = Widgets.AttachSliderInput(editor, secondarySize, { suffix = "%" })
    frame.SecondaryIconSize, frame.SecondaryIconSizeValue = secondarySize, secondarySizeValue

    local autoSave = editor:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    autoSave:SetPoint("LEFT", spellID, "RIGHT", 10, 0)
    autoSave:SetText("Changes save automatically")

    local message = editor:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    message:SetPoint("TOPLEFT", secondarySize, "BOTTOMLEFT", -7, -18)
    message:SetWidth(390)
    message:SetJustifyH("LEFT")
    frame.Message = message

    local toggle = Widgets.CreateSectionToggle(editor, title, line, "icon")
    return {
        title = title,
        line = line,
        label = label,
        spellID = spellID,
        prismatic = prismatic,
        prismaticLabel = prismaticLabel,
        secondary = secondary,
        secondaryLabel = secondaryLabel,
        secondarySpellLabel = secondarySpellLabel,
        secondarySpellID = secondarySpellID,
        secondarySizeLabel = secondarySizeLabel,
        secondarySize = secondarySize,
        secondarySizeValue = secondarySizeValue,
        autoSave = autoSave,
        message = message,
        toggle = toggle,
        descriptor = {
            key = "icon", title = title, toggle = toggle, bottom = message,
            gap = -14, collapseHeight = 252,
            elements = {
                label, spellID, prismatic, prismaticLabel, autoSave,
                secondary, secondaryLabel, secondarySpellLabel, secondarySpellID,
                secondarySizeLabel, secondarySize, secondarySizeValue, message,
            },
        },
    }
end
