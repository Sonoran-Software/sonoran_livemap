CreateThread(function() Config.LoadPlugin("livemap", function(pluginConfig)

if pluginConfig.enabled then

    local TrackedPlayers = {}

    RegisterCommand("trackedplayers", function() print(json.encode(TrackedPlayers)) end, true)

    local function GetSourceByApiId(apiIds)
        if apiIds == nil then return nil end
        for x=1, #apiIds do
            for i=0, GetNumPlayerIndices()-1 do
                local player = GetPlayerFromIndex(i)
                if player then
                    local identifiers = GetIdentifiers(player)
                    for type, id in pairs(identifiers) do
                        if id == apiIds[x] then
                            return player
                        end
                    end
                end
            end
        end
        return nil
    end 

    CreateThread(function()
        if pluginConfig.refreshTimer == nil then
            pluginConfig.refreshTimer = 5000
        end
        if pluginConfig.hideNonUnits == nil then
            pluginConfig.hideNonUnits = true
        end
        while true do
            Wait(pluginConfig.refreshTimer)
            for i=0, GetNumPlayerIndices()-1 do
                local player = GetPlayerFromIndex(i)
                local unit = GetUnitByPlayerId(player)
                --debugLog(("idx: %s - player: %s - unit: %s"):format(i, player, unit ~= nil and json.encode(unit) or nil))
                if unit then
                    if TrackedPlayers[player] == nil then
                        debugLog(("Add %s to tracking"):format(player))
                        TriggerClientEvent("SonoranCAD::livemap:AddPlayer", player, unit)
                    end
                    TrackedPlayers[player] = unit
                elseif not pluginConfig.hideNonUnits then
                    if TrackedPlayers[player] == nil then
                        debugLog(("Add civilian %s to tracking"):format(player))
                        TriggerClientEvent("SonoranCAD::livemap:AddPlayer", player, { id = 0 })
                    end
                    TrackedPlayers[player] = { id = 0 }
                else
                    if TrackedPlayers[player] ~= nil then
                        TrackedPlayers[player] = nil
                        TriggerClientEvent("SonoranCAD::livemap:RemovePlayer", player)
                        debugLog(("Unit %s no longer tracked %s"):format(player, json.encode(unit)))
                    end
                end
            end
        end
    end)
    -- Listener Event to recieve data from the API listener
    RegisterServerEvent('SonoranCAD::pushevents:UnitUpdate')
    AddEventHandler('SonoranCAD::pushevents:UnitUpdate', function(unit, status)
        local player = GetSourceByApiId(unit.data.apiIds)
        debugLog(("player: %s - ids: %s - status: %s - Track: %s"):format(player, json.encode(unit.data.apiIds), status, TrackedPlayers[player]))
        if player and TrackedPlayers[player] ~= nil then
            local unit = TrackedPlayers[player]
            unit.status = status
            TriggerClientEvent("SonoranCAD::livemap:UpdatePlayer", player, unit)
        end
    end)
end
end) end)