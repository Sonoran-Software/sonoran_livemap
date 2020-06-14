local pluginConfig = Config.GetPluginConfig("livemap")

if pluginConfig.enabled then

    ---------------------------------------------------------------------------
    -- SonoranCAD Listener Event Handling (Recieves data from SonoranCAD)
    ---------------------------------------------------------------------------
    -- Tracking of Active Units via SonoranCAD
    local Unit = {
        apiId = nil,
        serverId = nil
    }
    function Unit.Create(serverId, apiId)
        local self = shallowcopy(Unit)
        debugLog(("create %s with %s"):format(serverId, apiId))
        assert(apiId ~= nil, 'apiId required, but not supplied')
        self.serverId = tostring(serverId)
        self.apiId = apiId
        return self
    end
    Active_Units = {}
    local lockedUnits = false
    local function getActiveUnits()
        while lockedUnits do
            Wait(10)
        end
        return Active_Units
    end
    local function getUnitByServerId(serverId)
        for i = 1, #getActiveUnits(), 1 do
            if getActiveUnits()[i].serverId == tostring(serverId) then
                return getActiveUnits()[i], i
            end
        end
        return nil
    end

    -- Function to figure out the player server id from their steamHex
    function getPlayerSource(identifier)
        local activePlayers = GetPlayers();
        for i,player in pairs(activePlayers) do
            local identifiers = GetIdentifiers(player)
            local primary = identifiers[Config.primaryIdentifier]
            debugLog(("Check %s has identifier %s = %s"):format(player, primary, identifier))
            if primary == identifier then
                return player
            end
        end
    end

    -- Function to remove variable from Active_Units array
    local function removeTrackedApiId(targetPlayer)
        local search, index = getUnitByServerId(targetPlayer)
        if search then
            Active_Units[index] = nil
            debugLog(("Removed player: %s from Active_Units"):format(targetPlayer))
            TriggerClientEvent("SonoranCAD::livemap:ReturnPlayerTrackStatus", targetPlayer, false)
            TriggerClientEvent("sonorancad:livemap:RemovePlayer", targetPlayer)
        else
            debugLog(("Failed to find player %s in Active_Unit list, this might be fine."):format(targetPlayer))
        end
    end

    -- Server Event to allow clients to check tracked status
    RegisterServerEvent("SonoranCAD::livemap:IsPlayerTracked")
    AddEventHandler("SonoranCAD::livemap:IsPlayerTracked", function()
        local identifiers = GetIdentifiers(source)
        local primary = identifiers[Config.primaryIdentifier]
        local search, index = getUnitByServerId(source)
        if search and search.apiId == primary then
            TriggerClientEvent("SonoranCAD::livemap:ReturnPlayerTrackStatus", source, true)
            debugLog(("Player is tracked: %s - %s returning TRUE"):format(source,primary))
        else
            TriggerClientEvent("SonoranCAD::livemap:ReturnPlayerTrackStatus", source, false)
            debugLog(("Player is NOT tracked: %s - %s returning FALSE"):format(source,primary))
        end
    end)

    -- Listener Event to recieve data from the API listener
    RegisterServerEvent('SonoranCAD::pushevents:UnitUpdate')
    AddEventHandler('SonoranCAD::pushevents:UnitUpdate', function(unit)
        -- Strip the secret SonoranCAD API Key before passing data to clients
        unit.key = nil
        debugLog("Got a unit update: "..tostring(json.encode(unit)))
        if unit.type == "EVENT_UNIT_STATUS" then
            if unit.data.apiId1 ~= nil then
                targetPlayer = getPlayerSource(unit.data.apiId1)
                if targetPlayer ~= nil then
                    local search, index = getUnitByServerId(targetPlayer)
                    if not search then
                        local unitObj = Unit.Create(targetPlayer, unit.data.apiId1)
                        table.insert(Active_Units, unitObj)
                        TriggerClientEvent("SonoranCAD::livemap:ReturnPlayerTrackStatus", targetPlayer, true)
                    end
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
                targetPlayer = getPlayerSource(unit.data.apiId1)
                if targetPlayer ~= nil then
                    local search, index = getUnitByServerId(targetPlayer)
                    if not search then
                        local unitObj = Unit.Create(targetPlayer, unit.data.apiId1)
                        table.insert(Active_Units, unitObj)
                        TriggerClientEvent('sonorancad:livemap:firstSpawn', targetPlayer, true)
                        TriggerClientEvent('SonoranCAD::pushevents:UnitUpdate', targetPlayer, unit)
                        TriggerClientEvent("SonoranCAD::livemap:ReturnPlayerTrackStatus", targetPlayer, true)
                        debugLog(("Added player: %s - %s to Active_Units"):format(targetPlayer,unit.data.apiId1))
                    else
                        debugLog("Warning: skipped unit login for "..targetPlayer)
                    end
                else
                    debugLog("Failed to get player source for apiID: " .. unit.data.apiId1)
                end
            end
        elseif unit.type == "EVENT_UNIT_LOGOUT" then
            if unit.data.apiId1 ~= nil then
                targetPlayer = getPlayerSource(unit.data.apiId1)
                if targetPlayer ~= nil then
                    removeTrackedApiId(targetPlayer)
                    TriggerClientEvent('sonorancad:livemap:firstSpawn', targetPlayer, true)
                else
                    debugLog("Failed to get player source for apiID: " .. unit.data.apiId1)
                end
            end
        end
    end)

    registerApiType("GET_ACTIVE_UNITS", "emergency")
    Citizen.CreateThread(function()
        while true do
            local units = {}
            Active_Units = {}
            local payload = { serverId = Config.serverId}
            lockedUnits = true
            performApiRequest({payload}, "GET_ACTIVE_UNITS", function(runits)
                local allUnits = json.decode(runits)
                for k, v in pairs(allUnits) do
                    local id = getPlayerSource(v.data.apiId1)
                    if id ~= nil then
                        local unit = Unit.Create(id, v.data.apiId1)
                        table.insert(units, unit)
                    end
                end
            end)
            for i = 1, #units, 1 do
                table.insert(Active_Units, units[i])
            end
            lockedUnits = false
            Citizen.Wait(60000)
        end
    end)
end