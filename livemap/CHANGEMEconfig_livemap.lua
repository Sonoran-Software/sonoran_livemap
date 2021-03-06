--[[
    Sonoran Plugins

    Plugin Configuration

    Put all needed configuration in this file.
]]
local config = {
    enabled = false,
    pluginName = "livemap", -- name your plugin here
    pluginAuthor = "SonoranCAD", -- author
    requiresPlugins = {"locations", "pushevents"}, -- required plugins for this plugin to work, separated by commas
    -- Enable setting blips on the in-game and live map when calls come in
    enableCallerBlips = true
}

if config.enabled then
    Config.RegisterPluginConfig(config.pluginName, config)
end