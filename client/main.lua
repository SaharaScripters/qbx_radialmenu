local function convert(tbl)
    if tbl.items then
        local items = {}
        for _, v in pairs(tbl.items) do
            items[#items + 1] = convert(v)
        end

        lib.registerRadial({
            id = tbl.id..'_menu',
            items = items
        })

        return {
            id = tbl.id,
            label = tbl.title or tbl.label,
            icon = tbl.icon,
            menu = tbl.id..'_menu'
        }
    end

    local action
    if tbl.event then
        if tbl.type == 'client' then
            action = function()
                TriggerEvent(tbl.event, tbl.arg or nil)
            end
        elseif tbl.type == 'server' then
            action = function()
                TriggerServerEvent(tbl.event, tbl.arg or nil)
            end
        end
    elseif tbl.action then
        action = tbl.action(tbl.arg)
    elseif tbl.command then
        action = function()
            ExecuteCommand(tbl.command .. ' ' .. tbl.arg)
        end
    end

    return {
        id = tbl.id,
        label = tbl.title or tbl.label,
        icon = tbl.icon,
        onSelect = tbl.onSelect or function()
            if action then action() end
        end,
        keepOpen = not tbl.shouldClose or false
    }
end

local function addVehicleSeats()
    while true do
        if IsPedInAnyVehicle(cache.ped, true) and not cache.vehicle then
            local coords = GetEntityCoords(cache.ped)
            local vehicle = lib.getClosestVehicle(coords)
            if vehicle then
                local vehicleSeats = {}
                local seatTable = {
                    [1] = Lang:t('options.driver_seat'),
                    [2] = Lang:t('options.passenger_seat'),
                    [3] = Lang:t('options.rear_left_seat'),
                    [4] = Lang:t('options.rear_right_seat'),
                }
                local amountOfSeats = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle))
                for i = 1, amountOfSeats do
                    vehicleSeats[#vehicleSeats + 1] = {
                        id = 'vehicleseat'..i,
                        label = seatTable[i] or Lang:t('options.other_seats'),
                        icon = 'caret-up',
                        onSelect = function()
                            if cache.vehicle then
                                TriggerEvent('radialmenu:client:ChangeSeat', i, seatTable[i] or Lang:t('options.other_seats'))
                            else
                                exports.qbx_core:Notify(Lang:t('error.not_in_vehicle'), 'error')
                            end
                            lib.hideRadial()
                        end,
                    }
                end
                lib.registerRadial({
                    id = 'vehicleseatsmenu',
                    items = vehicleSeats
                })
            end
        end
        Wait(1000)
    end
end

