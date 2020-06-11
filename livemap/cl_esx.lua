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

local pluginConfig = Config.GetPluginConfig("livemap")

Citizen.CreateThread(function()
    while Config.serverType == nil do
        Wait(10)
    end
    if pluginConfig.enabled then
        ---------------------------------------------------------------------------
        -- ESX Integration Initialization/Events/Functions
        ---------------------------------------------------------------------------
        -- Initialize ESX Framework hooks to allow obtaining data
        PlayerData = {}
        ESX = nil

        Citizen.CreateThread(function()
            if Config.serverType ~= "esx" then
                return
            end
            while ESX == nil do
                TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
                Citizen.Wait(10)
            end

            while ESX.GetPlayerData() == nil do
                Citizen.Wait(10)
            end

            PlayerData = ESX.GetPlayerData()
        end)

        if Config.serverType == "esx" then
            -- Listen for when new players load into the game
            RegisterNetEvent('esx:playerLoaded')
            AddEventHandler('esx:playerLoaded', function(xPlayer)
            PlayerData = xPlayer
            end)
            -- Listen for when jobs are changed in esx_jobs
            RegisterNetEvent('esx:setJob')
            AddEventHandler('esx:setJob', function(job)
            PlayerData.job = job
            TriggerEvent('sonorancad:livemap:firstSpawn', true)
            end)
            -- Function to check if player's framwork job type is to be tracked on the live map
            function IsTrackedEmployee()
                for i,job in pairs(pluginConfig.jobsTracked) do
                    if PlayerData.job.name == job then
                        return true
                    end
                end
                return false
            end
            -- Function to return esx_identity data on the client from server
            -- This event listens for data from the server when requested
            local recievedIdentity = false
            returnedIdentity = nil
            RegisterNetEvent('sonorancad:returnIdentity')
            AddEventHandler('sonorancad:returnIdentity', function(data)
                recievedIdentity = true
                if data.job == nil then
                    print("Warning: no identity data was found.")
                else
                    returnedIdentity = data
                end
            end)
            -- This function requests data from the server
            function GetIdentity(callback)
                recievedIdentity = false
                returnIdentity = false
                TriggerServerEvent("sonorancad:getIdentity")
                local timeStamp = GetGameTimer()
                while not recievedIdentity do
                    Citizen.Wait(0)
                end
                callback(returnedIdentity)
            end
        end
    end
end)
