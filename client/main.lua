-- client/main.lua
--========================================================--
--  Plenix FiveM Bunkers - Client
--========================================================--

if not Config then
    print("^1[plenix-bunkers]^7 ERROR: Config is nil. Did config.lua load?")
    return
end

--========================--
-- Models / Constants
--========================--

local CLOSED_DOOR_MODEL_A = GetHashKey("gr_prop_gr_bunkeddoor_f") -- standard closed bunker door
local CLOSED_DOOR_MODEL_B = -877963371 -- alternate hash some servers use
local DOOR_TOP_MODEL = GetHashKey("gr_prop_gr_doorpart_f") -- animated top part
local DOOR_BOTTOM_MODEL = GetHashKey("gr_prop_gr_basepart_f") -- static base part

--========================--
-- Runtime State
--========================--

local isTransitionBusy = false -- blocks spam / double triggers
local lastEntranceIndex = nil -- for UseSameEntranceExit logic

local blips = {} -- created blips, for cleanup
local interiorConfigured = false -- apply interior style/sets once per session

local activeCam = nil -- current scripted camera (if any)
local activeDoor = { closed = nil, top = nil, bottom = nil } -- spawned door parts for cleanup

--========================--
-- Small Helpers
--========================--

local function DrawHelpTextThisFrame(text)
    BeginTextCommandDisplayHelp("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function IsPlayerInBunkerInterior()
    local ped = PlayerPedId()
    return GetInteriorFromEntity(ped) == (Config.Interior and Config.Interior.Id or 0)
end

local function LoadIPLs()
    for _, ipl in ipairs(Config.IPLs or {}) do
        RequestIpl(ipl)
    end
end

local function LoadDoorModels()
    RequestModel(DOOR_TOP_MODEL)
    RequestModel(DOOR_BOTTOM_MODEL)

    local timeout = 0
    while (not HasModelLoaded(DOOR_TOP_MODEL) or not HasModelLoaded(DOOR_BOTTOM_MODEL)) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end

    if timeout >= 5000 then
        print("^3[plenix-fivem-bunkers]^7 Warning: Door models took too long to load")
    end
end

--========================--
-- Sound Handling
--========================--

local audioPreloading = false

local function PreloadDoorAudioAsync()
    if audioPreloading or not (Config.Door and Config.Door.EnableSounds) then
        return
    end

    audioPreloading = true

    Citizen.CreateThread(function()
        local bank = Config.Door.SoundBank
        local tries = tonumber(Config.Door.SoundLoadTries) or 120

        for _ = 1, tries do
            -- Request both types for best compatibility across artifacts
            RequestScriptAudioBank(bank, false)
            RequestAmbientAudioBank(bank, false)

            if Config.Door.UseStreamedSounds then
                -- Preload both streams (original style)
                RequestStreamedScript(Config.Door.SoundOpen, bank)
                LoadStream(Config.Door.SoundOpen, bank)

                RequestStreamedScript(Config.Door.SoundLimit, bank)
                LoadStream(Config.Door.SoundLimit, bank)
            end

            Wait(0)
        end
    end)
end

local function PlayDoorSound(soundName)
    if not (Config.Door and Config.Door.EnableSounds) then
        return
    end

    -- Ensure we’re trying to preload, but never block the animation
    PreloadDoorAudioAsync()

    local bank = Config.Door.SoundBank

    -- Streamed playback (original-like)
    if Config.Door.UseStreamedSounds then
        StopStream()
        Wait(10)
        RequestStreamedScript(soundName, bank)
        LoadStream(soundName, bank)
        PlayStreamFrontend()
    end

    -- Frontend fallback (works on many servers even if streaming fails)
    local sid = GetSoundId()
    PlaySoundFrontend(sid, soundName, bank, true)
    ReleaseSoundId(sid)
end

--========================--
-- Blips
--========================--

local function CreateBlips()
    if not (Config.Blips and Config.Blips.Enabled) then
        return
    end

    for _, e in ipairs(Config.Entrances or {}) do
        local b = AddBlipForCoord(e.x, e.y, e.z)
        SetBlipSprite(b, Config.Blips.Sprite)
        SetBlipDisplay(b, Config.Blips.Display)
        SetBlipScale(b, Config.Blips.Scale)
        SetBlipColour(b, Config.Blips.Color)
        SetBlipAsShortRange(b, Config.Blips.ShortRange)

        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(Config.Blips.Name)
        EndTextCommandSetBlipName(b)

        blips[#blips + 1] = b
    end
end

local function RemoveBlips()
    for _, b in ipairs(blips) do
        if DoesBlipExist(b) then
            RemoveBlip(b)
        end
    end
    blips = {}
end

--========================--
-- Interior Styling / Sets
--========================--

local function ApplyInteriorSetsOnce()
    if not (Config.Interior and Config.Interior.Enabled) then
        return
    end

    if interiorConfigured then
        return
    end

    local interiorId = Config.Interior.Id
    if not interiorId or interiorId == 0 then
        return
    end

    PinInteriorInMemory(interiorId)

    for _, setName in ipairs(Config.Interior.DisableSets or {}) do
        DeactivateInteriorEntitySet(interiorId, setName)
    end

    local style = Config.Interior.Style
    if style then
        DeactivateInteriorEntitySet(interiorId, "Bunker_Style_A")
        DeactivateInteriorEntitySet(interiorId, "Bunker_Style_B")
        DeactivateInteriorEntitySet(interiorId, "Bunker_Style_C")
        ActivateInteriorEntitySet(interiorId, style)
    end

    for _, setName in ipairs(Config.Interior.EnableSets or {}) do
        ActivateInteriorEntitySet(interiorId, setName)
    end

    RefreshInterior(interiorId)
    interiorConfigured = true
end

--========================--
-- Safety Rules
--========================--

local function DisableCombatControlsThisFrame()
    DisableControlAction(0, 24, true)  -- INPUT_ATTACK
    DisableControlAction(0, 25, true)  -- INPUT_AIM
    DisableControlAction(0, 37, true)  -- INPUT_SELECT_WEAPON
    DisableControlAction(0, 140, true) -- INPUT_MELEE_ATTACK_LIGHT
    DisableControlAction(0, 141, true) -- INPUT_MELEE_ATTACK_HEAVY
    DisableControlAction(0, 142, true) -- INPUT_MELEE_ATTACK_ALTERNATE
    DisableControlAction(0, 143, true) -- INPUT_MELEE_BLOCK
    DisablePlayerFiring(PlayerPedId(), true) -- hard block firing
end

local function DisableMeleeControlsThisFrame()
    DisableControlAction(0, 140, true) -- INPUT_MELEE_ATTACK_LIGHT
    DisableControlAction(0, 141, true) -- INPUT_MELEE_ATTACK_HEAVY
    DisableControlAction(0, 142, true) -- INPUT_MELEE_ATTACK_ALTERNATE
    DisableControlAction(0, 143, true) -- INPUT_MELEE_BLOCK
end

local function ApplyBunkerSafetyRules(isInside)
    local ped = PlayerPedId()

    if isInside then
        if Config.Safety and Config.Safety.DisableCombatControlsInBunker then
            DisableCombatControlsThisFrame()
        end

        if Config.Safety and Config.Safety.DisableMeleeInBunker then
            DisableMeleeControlsThisFrame()
        end

        if Config.Safety and Config.Safety.InvincibleInBunker then
            SetEntityInvincible(ped, true)
        end

        if Config.Safety and Config.Safety.ForceUnarmedInBunker then
            SetCurrentPedWeapon(ped, GetHashKey("WEAPON_UNARMED"), true)
        end
    else
        SetEntityInvincible(ped, false) -- always restore on exit
    end
end

--========================--
-- Door Helpers
--========================--

local function GetDoorAttributes(doorEntity)
    return {
        pos = GetEntityCoords(doorEntity),
        rot = GetEntityRotation(doorEntity, 2),
        heading = GetEntityHeading(doorEntity),
    }
end

local function SetClosedDoorVisibleAndCollidable(doorEntity, isVisible, isCollidable)
    local alpha = isVisible and 255 or 0
    SetEntityAlpha(doorEntity, alpha, true)
    FreezeEntityPosition(doorEntity, true)
    SetEntityCollision(doorEntity, isCollidable, true)
end

local function CalculateDoorTopPartPosition(closedDoor, offset)
    local a = GetDoorAttributes(closedDoor)
    local rad = math.rad(a.heading)

    local worldX = offset.x * math.cos(rad) - offset.y * math.sin(rad)
    local worldY = offset.x * math.sin(rad) + offset.y * math.cos(rad)

    return vector3(a.pos.x + worldX, a.pos.y + worldY, a.pos.z + offset.z)
end

local function SpawnDoorBottomPart(closedDoor)
    local a = GetDoorAttributes(closedDoor)
    local bottom = CreateObjectNoOffset(DOOR_BOTTOM_MODEL, a.pos.x, a.pos.y, a.pos.z, true, true, true)

    SetEntityHeading(bottom, a.heading)
    SetEntityRotation(bottom, a.rot.x, a.rot.y, a.rot.z, 2, true)
    SetEntityCollision(bottom, true, true)

    return bottom
end

local function SpawnDoorTopPart(closedDoor)
    local a = GetDoorAttributes(closedDoor)
    local pos = CalculateDoorTopPartPosition(closedDoor, Config.Door.TopPartOffset)

    local top = CreateObjectNoOffset(DOOR_TOP_MODEL, pos.x, pos.y, pos.z, true, true, true)
    SetEntityHeading(top, a.heading)
    SetEntityRotation(top, a.rot.x, a.rot.y + Config.Door.TopPartExtraRotY, a.rot.z, 2, true)

    return top
end

local function ResetDoorState()
    if activeDoor.top and DoesEntityExist(activeDoor.top) then
        DeleteEntity(activeDoor.top)
    end

    if activeDoor.bottom and DoesEntityExist(activeDoor.bottom) then
        DeleteEntity(activeDoor.bottom)
    end

    if activeDoor.closed and DoesEntityExist(activeDoor.closed) then
        SetClosedDoorVisibleAndCollidable(activeDoor.closed, true, true)
    end

    activeDoor = { closed = nil, top = nil, bottom = nil }
end

--========================--
-- Door Camera
--========================--

local function CreateDoorCamera(doorEntity)
    if not (Config.Door and Config.Door.EnableCamera) then
        return nil
    end

    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    local doorPos = GetEntityCoords(doorEntity)

    SetCamCoord(
        cam,
        doorPos.x + Config.Door.CameraOffset.x,
        doorPos.y + Config.Door.CameraOffset.y,
        doorPos.z + Config.Door.CameraOffset.z
    )

    PointCamAtEntity(cam, doorEntity, 0.0, 0.0, 0.5, true)
    SetCamFov(cam, Config.Door.CameraFov)

    SetCamActive(cam, true)
    RenderScriptCams(true, false, 600, true, true)

    return cam
end

local function DestroyDoorCamera(cam)
    if not cam then
        return
    end

    SetCamActive(cam, false)
    RenderScriptCams(false, false, 600, true, true)
    DestroyCam(cam, true)
end

--========================--
-- Door Detection
--========================--

local function FindClosestClosedDoor(radius)
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)

    if DoesObjectOfTypeExistAtCoords(p.x, p.y, p.z, radius, CLOSED_DOOR_MODEL_A, true) then
        return GetClosestObjectOfType(p.x, p.y, p.z, radius, CLOSED_DOOR_MODEL_A, false, true, true)
    end

    if DoesObjectOfTypeExistAtCoords(p.x, p.y, p.z, radius, CLOSED_DOOR_MODEL_B, true) then
        return GetClosestObjectOfType(p.x, p.y, p.z, radius, CLOSED_DOOR_MODEL_B, false, true, true)
    end

    return nil
end

--========================--
-- Teleport Helpers
--========================--

local function TeleportPlayerOrVehicleTo(coords)
    local ped = PlayerPedId()

    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        SetEntityCoords(veh, coords.x, coords.y, coords.z, true, false, false, false)
    else
        SetEntityCoords(ped, coords.x, coords.y, coords.z, true, false, false, false)
    end
end

local function GetExitWorldCoords()
    if Config.Teleport and Config.Teleport.UseSameEntranceExit and lastEntranceIndex and Config.Entrances[lastEntranceIndex] then
        local e = Config.Entrances[lastEntranceIndex]

        local foundGround, groundZ = GetGroundZFor_3dCoord(e.x, e.y, e.z + 50.0, false)
        if foundGround then
            return vector3(e.x, e.y, groundZ + 1.0)
        end

        return vector3(e.x, e.y, e.z + 1.0)
    end

    return Config.Teleport.DefaultExitWorldCoords
end

--========================--
-- Enter / Exit
--========================--

local function EnterBunker(entranceIndex)
    if isTransitionBusy then
        return
    end

    isTransitionBusy = true
    lastEntranceIndex = entranceIndex

    local closedDoor = FindClosestClosedDoor(Config.Door.SearchRadius)

    if closedDoor and DoesEntityExist(closedDoor) then
        activeDoor.closed = closedDoor
        activeDoor.bottom = SpawnDoorBottomPart(closedDoor)
        activeDoor.top = SpawnDoorTopPart(closedDoor)
        SetClosedDoorVisibleAndCollidable(closedDoor, false, false)

        activeCam = CreateDoorCamera(closedDoor)

        if Config.Door.EnableSounds then
            PlayDoorSound(Config.Door.SoundOpen)
        end

        local rot = GetEntityRotation(activeDoor.top, 2)
        for i = 1, Config.Door.AnimationSteps do
            Wait(Config.Door.StepWaitMs)
            SetEntityRotation(activeDoor.top, rot.x, rot.y - i, rot.z, 2, true)

            if Config.Door.EnableSounds and i == Config.Door.PlayLimitSoundAtStep then
                PlayDoorSound(Config.Door.SoundLimit)
            end
        end
    end

    DoScreenFadeOut(Config.Door.FadeOutMs)
    while not IsScreenFadedOut() do
        Wait(0)
    end

    ResetDoorState()
    DestroyDoorCamera(activeCam)
    activeCam = nil

    TeleportPlayerOrVehicleTo(Config.Teleport.InteriorCoords)

    Wait(200) -- small delay so the interior is ready
    ApplyInteriorSetsOnce()

    DoScreenFadeIn(Config.Door.FadeInMs)
    isTransitionBusy = false
end

local function TryExitBunker()
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)

    local exitPoint = Config.Teleport.InteriorExitPoint
    local dist = #(p - exitPoint)

    local em = Config.ExitMarker or {}
    local renderDistance = em.RenderDistance or 10.0

    if em.Enabled and dist <= renderDistance then
        DrawMarker(
            em.Type or 1,
            exitPoint.x, exitPoint.y, exitPoint.z + (em.ZOffset or 0.0),
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            (em.Scale and em.Scale.x) or 1.25,
            (em.Scale and em.Scale.y) or 1.25,
            (em.Scale and em.Scale.z) or 1.25,
            (em.Color and em.Color.r) or 255,
            (em.Color and em.Color.g) or 175,
            (em.Color and em.Color.b) or 0,
            (em.Color and em.Color.a) or 120,
            false, true, 2, false,
            nil, nil, false
        )
    end

    local interactDist = em.InteractDistance or (Config.Teleport.InteriorExitInteractDistance or 1.0)
    if dist <= interactDist then
        if Config.UI and Config.UI.ShowHelpText then
            DrawHelpTextThisFrame(Config.UI.ExitText)
        end

        if IsControlJustPressed(0, Config.InteractKey) then
            DoScreenFadeOut(500)
            while not IsScreenFadedOut() do
                Wait(0)
            end

            TeleportPlayerOrVehicleTo(GetExitWorldCoords())

            DoScreenFadeIn(500)
        end
    end
