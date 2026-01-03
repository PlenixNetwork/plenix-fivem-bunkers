-- config.lua
--========================================================--
--  Plenix Bunkers - Configuration
--========================================================--

Config = {
    -- Keybinds
    InteractKey = 38, -- INPUT_CONTEXT (E)

    -- UI prompts
    UI = {
        ShowHelpText = false, -- true = show GTA help text near markers
        EnterText = "Press ~INPUT_CONTEXT~ to enter the bunker.", -- entrance prompt
        ExitText  = "Press ~INPUT_CONTEXT~ to exit the bunker.",  -- exit prompt
    },

    -- Entrance marker settings (world)
    EntranceMarker = {
        Enabled = true, -- show entrance markers
        RenderDistance = 10.0, -- how far away the marker is visible
        InteractDistance = 2.0, -- press key distance
        Type = 1, -- marker type (1 = cylinder)
        Scale = vector3(1.55, 1.50, 3.00), -- marker size
        Color = { r = 255, g = 175, b = 0, a = 100 }, -- marker color/alpha
        ZOffset = 0.0, -- adjust if marker floats/sinks (usually 0.0 outside)
    },

    -- Exit marker settings (inside interior)
    ExitMarker = {
        Enabled = true, -- show exit marker inside bunker
        RenderDistance = 10.0, -- how far away the marker is visible
        InteractDistance = 1.0, -- press key distance
        Type = 1, -- marker type (1 = cylinder)
        Scale = vector3(1.25, 1.25, 1.25), -- marker size (smaller indoors)
        Color = { r = 255, g = 175, b = 0, a = 120 }, -- marker color/alpha
        ZOffset = -1.0, -- interior markers often need a small negative Z offset
    },

    -- Optional map blips for bunker entrances
    Blips = {
        Enabled = false, -- show bunker blips on the map
        Sprite = 557, -- bunker sprite
        Display = 4, -- standard display
        Scale = 0.9, -- blip size
        Color = 2, -- blip color
        ShortRange = true, -- only visible when close-ish
        Name = "Bunker", -- blip label
    },

    -- Door animation / camera / sound
    Door = {
        SearchRadius = 25.0, -- how far to search for the closed door prop

        EnableCamera = true, -- enable door animation camera
        CameraOffset = vector3(10.0, 2.0, 2.0), -- camera position offset from door
        CameraFov = 50.0, -- camera field of view

        EnableSounds = true, -- play bunker door sounds
        SoundBank = "DLC_GR_Bunker_Door_Sounds", -- audio bank name
        SoundOpen = "Door_Open_Long", -- open sound
        SoundLimit = "Door_Open_Limit", -- limit/clunk sound
        UseStreamedSounds = true, -- uses LoadStream/PlayStreamFrontend like the original script
        SoundLoadTries = 200, -- frames to retry loading the bank/stream
        DebugSounds = false, -- prints why it fails

        TopPartOffset = vector3(-8.68, 0.0, 0.0), -- offset for the door top object spawn
        TopPartExtraRotY = 20.0, -- extra rotation on Y to match GTA door animation setup

        AnimationSteps = 20, -- number of rotation steps
        StepWaitMs = 60, -- wait per step (ms), lower = faster animation
        PlayLimitSoundAtStep = 18, -- step when limit sound plays

        FadeOutMs = 500, -- screen fade out on enter
        FadeInMs = 500, -- screen fade in after teleport
    },

    -- Teleport / locations
    Teleport = {
        InteriorCoords = vector3(885.982, -3245.716, -98.278), -- bunker interior spawn point

        InteriorExitPoint = vector3(896.376, -3245.798, -98.243), -- where players press E to exit
        InteriorExitInteractDistance = 1.0, -- fallback interact distance if ExitMarker.InteractDistance is nil

        UseSameEntranceExit = true, -- exit to the same entrance you used
        DefaultExitWorldCoords = vector3(-3151.440, 1377.317, 17.391), -- fallback exit point
    },

    -- Interior customization (style + sets)
    Interior = {
        Enabled = true, -- apply interior style/sets (true) or leave GTA defaults (false)
        Id = 258561, -- bunker interior id

        Style = "Bunker_Style_B", -- "Bunker_Style_A" / "Bunker_Style_B" / "Bunker_Style_C" / nil

        EnableSets = {
            "standard_bunker_set", -- machines / basic props
            "Gun_schematic_set", -- gun schematics props
            "Office_Upgrade_set", -- office room upgrade props
            "standard_security_set", -- standard security props
        },

        DisableSets = {
            "security_upgrade", -- disable alternate security props
        },
    },

    -- Safety / rules while inside the bunker
    Safety = {
        DisableCombatControlsInBunker = true, -- disables shooting, aiming, weapon wheel
        InvincibleInBunker = false, -- player takes no damage inside bunker
        ForceUnarmedInBunker = false, -- switches player to unarmed inside bunker
        DisableMeleeInBunker = true, -- prevents punching through walls / ragdoll abuse
    },

    -- IPL loading (bunker shells/placements)
    IPLs = {
        "gr_case0_bunkerclosed",
        "gr_case1_bunkerclosed",
        "gr_case2_bunkerclosed",
        "gr_case3_bunkerclosed",
        "gr_case4_bunkerclosed",
        "gr_case5_bunkerclosed",
        "gr_case6_bunkerclosed",
        "gr_case7_bunkerclosed",
        "gr_case8_bunkerclosed",
        "gr_case9_bunkerclosed",
        "gr_case10_bunkerclosed",
        "gr_case11_bunkerclosed",
        "gr_entrance_placement",
    },

    -- Entrance list (world coords)
    Entrances = {
        { x = -3156.372, y = 1376.653, z = 16.123 },
        { x = 850.382,   y = 3026.168, z = 41.270 },
        { x = 2126.785,  y = 3335.040, z = 48.21422 },
        { x = 2493.654,  y = 3140.399, z = 51.28789 },
        { x = 481.0465,  y = 2995.135, z = 43.96672 },
        { x = -388.239,  y = 4333.197, z = 54.636 },
        { x = 1793.181,  y = 4705.138, z = 39.300 },
        { x = 1572.405,  y = 2218.4121, z = 77.609 },
        { x = -748.903,  y = 5945.7529, z = 18.500 },
        { x = 42.668,    y = 2924.000, z = 54.500 },
        { x = -3027.569, y = 3334.229, z = 10.032 },
    },
}
