-- MyAce3Addon - Ace3 skeleton with profile DB and AceConfig options panel.

local ADDON_NAME = ...

local MyAddon = LibStub("AceAddon-3.0"):NewAddon(
    ADDON_NAME,
    "AceEvent-3.0",
    "AceConsole-3.0",
    "AceTimer-3.0"
)

-- =========================================================================
-- Defaults & DB
-- =========================================================================

local DEFAULTS = {
    profile = {
        enabled = true,
        threshold = 50,
        announceChannel = "PARTY",
        colors = {
            bg = { 0, 0, 0, 0.6 },
            fg = { 1, 1, 1, 1 },
        },
    },
    char = {
        seenIntro = false,
    },
    global = {
        installCount = 0,
    },
}

-- =========================================================================
-- Lifecycle
-- =========================================================================

function MyAddon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New(ADDON_NAME .. "DB", DEFAULTS, true)
    self.db.global.installCount = self.db.global.installCount + 1

    self:RegisterChatCommand("myaddon", "OnSlashCommand")
    self:RegisterChatCommand("ma", "OnSlashCommand")

    self:SetupOptions()
end

function MyAddon:OnEnable()
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:Print(("|cff00ff00enabled|r (run #%d)"):format(self.db.global.installCount))
end

function MyAddon:OnDisable()
    -- AceEvent auto-unregisters on disable; nothing to do here.
end

-- =========================================================================
-- Event handlers (named after the event)
-- =========================================================================

function MyAddon:PLAYER_REGEN_DISABLED()
    if not self.db.profile.enabled then return end
    self:Print("combat started")
end

function MyAddon:PLAYER_REGEN_ENABLED()
    if not self.db.profile.enabled then return end
    self:Print("combat ended")
end

-- =========================================================================
-- Options panel via AceConfig-3.0
-- =========================================================================

function MyAddon:SetupOptions()
    local options = {
        name = "MyAce3Addon",
        type = "group",
        args = {
            enabled = {
                name = "Enabled",
                desc = "Master toggle for the addon.",
                type = "toggle",
                order = 1,
                get = function() return self.db.profile.enabled end,
                set = function(_, val) self.db.profile.enabled = val end,
            },
            threshold = {
                name = "Threshold",
                desc = "Threshold (0-100).",
                type = "range",
                min = 0, max = 100, step = 1,
                order = 2,
                get = function() return self.db.profile.threshold end,
                set = function(_, val) self.db.profile.threshold = val end,
            },
            announceChannel = {
                name = "Announce channel",
                type = "select",
                values = { SAY = "Say", YELL = "Yell", PARTY = "Party", RAID = "Raid" },
                order = 3,
                get = function() return self.db.profile.announceChannel end,
                set = function(_, val) self.db.profile.announceChannel = val end,
            },
            spacer1 = { name = "", type = "header", order = 10 },
            profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db),
        },
    }

    LibStub("AceConfig-3.0"):RegisterOptionsTable(ADDON_NAME, options)
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(ADDON_NAME, "MyAce3Addon")
    -- self.optionsFrame.profiles = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(
    --     ADDON_NAME, "Profiles", "MyAce3Addon", "profiles")
end

-- =========================================================================
-- Slash command
-- =========================================================================

function MyAddon:OnSlashCommand(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S+)%s*(.*)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "" or cmd == "config" or cmd == "options" then
        Settings.OpenToCategory(ADDON_NAME)

    elseif cmd == "status" then
        local p = self.db.profile
        self:Printf("enabled=%s threshold=%d channel=%s",
            tostring(p.enabled), p.threshold, p.announceChannel)

    elseif cmd == "reset" then
        self.db:ResetProfile()
        self:Print("profile reset to defaults.")

    else
        self:Print("commands:")
        self:Print("  /myaddon          -- open options")
        self:Print("  /myaddon status   -- show settings")
        self:Print("  /myaddon reset    -- reset profile")
    end
end