end

--========================--
-- Marker Drawing (Entrances)
--========================--

local function DrawEntranceMarkers()
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)

    local m = Config.EntranceMarker or {}
    if not m.Enabled then
        return 999999.0
    end

    local closestDist = 999999.0

    for i, e in ipairs(Config.Entrances or {}) do
        local entrance = vector3(e.x, e.y, e.z)
        local dist = #(p - entrance)

        if dist < closestDist then
            closestDist = dist
        end

        if dist <= (m.RenderDistance or 10.0) then
            DrawMarker(
                m.Type or 1,
                e.x, e.y, e.z + (m.ZOffset or 0.0),
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                (m.Scale and m.Scale.x) or 1.55,
                (m.Scale and m.Scale.y) or 1.50,
                (m.Scale and m.Scale.z) or 3.00,
                (m.Color and m.Color.r) or 255,
                (m.Color and m.Color.g) or 175,
                (m.Color and m.Color.b) or 0,
                (m.Color and m.Color.a) or 100,
                false, true, 2, false,
                nil, nil, false
            )

            if dist <= (m.InteractDistance or 2.0) then
                if Config.UI and Config.UI.ShowHelpText then
                    DrawHelpTextThisFrame(Config.UI.EnterText)
                end

                if IsControlJustPressed(0, Config.InteractKey) then
                    EnterBunker(i)
                end
            end
        end
    end

    return closestDist
end

--========================--
-- Cleanup
--========================--

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    ResetDoorState()
    DestroyDoorCamera(activeCam)

    SetEntityInvincible(PlayerPedId(), false) -- safety reset
    RemoveBlips()
end)

--========================--
-- Main
--========================--

Citizen.CreateThread(function()
    LoadIPLs()
    LoadDoorModels()
    CreateBlips()

    if Config.Door and Config.Door.EnableSounds then
        PreloadDoorAudioAsync()
    end

    while true do
        local inside = IsPlayerInBunkerInterior()

        if inside then
            ApplyInteriorSetsOnce()
            ApplyBunkerSafetyRules(true)
            TryExitBunker()
            Wait(0)
        else
            ApplyBunkerSafetyRules(false)

            local nearest = DrawEntranceMarkers()
            local sleepDistance = (Config.EntranceMarker and Config.EntranceMarker.RenderDistance) or 10.0

            if nearest > sleepDistance then
                Wait(250)
            else
                Wait(0)
            end
        end
    end
end)
