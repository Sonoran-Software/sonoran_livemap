local pluginConfig = Config.GetPluginConfig("livemap")

if pluginConfig.enabled then

    RegisterServerEvent("SonoranCAD::core:AddPlayer")
    RegisterServerEvent("SonoranCAD::core:RemovePlayer")
    AddEventHandler("SonoranCAD::core:AddPlayer", function(playerId, unit)
        TriggerClientEvent("SonoranCAD::livemap:PlayerIsTracked", playerId, true)
    end)

    AddEventHandler("SonoranCAD::core:RemovePlayer", function(playerId, unit)
        TriggerClientEvent("SonoranCAD::livemap:PlayerIsTracked", playerId, false)
    end)

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
    -- Listener Event to recieve data from the API listener
    RegisterServerEvent('SonoranCAD::pushevents:UnitUpdate')
    AddEventHandler('SonoranCAD::pushevents:UnitUpdate', function(ids, status)
        local player = GetSourceByApiId(ids)
        if player then
            local unit = GetUnitByPlayerId(player)
            if unit then
                TriggerClientEvent("SonoranCAD::livemap:ReturnPlayerTrackStatus", player, true)
                TriggerClientEvent('SonoranCAD::pushevents:UnitUpdate', player, status)
                TriggerClientEvent("SonoranCAD::livemap:UnitAdd", player, unit)
            else
                debugLog("Unable to find unit? Cache: "..json.encode(GetUnitCache()))
            end
        end
    end)

    RegisterServerEvent('SonoranCAD::pushevents:UnitLogin')
    AddEventHandler('SonoranCAD::pushevents:UnitLogin', function(unit, isDispatch)
        local player = GetSourceByApiId(unit.data.apiIds)
        if player then
            TriggerClientEvent('sonorancad:livemap:firstSpawn', player, true)
            TriggerClientEvent('SonoranCAD::pushevents:UnitLogin', player, unit)
            TriggerClientEvent("SonoranCAD::livemap:ReturnPlayerTrackStatus", player, true)
            TriggerClientEvent("SonoranCAD::livemap:UnitAdd", player, unit)
        else
            debugLog("Unable to find API ID? Got: "..json.encode(unit))
        end
    end)

    RegisterServerEvent('SonoranCAD::pushevents:UnitLogout')
    AddEventHandler('SonoranCAD::pushevents:UnitLogout', function(id)
        local targetPlayer = GetUnitById(id)
        if targetPlayer then
            TriggerClientEvent('sonorancad:livemap:firstSpawn', targetPlayer, true)
        else
            debugLog("Unknown unit in logout event")
        end
    end)

    AddEventHandler("SonoranCAD::core:AddPlayer", function(playerId, unit)
        TriggerClientEvent("SonoranCAD::livemap:PlayerIsTracked", playerId, true)
        TriggerClientEvent('sonorancad:livemap:firstSpawn', playerId, true)
    end)

    AddEventHandler("SonoranCAD::core:RemovePlayer", function(playerId, unit)
        TriggerClientEvent("SonoranCAD::livemap:PlayerIsTracked", playerId, false)
        TriggerClientEvent('sonorancad:livemap:firstSpawn', playerId, true)
    end)
end