local function setupVehicleMenu()
    local vehicleMenu = {
        id = 'vehicle',
        label = Lang:t('options.vehicle'),
        icon = 'car',
        menu = 'vehiclemenu'
    }

    local vehicleItems = {{
        id = 'vehicle-flip',
        label = Lang:t('options.flip'),
        icon = 'car-burst',
        onSelect = function()
            TriggerEvent('radialmenu:flipVehicle')
            lib.hideRadial()
        end,
    }}

    vehicleItems[#vehicleItems + 1] = convert(Config.VehicleDoors)
    if Config.EnableExtraMenu then vehicleItems[#vehicleItems + 1] = convert(Config.VehicleExtras) end

    if Config.VehicleSeats then
        CreateThread(addVehicleSeats)
        vehicleItems[#vehicleItems + 1] = Config.VehicleSeats
    end
    lib.registerRadial({
        id = 'vehiclemenu',
        items = vehicleItems
    })
    lib.addRadialItem(vehicleMenu)
end

local function setupRadialMenu()
    setupVehicleMenu()

    for _, v in pairs(Config.MenuItems) do
        lib.addRadialItem(convert(v))
    end

    if Config.GangInteractions[QBX.PlayerData.gang.name] then
        lib.addRadialItem(convert({
            id = 'ganginteractions',
            label = Lang:t('general.gang_radial'),
            icon = 'skull-crossbones',
            items = Config.GangInteractions[QBX.PlayerData.gang.name]
        }))
    end

    if not QBX.PlayerData.job.onduty then return end
    if not Config.JobInteractions[QBX.PlayerData.job.name] then return end

    lib.addRadialItem(convert({
        id = 'jobinteractions',
        label = Lang:t('general.job_radial'),
        icon = 'briefcase',
        items = Config.JobInteractions[QBX.PlayerData.job.name]
    }))
end

local function isPolice()
    return QBX.PlayerData.job.type == 'leo' and QBX.PlayerData.job.onduty
end

local function isEMS()
    return QBX.PlayerData.job.type == 'medic' and QBX.PlayerData.job.onduty
end

-- Events
RegisterNetEvent('radialmenu:client:deadradial', function(isDead)
    if isDead then
        local ispolice, isems = isPolice(), isEMS()
        if not ispolice or isems then return lib.disableRadial(true) end
        lib.clearRadialItems()
        lib.addRadialItem({
            id = 'emergencybutton2',
            label = Lang:t('options.emergency_button'),
            icon = 'circle-exclamation',
            onSelect = function ()
                if ispolice then
                    TriggerEvent('police:client:SendPoliceEmergencyAlert')
                elseif isems then
                    TriggerEvent('ambulance:client:SendAmbulanceEmergencyAlert')
                end
                lib.hideRadial()
            end
        })
    else
        lib.clearRadialItems()
        setupRadialMenu()
        lib.disableRadial(false)
    end
end)

RegisterNetEvent('radialmenu:client:ChangeSeat', function(id, label)
    local isSeatFree = IsVehicleSeatFree(cache.vehicle, id - 2)
    local speed = GetEntitySpeed(cache.vehicle)
    local hasHarness = exports.qbx_seatbelt:HasHarness()
    if hasHarness then
        return exports.qbx_core:Notify(Lang:t('error.race_harness_on'), 'error')
    end

    if not isSeatFree then
        return exports.qbx_core:Notify(Lang:t('error.seat_occupied'), 'error')
    end

    local kmh = speed * 3.6

    if kmh > 100.0 then
        return exports.qbx_core:Notify(Lang:t('error.vehicle_driving_fast'), 'error')
    end

    SetPedIntoVehicle(cache.ped, cache.vehicle, id - 2)
    exports.qbx_core:Notify(Lang:t('info.switched_seats', {seat = label}))
end)

RegisterNetEvent('qb-radialmenu:trunk:client:Door', function(plate, door, open)
    if not cache.vehicle then return end

    local pl = GetPlate(cache.vehicle)
    if pl ~= plate then return end

    if open then
        SetVehicleDoorOpen(cache.vehicle, door, false, false)
    else
        SetVehicleDoorShut(cache.vehicle, door, false)
    end
end)

RegisterNetEvent('qb-radialmenu:client:noPlayers', function()
    exports.qbx_core:Notify(Lang:t('error.no_people_nearby'), 'error', 2500)
end)

RegisterNetEvent('qb-radialmenu:client:openDoor', function(id)
    local door = id
    local closestVehicle = cache.vehicle or GetClosestVehicle(GetEntityCoords(cache.ped))
    if closestVehicle ~= 0 then
        if closestVehicle ~= cache.vehicle then
            local plate = GetPlate(closestVehicle)
            if GetVehicleDoorAngleRatio(closestVehicle, door) > 0.0 then
                if not IsVehicleSeatFree(closestVehicle, -1) then
                    TriggerServerEvent('qb-radialmenu:trunk:server:Door', false, plate, door)
                else
                    SetVehicleDoorShut(closestVehicle, door, false)
                end
            else
                if not IsVehicleSeatFree(closestVehicle, -1) then
                    TriggerServerEvent('qb-radialmenu:trunk:server:Door', true, plate, door)
                else
                    SetVehicleDoorOpen(closestVehicle, door, false, false)
                end
            end
        else
            if GetVehicleDoorAngleRatio(closestVehicle, door) > 0.0 then
                SetVehicleDoorShut(closestVehicle, door, false)
            else
                SetVehicleDoorOpen(closestVehicle, door, false, false)
            end
        end
    else
        exports.qbx_core:Notify(Lang:t('error.no_vehicle_found'), 'error', 2500)
    end
end)

RegisterNetEvent('radialmenu:client:setExtra', function(id)
    local extra = id
    if cache.vehicle ~= nil then
        if cache.seat == -1 then
            SetVehicleAutoRepairDisabled(cache.vehicle, true) -- Forces Auto Repair off when Toggling Extra [GTA 5 Niche Issue]
            if DoesExtraExist(cache.vehicle, extra) then
                if IsVehicleExtraTurnedOn(cache.vehicle, extra) then
                    SetVehicleExtra(cache.vehicle, extra, true)
                    exports.qbx_core:Notify(Lang:t('error.extra_deactivated', {extra = extra}), 'error', 2500)
                else
                    SetVehicleExtra(cache.vehicle, extra, false)
                    exports.qbx_core:Notify(Lang:t('success.extra_activated', {extra = extra}), 'success', 2500)
                end
            else
                exports.qbx_core:Notify(Lang:t('error.extra_not_present', {extra = extra}), 'error', 2500)
            end
        else
            exports.qbx_core:Notify(Lang:t('error.not_driver'), 'error', 2500)
        end
    end
end)

RegisterNetEvent('radialmenu:flipVehicle', function()
    if cache.vehicle then return end
    local coords = GetEntityCoords(cache.ped)
    local vehicle = lib.getClosestVehicle(coords)
    if not vehicle then return exports.qbx_core:Notify(Lang:t('error.no_vehicle_nearby'), 'error') end
    if lib.progressBar({
        label = Lang:t('progress.flipping_car'),
        duration = Config.Fliptime,
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            mouse = false,
            combat = true
        },
        anim = {
            dict = 'mini@repair',
            clip = 'fixing_a_ped'
        },
    })
    then
        SetVehicleOnGroundProperly(vehicle)
        exports.qbx_core:Notify(Lang:t('success.flipped_car'), 'success')
    else
        exports.qbx_core:Notify(Lang:t('error.cancel_task'), 'error')
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource == cache.resource then
        if LocalPlayer.state.isLoggedIn then
            setupRadialMenu()
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == cache.resource then
        lib.clearRadialItems()
    end
end)

-- Sets the metadata when the player spawns
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    setupRadialMenu()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    lib.removeRadialItem('jobinteractions')
    if job.onduty and Config.JobInteractions[job.name] then
        lib.addRadialItem(convert({
            id = 'jobinteractions',
            label = Lang:t('general.job_radial'),
            icon = 'briefcase',
            items = Config.JobInteractions[job.name]
        }))
    end
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(onDuty)
    lib.removeRadialItem('jobinteractions')
    if onDuty and Config.JobInteractions[QBX.PlayerData.job.name] then
        lib.addRadialItem(convert({
            id = 'jobinteractions',
            label = Lang:t('general.job_radial'),
            icon = 'briefcase',
            items = Config.JobInteractions[QBX.PlayerData.job.name]
        }))
    end
end)

RegisterNetEvent('QBCore:Client:OnGangUpdate', function(gang)
    lib.removeRadialItem('ganginteractions')
    if Config.GangInteractions[gang.name] and next(Config.GangInteractions[gang.name]) then
        lib.addRadialItem(convert({
            id = 'ganginteractions',
            label = Lang:t('general.gang_radial'),
            icon = 'skull-crossbones',
            items = Config.GangInteractions[gang.name]
        }))
    end
end)

local function addOption(data, id)
    data.id = data.id or id and id
    lib.addRadialItem(convert(data))
    return data.id
end

exports('AddOption', addOption)

local function removeOption(id)
    lib.removeRadialItem(id)
end

exports('RemoveOption', removeOption)
