local pluginConfig = Config.GetPluginConfig("livemap")

if pluginConfig.enabled then

    ---------------------------------------------------------------------------
    -- SonoranCAD Listener Event Handling (Recieves data from SonoranCAD)
    ---------------------------------------------------------------------------
    local ActiveUnits = {}

    function getMapActiveUnits() return ActiveUnits end

    local function AddUnit(serverId, apiId)
        serverId = tostring(serverId)
        TriggerClientEvent("SonoranCAD::livemap:PlayerIsTracked", serverId, true)
        if ActiveUnits[apiId] == nil then
            debugLog(("Adding unit %s with ApiId %s"):format(serverId, apiId))
            ActiveUnits[apiId] = serverId
        end
    end
    local function RemoveUnit(serverId)
        serverId = tostring(serverId)
        TriggerClientEvent("SonoranCAD::livemap:PlayerIsTracked", serverId, false)
        for k, v in pairs(ActiveUnits) do
            if v == serverId then
                debugLog(("Removing unit %s with ApiId %s"):format(serverId, k))
                ActiveUnits[k] = nil
                break
            end
        end
    end
    local function GetUnitByServerId(serverId)
        serverId = tostring(serverId)
        for k, v in pairs(ActiveUnits) do
            if v == serverId then
                return ActiveUnits[k]
            end
        end
        return nil
    end
    local function GetUnitByApiId(apiIds)
        for x=1, #apiIds do
            if ActiveUnits[apiIds[x]] ~= nil then
                return ActiveUnits[apiIds[x]]
            end
        end
        return nil
    end
    local function GetSourceByApiId(apiIds)
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
    -- Function to remove variable from Active_Units array
    local function removeTrackedApiId(targetPlayer)
        if GetUnitByServerId(targetPlayer) then
            RemoveUnit(targetPlayer)
        else
            debugLog(("Failed to find player %s in Active_Unit list, this might be fine."):format(targetPlayer))
        end
    end

    -- Listener Event to recieve data from the API listener
    RegisterServerEvent('SonoranCAD::pushevents:UnitUpdate')
    AddEventHandler('SonoranCAD::pushevents:UnitUpdate', function(ids, status)
        -- Strip the secret SonoranCAD API Key before passing data to clients
        local player = GetSourceByApiId(ids)
        if player then
            local unit = GetUnitByServerId(player)
            if unit then
                TriggerClientEvent("SonoranCAD::livemap:ReturnPlayerTrackStatus", targetPlayer, true)
                TriggerClientEvent('SonoranCAD::pushevents:UnitUpdate', targetPlayer, status)
            end
        end
    end)

    RegisterServerEvent('SonoranCAD::pushevents:UnitLogin')
    AddEventHandler('SonoranCAD::pushevents:UnitLogin', function(unit, isDispatch)
        local player = GetSourceByApiId(unit.apiIds)
        if player then
            local mapId = GetIdentifiers(player)[Config.primaryIdentifier]
            AddUnit(player, mapId)
            TriggerClientEvent('sonorancad:livemap:firstSpawn', player, true)
            TriggerClientEvent('SonoranCAD::pushevents:UnitLogin', targetPlayer, unit)
            TriggerClientEvent("SonoranCAD::livemap:ReturnPlayerTrackStatus", targetPlayer, true)
            debugLog(("Added player: %s - %s to Active_Units"):format(targetPlayer,mapId))
        else
            debugLog("Unable to find API ID?")
        end
    end)

    RegisterServerEvent('SonoranCAD::pushevents:UnitLogout')
    AddEventHandler('SonoranCAD::pushevents:UnitLogout', function(apiIds)
        local targetPlayer = GetSourceByApiId(unit.apiIds)
        if targetPlayer then
            removeTrackedApiId(targetPlayer)
            RemoveUnit(targetPlayer)
            TriggerClientEvent('sonorancad:livemap:firstSpawn', targetPlayer, true)
        else
            debugLog("Unknown unit in logout event")
        end
    end)

    AddEventHandler("playerDropped", function()
        RemoveUnit(source)
    end)

    registerApiType("GET_ACTIVE_UNITS", "emergency")
    Citizen.CreateThread(function()
        local OldUnits = {}
        for k, v in pairs(ActiveUnits) do
            OldUnits[k] = v
        end
        while true do
            if GetNumPlayerIndices() > 0 then
                local payload = { serverId = Config.serverId}
                performApiRequest({payload}, "GET_ACTIVE_UNITS", function(runits)
                    local allUnits = json.decode(runits)
                    if allUnits ~= nil then
                        for k, v in pairs(allUnits) do
                            local playerId = GetSourceByApiId(v.data.apiIds)
                            if playerId then
                                local mapId = GetIdentifiers(playerId)[Config.primaryIdentifier]
                                AddUnit(playerId, mapId)
                                if OldUnits[mapId] ~= nil then
                                    OldUnits[mapId] = nil
                                end
                            end
                        end
                    end
                    for k, v in pairs(OldUnits) do
                        debugLog(("Removing player %s (API ID: %s), not on units list"):format(k, v))
                        RemoveUnit(v)
                    end
                end)
            end
            Citizen.Wait(60000)
        end
    end)
end