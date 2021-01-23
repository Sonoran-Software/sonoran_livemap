local pluginConfig = Config.GetPluginConfig("livemap")

if pluginConfig.enableCallerBlips and pluginConfig.enabled then
    if not isPluginLoaded("callcommands") then
        warnLog("[livemap] The callcommands plugin is required for the blips feature.")
        return
    end
    local CurrentCalls = {}

    local useBlip = 459
    local useColor = 59

    AddEventHandler("SonoranCAD::pushevents:IncomingCadCall", function(call, apiIds)
        if call.metaData ~= nil then
            if call.metaData.callerApiId ~= nil then
                CurrentCalls[call.callId] = { location = call.location, description = call.description, source = call.metaData.callerApiId, identifier = call.metaData.callerApiId }
                TriggerClientEvent("SonoranCAD::livemap:Emergency", call.metaData.callerPlayerId, call.caller, useBlip, useColor, "Emergency Call", call.description)
                TriggerClientEvent("SonoranCAD::livemap:GetCurrentLocation", call.metaData.callerPlayerId, call.description) 
            else
                debugLog(("Failed to process call, missing caller metadata: %s"):format(json.encode(call)))
            end
        else
            debugLog(("Failed to process call, missing metadata: %s"):format(json.encode(call)))
        end
    end)

    AddEventHandler("SonoranCAD::pushevents:CadCallRemoved", function(callId)
        if CurrentCalls[tonumber(callId)] ~= nil then
            local call = CurrentCalls[tonumber(callId)]
            if call.origin911 == nil then -- no call was created for this
                TriggerClientEvent("SonoranCAD::livemap:RemoveCallBlip", -1, call.source)
                TriggerClientEvent("SonoranCAD::livemap:ClosedCall", call.source)
                CurrentCalls[tonumber(callId)] = nil
            end
        end
    end)

    RegisterNetEvent("SonoranCAD::livemap:CurrentLocation")
    AddEventHandler("SonoranCAD::livemap:CurrentLocation", function(coords, description)
        local source = source
        for k, serverId in pairs(getMapActiveUnits()) do
            TriggerClientEvent("SonoranCAD::livemap:AddCallBlip", serverId, coords, useBlip, useColor, description, source)
        end
        debugLog("Got location")
    end)

    RegisterServerEvent("SonoranCAD::pushevents:DispatchEvent")
    AddEventHandler("SonoranCAD::pushevents:DispatchEvent", function(data)
        local dispatchType = data.dispatch_type
        local dispatchData = data.dispatch
        local metaData = data.dispatch.metaData
        if metaData == nil then
            warnLog("Expected some metadata from this call, but it was nil. Is your callcommands plugin updated, or is your custom function not passing needed data? Ignoring!")
            return
        end
        if dispatchType == "CALL_NEW" then
            local originalId = metaData.origin911 ~= nil and metaData.origin911 or metaData.createdFromId
            -- new call, check if it was created from dispatch screen
            if originalId ~= nil then
                local call = CurrentCalls[tonumber(originalId)]
                if call ~= nil then
                    CurrentCalls[tonumber(originalId)].origin911 = metaData.origin911
                    debugLog("Mapped new call successfully")
                else
                    debugLog(("Failed to find call to map to: %s"):format(json.encode(CurrentCalls)))
                end
            else
                debugLog("Unsupported call, lacks origin call ID")
            end
        elseif dispatchType == "CALL_CLOSE" then
            -- call closed, remove matching blips
            local originalId = metaData.origin911 ~= nil and metaData.origin911 or metaData.createdFromId
            local call = CurrentCalls[tonumber(originalId)]
            if call ~= nil then
                TriggerClientEvent("SonoranCAD::livemap:RemoveCallBlip", -1, call.source)
                TriggerClientEvent("SonoranCAD::livemap:ClosedCall", call.source)
                CurrentCalls[tonumber(originalId)] = nil
            else
                debugLog(("Unable to map closed call %s to an existing blip: %s"):format(originalId, json.encode(CurrentCalls)))
            end
        end
    end)
end