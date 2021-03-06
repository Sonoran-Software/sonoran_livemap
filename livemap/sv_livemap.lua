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
    local function GetUnitByApiId(apiId1, apiId2)
        if ActiveUnits[apiId1] ~= nil then
            return ActiveUnits[apiId1]
        elseif apiId2 ~= nil and ActiveUnits[apiId2] ~= nil then
            return ActiveUnits[apiId2]
        else
            return nil
        end
    end
    local function GetSourceByApiId(apiId1, apiId2)
        if apiId1 == nil then
            return nil
        end
        if string.find(apiId1, ":") then
            local split = stringsplit(apiId1, ":")
            apiId1 = split[2]
        end
        if apiId2 ~= nil then
            if string.find(apiId2, ":") then
                local split = stringsplit(apiId2, ":")
                apiId2 = split[2]
            end
        end
        for i=0, GetNumPlayerIndices()-1 do
            local player = GetPlayerFromIndex(i)
            if player then
                identifiers = GetIdentifiers(player)
                for k, v in pairs(identifiers) do
                    if v == apiId1 or (apiId2 ~= nil and v == apiId2) then
                        return player
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
    AddEventHandler('SonoranCAD::pushevents:UnitUpdate', function(unit)
        -- Strip the secret SonoranCAD API Key before passing data to clients
        unit.key = nil
        debugLog("Got a unit update: "..tostring(json.encode(unit)))
        if unit.type == "EVENT_UNIT_STATUS" then
            if unit.data.apiId1 ~= nil then
                targetPlayer = GetUnitByApiId(unit.data.apiId1)
                if targetPlayer ~= nil then
                    TriggerClientEvent("SonoranCAD::livemap:ReturnPlayerTrackStatus", targetPlayer, true)
                    TriggerClientEvent('SonoranCAD::pushevents:UnitUpdate', targetPlayer, unit)
                    debugLog(("Fired to %s with unit data %s"):format(targetPlayer, json.encode(unit)))
                else
                    debugLog("Failed to get player source for apiID: " .. unit.data.apiId1)
                end
            end
        end
    end)

    -- Listener Event to recieve data from the API listener
    RegisterServerEvent('SonoranCAD::pushevents:UnitListUpdate')
    AddEventHandler('SonoranCAD::pushevents:UnitListUpdate', function(unit)
        -- Strip the secret SonoranCAD API Key before processing
        unit.key = nil
        debugLog(("Got a %s unit: %s"):format(unit.type,tostring(json.encode(unit))))
        if unit.type == "EVENT_UNIT_LOGIN" then
            if unit.data.apiId1 ~= nil then
                targetPlayer = GetUnitByApiId(unit.data.apiId1)
                if targetPlayer == nil then
                    targetPlayer = GetSourceByApiId(unit.data.apiId1, unit.data.apiId2)
                    if targetPlayer then
                        AddUnit(targetPlayer, unit.data.apiId1)
                    else
                        return
                    end
                end
                TriggerClientEvent('sonorancad:livemap:firstSpawn', targetPlayer, true)
                TriggerClientEvent('SonoranCAD::pushevents:UnitUpdate', targetPlayer, unit)
                TriggerClientEvent("SonoranCAD::livemap:ReturnPlayerTrackStatus", targetPlayer, true)
                debugLog(("Added player: %s - %s to Active_Units"):format(targetPlayer,unit.data.apiId1))
            end
        elseif unit.type == "EVENT_UNIT_LOGOUT" then
            if unit.data.apiId1 ~= nil then
                targetPlayer = GetUnitByApiId(unit.data.apiId1)
                if targetPlayer ~= nil then
                    removeTrackedApiId(targetPlayer)
                    RemoveUnit(targetPlayer)
                    TriggerClientEvent('sonorancad:livemap:firstSpawn', targetPlayer, true)
                else
                    debugLog("Failed to get player source for apiID: " .. unit.data.apiId1)
                end
            end
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
                            local playerId = GetSourceByApiId(v.data.apiId1, v.data.apiId2)
                            if playerId then
                                AddUnit(playerId, v.data.apiId1)
                                if OldUnits[v.data.apiId1] ~= nil then
                                    OldUnits[v.data.apiId1] = nil
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