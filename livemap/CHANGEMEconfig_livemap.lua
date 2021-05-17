--[[
    Sonoran Plugins

    Plugin Configuration

    Put all needed configuration in this file.
]]
local config = {
    enabled = false,
    pluginName = "livemap", -- name your plugin here
    pluginAuthor = "SonoranCAD", -- author
    configVersion = "2.0.0",
    -- if the player isn't logged into the CAD, don't show them
    hideNonUnits = true, 
    -- how often to check if units change state
    refreshTimer = 5000, 
    -- Show incoming calls on the map?
    enableCallerBlips = true, 
    -- Use in-CAD name for online units? false uses in-game name or ESX name (if esxsupport plugin is loaded)
    useCadName = true,
    infoDisplayNames = {
        -- localization, edit the values only
        ["pos"] = "pos",
        ["icon"] = "icon",
        ["name"] = "name",
        ["status"] = "Status",
        ["unitNumber"] = "Unit Number",
        ["department"] = "Department",
        ["subdivision"] = "Subdivision",
        ["assignment"] = "Call Assignment"
    }
}

if config.enabled then
    Config.RegisterPluginConfig(config.pluginName, config)
end