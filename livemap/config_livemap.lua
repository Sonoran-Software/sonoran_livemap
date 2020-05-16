--[[
    Sonoran Plugins

    Plugin Configuration

    Put all needed configuration in this file.
]]
local config = {
    pluginName = "livemap", -- name your plugin here
    pluginVersion = "1.0", -- version of your plugin
    pluginAuthor = "SonoranCAD", -- author
    requiresPlugins = {"locations", "pushevents"}, -- required plugins for this plugin to work, separated by commas

    -- put your configuration options below
    jobsTracked = {"police", "ambulance"}
}

-- IMPORTANT: UNCOMMENT THE BELOW LINE ON ACTUAL PLUGINS!

Config.RegisterPluginConfig(config.pluginName, config)