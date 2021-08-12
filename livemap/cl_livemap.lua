--[[
        SonoranCAD FiveM - A SonoranCAD integration for FiveM servers
              Copyright (C) 2020  Sonoran Software Systems LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program in the file "LICENSE".  If not, see <http://www.gnu.org/licenses/>.
]]

---------------------------------------------------------------------------
-- Client Data Processing for Live Map Blip
---------------------------------------------------------------------------
-- Default blip datafields to be initialized and updated
CreateThread(function() Config.LoadPlugin("livemap", function(pluginConfig)

    if pluginConfig.enabled then

        if Config == nil then
            errorLog("Failed to load core configuration.")
        end

        RegisterNetEvent("SonoranCAD::livemap:AddPlayer")
        RegisterNetEvent("SonoranCAD::livemap:RemovePlayer")
        RegisterNetEvent("SonoranCAD::livemap:UpdatePlayer")

        local playerData = {
            ["pos"] = { x=0,y=0,z=0 },
            ["icon"] = 6,
            ["name"] = GetPlayerName(PlayerId(-1)),
            ["status"] = nil,
            ["unitNumber"] = nil,
            ["department"] = nil,
            ["subdivision"] = nil,
            ["assignment"] = nil
        }

        local lastSentData = {
            ["pos"] = { x=0,y=0,z=0 },
            ["icon"] = 6,
            ["name"] = nil,
            ["status"] = nil,
            ["unitNumber"] = nil,
            ["department"] = nil,
            ["subdivision"] = nil,
            ["assignment"] = nil
        }

        local sendUpdates = false

        CreateThread(function()
            while not NetworkIsPlayerActive(PlayerId(-1)) do
                Wait(10)
            end
            Wait(1000)
            if isPluginLoaded('esxsupport') then
                GetIdentity(function(esxIdentity)
                    if esxIdentity ~= nil then
                        if esxIdentity.firstName ~= nil and esxIdentity.lastName ~= nil then
                            playerData.name = (esxIdentity.firstName or "")..' '..(esxIdentity.lastName) or ""
                        elseif esxIdentity.name ~= nil then
                            playerData.name = esxIdentity.name
                        end
                    end
                end)
            end
        end)

        AddEventHandler("SonoranCAD::livemap:AddPlayer", function(unit)
            debugLog("[livemap] Adding to map: "..json.encode(unit))
            if unit.id > 0 then
                local u = unit.data
                playerData.status = Config.statusLabels[unit.status + 1]
                playerData.unitNumber = u.unitNum
                playerData.department = u.department
                playerData.subdivision = u.subdivision ~= "" and u.subdivision or nil
                if pluginConfig.useCadName then
                    playerData.name = u.name
                end
            end
            TriggerServerEvent("sonorancad:livemap:playerSpawned")
            sendUpdates = true
        end)
        
        AddEventHandler("SonoranCAD::livemap:RemovePlayer", function()
            debugLog("[livemap] No longer tracking")
            sendUpdates = false
            lastSentData = {}
            TriggerServerEvent("sonorancad:livemap:RemovePlayer")
        end)

        AddEventHandler("SonoranCAD::livemap:UpdatePlayer", function(unit)
            local u = unit.data
            playerData.status = Config.statusLabels[unit.status + 1]
            playerData.unitNumber = u.unitNum
            playerData.department = u.department
            playerData.subdivision = u.subdivision ~= "" and u.subdivision or nil
            if pluginConfig.useCadName then
                playerData.name = u.name
            end
        end)

        -- Function to change live map icons based on type of vehicle player is in, does not take in account addon/dlc vehicles
        local function doIconUpdate()
            local ped = PlayerPedId()
            local newSprite = 6 -- Default to the player one

            if IsEntityDead(ped) then
                newSprite = 163 -- Using GtaOPassive since I don't have a "death" icon :(
            else
                if IsPedSittingInAnyVehicle(ped) then
                    -- Change icon to vehicle
                    -- our temp table should still have the latest vehicle
                    local vehicle = GetVehiclePedIsIn(PlayerPedId(), 0)
                    local vehicleModel = GetEntityModel(vehicle)
                    local h = GetHashKey

                    if vehicleModel == h("rhino") then
                        newSprite = 421
                    elseif (vehicleModel == h("lazer") or vehicleModel == h("besra") or vehicleModel == h("hydra")) then
                        newSprite = 16 -- Jet
                    elseif IsThisModelAPlane(vehicleModel) then
                        newSprite = 90 -- Airport (plane icon)
                    elseif IsThisModelAHeli(vehicleModel) then
                        newSprite = 64 -- Helicopter
                    elseif (vehicleModel == h("dinghy") or vehicleModel == h("dinghy2") or vehicleModel == h("dinghy3")) then
                        newSprite = 404 -- Dinghy
                    elseif (vehicleModel == h("submersible") or vehicleModel == h("submersible2")) then
                        newSprite = 308 -- Sub
                    elseif IsThisModelABoat(vehicleModel) then
                        newSprite = 410
                    elseif (IsThisModelABike(vehicleModel) or IsThisModelABicycle(vehicleModel)) then
                        newSprite = 226
                    elseif (vehicleModel == h("policeold2") or vehicleModel == h("policeold1") or vehicleModel == h("policet") or vehicleModel == h("police") or vehicleModel == h("police2") or vehicleModel == h("police3") or vehicleModel == h("policeb") or vehicleModel == h("riot") or vehicleModel == h("sheriff") or vehicleModel == h("sheriff2") or vehicleModel == h("pranger")) then
                        newSprite = 56 -- PoliceCar
                    elseif vehicleModel == h("taxi") then
                        newSprite = 198
                    elseif (vehicleModel == h("brickade") or vehicleModel == h("stockade") or vehicleModel == h("stockade2")) then
                        newSprite = 66 -- ArmoredTruck
                    elseif (vehicleModel == h("towtruck") or vehicleModel == h("towtruck")) then
                        newSprite = 68
                    elseif (vehicleModel == h("trash") or vehicleModel == h("trash2")) then
                        newSprite = 318
                    else
                        newSprite = 225 -- PersonalVehicleCar
                    end
                end
            end
            -- Only update icon if there is a change
            if playerData["icon"] ~= newSprite then
                playerData["icon"] = newSprite
            end
        end

        Citizen.CreateThread(function()
            local isFirstRun = true
            while not Config.primaryIdentifier or not NetworkIsPlayerActive(PlayerId()) do
                Wait(10)
            end
            while true do
                Citizen.Wait(1000)
                if sendUpdates then
                    doIconUpdate()
                    local x,y,z = table.unpack(GetEntityCoords(PlayerPedId()))
                    local x1,y1,z1 = 0,0,0
                    if lastSentData["pos"] ~= nil then
                        x1,y1,z1 = lastSentData["pos"].x, lastSentData["pos"].y, lastSentData["pos"].z
                    end
                    local dist = Vdist(x, y, z, x1, y1, z1)
                    if (dist >= 5) then
                        playerData.pos = {x = x, y=y, z=z}
                    end
                    for key, value in pairs(playerData) do
                        if value ~= lastSentData[key] then
                            local displayName = pluginConfig.infoDisplayNames[key]
                            if displayName then
                                TriggerServerEvent("sonorancad:livemap:UpdatePlayerData", displayName, value)
                                lastSentData[key] = value
                            end
                        end
                    end
                    isFirstRun = false
                end
            end
        end)
    end
end) end)