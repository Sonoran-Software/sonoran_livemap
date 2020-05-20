---------------------------------------------------------------------------
-- SonoranCAD Listener Event Handling (Recieves data from SonoranCAD)
---------------------------------------------------------------------------
-- Tracking of Active Units via SonoranCAD
Active_Units = {}

-- Function to figure out the player server id from their steamHex
function getPlayerSource(identifier)
    local activePlayers = GetPlayers();
    for i,player in pairs(activePlayers) do
        local identifiers = GetIdentifiers(player)
        local primary = identifiers[Config.primaryIdentifier]
        debugLog(("Check %s has identifier %s"):format(player, primary))
        if primary == string.lower(primary) then
            return player
        end
    end
end

-- Function to remove variable from Active_Units array
local function removeTrackedApiId(targetPlayer)
    for k, v in pairs(Active_Units) do
        if v == targetPlayer then
            Active_Units[k] = nil
            debugLog(("Removed player: %s to Active_Units"):format(targetPlayer))
            break
        end
    end
    debugLog(("Failed to find player %s in Active_Unit list, this might be fine."):format(targetPlayer))
end

-- Server Event to allow clients to check tracked status
RegisterServerEvent("SonoranCAD::livemap:IsPlayerTracked")
AddEventHandler("SonoranCAD::livemap:IsPlayerTracked", function()
    local identifiers = GetIdentifiers(source)
    local primary = identifiers[Config.primaryIdentifier]
    local IsTracked = false
    for k, v in pairs(Active_Units) do
        print(v .. " - " .. source)
        if tonumber(v) == tonumber(source) then
            TriggerClientEvent("SonoranCAD::livemap:ReturnPlayerTrackStatus", source, true)
            debugLog(("Player is tracked: %s - %s returning TRUE"):format(source,primary))
            IsTracked = true
        end
    end
    if not IsTracked then
        TriggerClientEvent("SonoranCAD::livemap:ReturnPlayerTrackStatus", source, false)
        debugLog(("Player is NOT tracked: %s - %s returning FALSE"):format(source,primary))
    end
end
)

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
                TriggerClientEvent('SonoranCAD::pushevents:UnitUpdate', targetPlayer, unit)
                debugLog(("Fired to %s with unit data %s"):format(targetPlayer, json.encode(unit)))
            else
                debugLog("Failed to get player source for apiID: " .. unit.data.apidId1)
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
                table.insert(Active_Units,targetPlayer)
                TriggerClientEvent('sonorancad:livemap:firstSpawn', targetPlayer, true)
                TriggerClientEvent('SonoranCAD::pushevents:UnitUpdate', targetPlayer, unit)
                debugLog(("Added player: %s - %s to Active_Units"):format(targetPlayer,unit.data.apiId1))
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

function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k,v in pairs(o) do
        if type(k) ~= 'number' then k = '"'..k..'"' end
        s = s .. '['..k..'] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

registerApiType("GET_ACTIVE_UNITS", "emergency")
Citizen.CreateThread(function()
    while true do
        local units = {}
        local payload = { serverId = Config.serverId}
        performApiRequest({payload}, "GET_ACTIVE_UNITS", function(runits)
            local allUnits = json.decode(runits)
            for k, v in pairs(allUnits) do
                print(json.encode(v))
                local id = getPlayerSource(v.data.apidId1)
                if id ~= nil then
                    table.insert( units,id )
                end
            end
            Active_Units = units
            print(dump(Active_Units))
        end)
        Citizen.Wait(60000)
    end
end)
