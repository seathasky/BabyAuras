local _, addon = ...

local Tutorial = addon.Tutorial

local function GetDemoIcon()
    local bestIcon, bestScore
    for _, icon in ipairs(addon.Navigation.icons or {}) do
        if icon:IsShown() and icon.data and icon.data.entry then
            local entry = icon.data.entry
            local triggerCount = 0
            for _, trigger in ipairs(addon.TriggerOrder) do
                if entry.validTriggers and entry.validTriggers[trigger] then
                    triggerCount = triggerCount + 1
                end
            end

            -- A tutorial example must actually be usable: learned by the
            -- current spec and backed by at least one Blizzard alert event.
            if entry.known == true and triggerCount > 0 then
                local score = triggerCount
                if addon.Solo:IsEligible(entry) then score = score + 20 end
                if entry.validTriggers[Enum.CooldownViewerAlertEventType.OnAuraApplied]
                    or entry.validTriggers[Enum.CooldownViewerAlertEventType.OnAuraRemoved] then
                    score = score + 10
                end
                if not bestScore or score > bestScore then
                    bestIcon, bestScore = icon, score
                end
            end
        end
    end
    return bestIcon
end

local function SelectDemoSpell()
    Tutorial.demoIcon = nil
    local icon = GetDemoIcon()
    if icon and icon.data and icon.data.entry then
        addon.GUI:Select(icon.data.entry)
        Tutorial.demoIcon = icon
    end
end

local function ShowCooldownSettingsPreview()
    Tutorial:ShowCooldownSettingsPreview()
end

local function ShowBabyAurasSettings()
    Tutorial:ShowBabyAurasSettings()
end

local function StartFinalCelebration()
    Tutorial:StartCelebration()
end

local function Frames(...)
    return { ... }
end

