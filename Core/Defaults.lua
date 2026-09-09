local _, addon = ...

local Defaults = {
    database = {
        guiHeight = 770,
        guiScale = 85,
        fadeWhenUnfocused = false,
        fadeOpacity = 60,
        muteAllAudio = false,
        snapEnabled = true,
        snapSpacing = 1,
        hideSoloTooltips = false,
        hideSoloLabels = false,
        soloIconsLocked = true,
        nextSoloLinkGroupID = 1,
        tutorialRainbowSeen = false,
        alertMotionVersion = 2,
        editorCollapsedSections = {
            display = true,
            theme = true,
            effects = true,
            voice = true,
            icon = true,
        },
        minimap = {
            hide = false,
            minimapPos = 220,
            showInCompartment = true,
        },
        editBarPosition = { x = 0, y = 0 },
    },
    trigger = {
        enabled = true,
        text = "",
        ttsEnabled = false,
        speechRate = 0,
        ttsVolume = 100,
        audioEnabled = false,
        audioSound = nil,
        audioChannel = "Master",
        zoom = false,
        bounce = false,
        bounceDuration = 0,
        glow = false,
        glowStyle = "blizzard",
        glowDuration = 0,
        glowCount = nil,
        glowSpeed = 4,
        glowThickness = 2,
        glowPadding = 0,
        color = { 1, 0.82, 0, 1 },
    },
    soloScale = 100,
    soloBarAppearance = {
        iconSize = 32,
        width = 180,
        height = 24,
        textSize = 14,
    },
    soloAppearance = {
        onTop = false,
        opacity = 100,
        cropEnabled = false,
        cropPercent = 50,
        showSwipe = true,
        showNumbers = true,
        showStacks = false,
        stackFontSize = 14,
        cooldownFontSize = 16,
        hotkeyFontSize = 14,
        font = "Baby Auras - Baby",
        stackColor = { 1, 1, 1, 1 },
        cooldownColor = { 1, 1, 1, 1 },
        hotkeyColor = { 1, 1, 1, 1 },
        hotkey = "",
        classSwipe = false,
        keepColored = false,
        activeBorder = false,
        alwaysShow = false,
        desaturateInactive = false,
        blackBorder = true,
        borderPixels = 1,
        barFillColor = { 0.08, 0.08, 0.10, 0.92 },
        barProgressColor = { 0.85, 0.85, 0.85, 0.55 },
        barTextColor = { 1, 1, 1, 1 },
    },
}
addon.Defaults = Defaults

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = Copy(child) end
    return result
end

local function ApplyMissing(target, source)
    for key, value in pairs(source) do
        if target[key] == nil then
            target[key] = Copy(value)
        elseif type(value) == "table" and type(target[key]) == "table" then
            ApplyMissing(target[key], value)
        end
    end
end

function Defaults:CreateTrigger()
    return Copy(self.trigger)
end

function Defaults:InitializeDatabase(database)
    database = type(database) == "table" and database or {}
    local migrateOldBounceToZoom = database.alertMotionVersion ~= 2
    ApplyMissing(database, self.database)
    database.editorCollapsedSections = type(database.editorCollapsedSections) == "table"
        and database.editorCollapsedSections or Copy(self.database.editorCollapsedSections)
    for key, collapsed in pairs(self.database.editorCollapsedSections) do
        if database.editorCollapsedSections[key] == nil then
            database.editorCollapsedSections[key] = collapsed
        else
            database.editorCollapsedSections[key] = database.editorCollapsedSections[key] == true
        end
    end
    database.profiles = type(database.profiles) == "table" and database.profiles or {}
    database.minimap = type(database.minimap) == "table" and database.minimap or Copy(self.database.minimap)
    database.editBarPosition = type(database.editBarPosition) == "table"
        and database.editBarPosition or Copy(self.database.editBarPosition)
    for _, profile in pairs(database.profiles) do
        for _, entry in pairs(type(profile) == "table" and profile.entries or {}) do
            if type(entry) == "table" then
                entry.editorCollapsedSections = nil
                entry.secondaryIconEnabled = entry.secondaryIconEnabled == true
                if entry.secondarySoloScale ~= nil then
                    entry.secondarySoloScale = Clamp(
                        math.floor((tonumber(entry.secondarySoloScale) or self.soloScale) + 0.5), 50, 200)
                end
                if entry.secondarySoloPosition ~= nil
                    and type(entry.secondarySoloPosition) ~= "table" then
                    entry.secondarySoloPosition = nil
                end
                for _, trigger in pairs(entry.triggers or {}) do
                    if type(trigger) == "table" then
                        if migrateOldBounceToZoom and trigger.zoom == nil and trigger.bounce ~= nil then
                            trigger.zoom = trigger.bounce == true
                            trigger.bounce = nil
                        end
                        trigger.triggerOnStacks = nil
                        trigger.triggerStackCount = nil
                    end
                end
            end
        end
    end
    database.guiHeight = Clamp(tonumber(database.guiHeight) or self.database.guiHeight, 420, 2000)
    database.guiScale = Clamp(math.floor(((tonumber(database.guiScale) or self.database.guiScale) + 2.5) / 5) * 5, 70, 130)
    database.fadeOpacity = Clamp(tonumber(database.fadeOpacity) or self.database.fadeOpacity, 10, 90)
    database.fadeWhenUnfocused = database.fadeWhenUnfocused == true
    database.muteAllAudio = database.muteAllAudio == true
    database.snapEnabled = database.snapEnabled ~= false
    database.snapSpacing = Clamp(math.floor(tonumber(database.snapSpacing) or self.database.snapSpacing), 0, 10)
    database.hideSoloTooltips = database.hideSoloTooltips == true
    database.hideSoloLabels = database.hideSoloLabels == true
    database.nextSoloLinkGroupID = math.max(1, math.floor(tonumber(database.nextSoloLinkGroupID) or 1))
    -- Locking is a safe session state, not a layout preference. Always begin a
    -- fresh addon load locked so another character/session cannot inherit an
    -- unlocked editor state.
    database.soloIconsLocked = true
    database.tutorialRainbowSeen = database.tutorialRainbowSeen == true
    database.alertMotionVersion = 2
    return database
end