Tutorial.steps = {
    {
        title = "Welcome to Baby Auras",
        text = "This guided tour explains how Baby Auras works without changing your saved options. You can exit at any time and replay it from this Tutorial button.",
        target = function() return addon.GUI.frame.TutorialButton end,
    },
    {
        title = "Choose what Blizzard tracks",
        text = "Baby Auras builds on Blizzard's Cooldown Manager. Outside this tour, use this button to choose the spells, buffs, and bars Blizzard should track. Return here afterward to configure their alerts and Solo icons.",
        target = function() return addon.Navigation.blizzardButton end,
        cursor = true,
        cursorPosition = "RIGHT",
        prepare = ShowCooldownSettingsPreview,
    },
    {
        title = "Your tracked categories",
        text = "The left panel mirrors your current Essential Cooldowns, Utility Cooldowns, Tracked Buffs, and Tracked Bars. These lists automatically refresh when your specialization or Cooldown Manager setup changes.",
        target = function() return addon.Navigation.scroll end,
        targetArrow = true,
        targetArrowPosition = "ABOVE_DIALOG",
    },
    {
        title = "Select an element",
        text = "Clicking an icon opens its settings on the right. The small blue S means that element already has a Solo icon. For this tour, Baby Auras selected an available element from your current specialization.",
        prepare = SelectDemoSpell,
        target = function() return Tutorial.demoIcon or GetDemoIcon() end,
        targetArrow = true,
        iconEmphasis = true,
    },
    {
        title = "Enable alerts",
        text = "Each spell or aura has one Baby Auras settings page. Enable Alerts turns its configured glow, motion, TTS, and audio alerts on or off. Solo display, styling, positioning, and icon customization remain independent. Icon Customization can also enable a second independently sized and positioned Solo icon driven by the same CDM state.",
        target = function() return addon.GUI.frame.EnablePanel end,
        editorScroll = true,
    },
    {
        title = "Solo icon display",
        text = "Solo this element creates a freely positioned copy of the CDM icon. On top raises it above normal Solo icons, and Icon size controls only this element. The same percentage produces the same icon size for Essential Cooldowns, Utility Cooldowns, and Tracked Buffs.",
        sectionKey = "display",
        target = function()
            local f = addon.GUI.frame
            return Frames(f.DisplayTitle, f.Solo, f.SoloLabel, f.SoloOnTop, f.SoloOnTopLabel)
        end,
        editorScroll = true,
        fullEditorWidth = true,
    },
    {
        title = "Timer and inactive appearance",
        sectionKey = "display",
        text = "Timer wheel shows Blizzard's live cooldown or aura sweep, while Cooldown text shows its time label. Always show keeps the icon visible while inactive; Desaturate inactive then makes that idle state easy to recognize. Keep colored prevents normal cooldown desaturation, and Class-color wheel recolors the sweep.",
        target = function()
            local f = addon.GUI.frame
            return Frames(f.SoloShowSwipe, f.SoloShowNumbers, f.SoloKeepColored, f.SoloClassSwipe,
                f.SoloActiveBorder, f.SoloAlwaysShow, f.SoloDesaturateInactive)
        end,
        editorScroll = true,
        fullEditorWidth = true,
    },
    {
        title = "Icon opacity and text",
        sectionKey = "display",
        text = "Stack text and Cooldown text are enabled by default and can be hidden independently. Turning either off grays out its size and position controls. The X/Y fields position each label. The footer Preview Mode shows only the enabled cooldown, stack/charge, and hotkey text while you inspect the icon.",
        target = function()
            local f = addon.GUI.frame
            return Frames(f.SoloOpacity, f.SoloOpacityLabel, f.SoloOpacityValue,
                f.SoloStackSizeLabel, f.SoloStackSize, f.SoloStackSizeValue,
                f.SoloCooldownSizeLabel, f.SoloCooldownSize, f.SoloCooldownSizeValue,
                f.SoloStackPositionLabel, f.SoloStackX, f.SoloStackY,
                f.SoloCooldownPositionLabel, f.SoloCooldownX, f.SoloCooldownY,
                f.SoloHotkeyLabel, f.SoloHotkey, f.SoloHotkeySizeLabel, f.SoloHotkeySize,
                f.SoloHotkeySizeValue, f.SoloHotkeyPositionLabel, f.SoloHotkeyX, f.SoloHotkeyY)
        end,
        editorScroll = true,
        fullEditorWidth = true,
    },
    {
        title = "Solo icon theme",
        sectionKey = "theme",
        text = "The Theme section adds a clean black border around the Solo icon. Text font changes the stack, cooldown, and hotkey font together, while the three color buttons set each text color independently for this icon. Reset Text Colors restores all three defaults for only this icon. It uses LibSharedMedia, so compatible fonts registered by other addons also appear in the menu.",
        target = function()
            local f = addon.GUI.frame
            return Frames(f.ThemeTitle, f.SoloBlackBorder, f.SoloBorderSize, f.SoloFontLabel, f.SoloFont,
                f.SoloStackColor, f.SoloCooldownColor, f.SoloHotkeyColor, f.ResetSoloTextColors)
        end,
        editorScroll = true,
        fullEditorWidth = true,
    },
    {
        title = "Visual alert effects",
        sectionKey = "effects",
        text = "Glow Alert flashes the icon when the spell's alert fires. Choose Blizzard Proc, Pixel Glow, or Extended Glow, then set its duration. Action Bar Glow can also hold a Blizzard proc glow on one or more buttons you pick while the Solo element is active. Pixel and Extended support a custom color plus Count, Speed, Thickness, and Padding controls. While Preview Mode is ON, these controls update the held glow live without replaying its sound. Tracked bars support Pixel and Extended; other icon categories can also use Blizzard Proc.",
        target = function()
            local f = addon.GUI.frame
            return Frames(f.EffectsTitle, f.Glow, f.GlowStyle, f.Duration, f.GlowColor,
                f.GlowCount, f.GlowSpeed, f.GlowThickness, f.GlowPadding)
        end,
        editorScroll = true,
        fullEditorWidth = true,
    },
    {
        title = "Voice and audio",
        sectionKey = "voice",
        text = "TTS speaks your custom phrase with adjustable speed and volume. Audio opens one searchable list containing both Baby Auras sounds and Blizzard CDM sounds, then plays your choice on the selected game channel. The speaker button previews it before you rely on it in combat.",
        target = function()
            local f = addon.GUI.frame
            return Frames(f.VoiceTitle, f.TTS, f.TextBox, f.SpeechRate, f.TTSVolume,
                f.Audio, f.AudioDropdown, f.AudioPreview, f.AudioChannel)
        end,
        editorScroll = true,
        fullEditorWidth = true,
    },
    {
        title = "Icon customization",
        sectionKey = "icon",
        text = "Enter a spell ID to replace the displayed icon without changing what is tracked. This section only changes the artwork shown for the selected element. All changes save automatically.",
        target = function()
            local f = addon.GUI.frame
            return Frames(f.IconTestingTitle, f.IconLabel, f.IconSpellID)
        end,
        editorScroll = true,
        fullEditorWidth = true,
    },
    {
        title = "Preview everything",
        text = "Preview Mode is the combined test toggle. Turning it ON unlocks Solo icons, shows each enabled stack, cooldown, and hotkey label, plays the configured TTS or audio once, and holds the selected glow for inspection. Changes to glow controls update live without replaying sound. It stays on while you switch icons. Click Preview Mode again, or close Baby Auras, to clear the preview and lock the icons.",
        target = function() return addon.GUI.frame.Test end,
    },
    {
        title = "Collapse or expand sections",
        text = "The plus or minus at the right of each heading opens or closes only that section. This layout is global: if Voice & Audio is open, it stays open when you switch icons. The highlighted Collapse All button closes every section together and then becomes Expand All. These controls never change the settings inside a section.",
        target = function() return addon.GUI.frame.AllSectionsButton end,
    },
    {
        title = "Position your Solo icons",
        text = "Unlock icons when you want to drag the Solo icons themselves. The positioning bar includes snap guides, Reset Positions, a tooltip toggle, and Hide B / Show B for the compact Baby Auras markers. Hover an icon to see its spell name. The B toggle does not affect stack, cooldown, or hotkey text. Their positions are adjusted with the X/Y fields in Display.",
        target = function()
            local f = addon.GUI.frame
            return Frames(f.IconLock, f.SoloEdit)
        end,
        targetArrow = true,
        targetArrowPosition = "INSIDE_RIGHT",
        showEditModeImage = true,
    },
    {
        title = "Baby Auras settings",
        text = "Use the settings menu to control unfocused fading, faded opacity, GUI scale, and the minimap button. These preferences apply to the Baby Auras interface itself.",
        prepare = ShowBabyAurasSettings,
        target = function() return addon.GUI.frame.SettingsPopup end,
        targetArrow = true,
    },
    {
        title = "Congratulations!",
        text = "Congratulations, you completed the Baby Auras tutorial! Go to About Me by double-clicking the Baby Auras title.",
        prepare = StartFinalCelebration,
        target = function() return addon.GUI.frame.TitleAboutButton end,
    },
}
