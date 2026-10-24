local addonName = ...

------------------------------------------------------------
-- Constants
------------------------------------------------------------

local TITLE = "Remix Tracker"
local CHAT_PREFIX = "|cffd8b46aRemix|r: "
local ERROR_PREFIX = "|cffff5555Remix:|r "

local FALLBACK_ICON = 134400
local PORTRAIT_ICON = "Interface\\AddOns\\ZamestoTV_Remix\\Icons\\remix.tga"
local MINIMAP_ICON = "Interface\\Icons\\Achievement_Boss_LichKing" -- Lich King helm: Wrath theme

-- Toy Box style paged grid: icon + name per cell, fixed number per page.
-- Change GRID_COLUMNS / GRID_ROWS to taste (the frame is sized for 3 x 6).
local GRID_COLUMNS = 3
local GRID_ROWS = 6
local ITEMS_PER_PAGE = GRID_COLUMNS * GRID_ROWS
local ICON_SIZE = 40
local CELL_WIDTH = 214
local CELL_HEIGHT = 44
local CELL_GAP_X = 8
local CELL_STEP_Y = 48
local GRID_PAD_X = 10
local GRID_PAD_Y = 8

local LAYOUT = {
    frameWidth = 700,
    frameHeight = 620,
    headerStripHeight = 34,   -- expansion / category row inside the inset
    gridHeight = 340,         -- icon area including the paging controls
    sideWidth = 230,          -- width of the Power / Talents / Currency / Phase column
    sideOffset = 2,           -- gap between the main frame and the side column
    sideGap = 4,              -- gap between the stacked side sub-frames
}

-- Side column (right of the main frame). Weights decide how the main frame's
-- height is shared; the last section is anchored to the main frame's bottom,
-- so the whole stack can never be taller than the main frame.
local SIDE_SECTIONS = {
    { label = "Power", weight = 0.46 },
    { label = "Talents", weight = 0.16 },
    { label = "Currency", weight = 0.16 },
    { label = "Phase", weight = 0.22 },
}

local MODE_ACHIEVEMENTS = "achievements"
local MODE_ITEMS = "items"

-- Virtual "expansion" index used for the Favorites tab.
local FAVORITES_TAB = 0

local FILTER_ALL = "all"
local FILTER_COMPLETED = "completed"
local FILTER_INCOMPLETE = "incomplete"

local SORT_MODES = {
    { key = "status", label = "Completed first", itemLabel = "Collected first" },
    { key = "incomplete", label = "Incomplete first", itemLabel = "Not collected first" },
    { key = "name", label = "Name (A-Z)", itemLabel = "Name (A-Z)" },
    { key = "list", label = "List order", itemLabel = "List order" },
}

local HORDE_ACHIEVEMENTS = { [3357] = true, [12568] = true, [63099] = true, [62925] = true, [62954] = true }
local ALLIANCE_ACHIEVEMENTS = { [3356] = true, [12567] = true, [63103] = true, [62953] = true, [62924] = true }

local BLACK_MARKET_ACHIEVEMENTS = {
    [14183] = true,
    [880] = true,
    [881] = true,
}

local EXPANSIONS = {
    {
        name = "Vanilla",
        achievements = { 2336, 871, 729, 424, 429, 428, 3356, 980, 4627, 3357, 3496 },
    },
    {
        name = "The Burning Crusade",
        achievements = { 1205, 426, 885, 882, 883, 1705, 884, 881, 880 },
    },
    {
        name = "Wrath of the Lich King",
        achievements = { 3316, 4625, 4496, 4623, 1706, 2081, 725, 3142, 4626 },
    },
    {
        name = "Cataclysm",
        achievements = { 5767, 6061, 6181, 6060, 6059, 5839 },
    },
    {
        name = "Mists of Pandaria",
        achievements = { 7852, 8092, 8345, 8698 },
    },
    {
        name = "Warlords of Draenor",
        achievements = { 10334, 9725, 10335, 9597, 9926, 10337, 9915 },
    },
    {
        name = "Legion",
        achievements = { 11744, 11869, 11137, 11913, 10751 },
    },
    {
        name = "Battle for Azeroth",
        achievements = { 14191, 12567, 14183, 12568, 13927, 12850 },
    },
    {
        name = "Shadowlands",
        achievements = { 15653, 15191, 15323, 15313, 15645, 14931 },
    },
    {
        name = "Dragonflight",
        achievements = { 18928, 18929, 18931, 17547, 19450, 18256, 19077, 17426, 19130 },
    },
    {
        name = "The War Within",
        achievements = { 41630, 40967, 61516, 40098, 42192, 42799, 20510, 41531 },
    },
    {
        name = "Midnight",
        subTabs = {
            {
                name = "General",
                achievements = { 62189, 61917, 61585, 63679, 62842, 61706, 62388, 61199, 61200, 61430, 63830, 63716, 62410, 62411, 62412, 62414, 62416, 63611 },
            },
            {
                name = "Delves",
                achievements = { 63333, 63326, 64039, 63715, 64118, 63332, 62889, 62890, 62891, 62892, 62893, 62894, 62895, 62897, 63433, 63863, 63864, 63865, 63846, 63847, 63848, 63849, 63850, 63851, 63852, 63853 },
            },
            {
                name = "Dungeons",
                achievements = { 62445, 62446, 62447, 62448, 62449, 63690, 62436, 62444, 62441, 62440, 62442, 62437, 62438, 62443, 62439, 63623, 63621, 63624, 63626, 63628, 63622, 63627, 63625, 62417, 62418, 62419, 62420, 62421, 62422, 62423, 62424, 62425, 62426, 62427, 62428, 62429, 62430, 62431, 62432, 62433, 62434, 62435 },
            },
            {
                name = "Raids",
                achievements = { 63650, 63651 },
            },
            {
                name = "PvP",
                achievements = { 62955, 62497, 62930, 62911, 62950, 62932, 62931, 62924, 62922, 62925, 62929, 62921, 62928, 63099, 62951, 62952, 62927, 62954, 62923, 62926, 63103 },
            },
            {
                name = "Events",
                achievements = { 63659, 63658, 63680, 63657, 63714 },
            },
        },
    },
}

------------------------------------------------------------
-- Example vendors (items)
------------------------------------------------------------
-- Each vendor lists item IDs. Names/icons/quality are read from the client at
-- runtime, so adding a vendor or item only needs an ID here. Vendor names and
-- locations are examples - replace them with the real Remix vendors.

local VENDORS = {
    {
        name = "Drakemaster Aldwyn",
        location = "Dalaran - Mounts",
        items = {
            43951, -- Reins of the Bronze Drake
            43952, -- Reins of the Azure Drake
            43953, -- Reins of the Blue Drake
            43954, -- Reins of the Twilight Drake
            43955, -- Reins of the Red Drake
            43986, -- Reins of the Black Drake
            44151, -- Reins of the Blue Proto-Drake
            44160, -- Reins of the Red Proto-Drake
            44164, -- Reins of the Black Proto-Drake
            44168, -- Reins of the Time-Lost Proto-Drake
            44175, -- Reins of the Plagued Proto-Drake
            44177, -- Reins of the Violet Proto-Drake
            44178, -- Reins of the Albino Drake
        },
    },
    {
        name = "Alchemist Zerina",
        location = "Dalaran - Consumables",
        items = {
            33447, -- Runic Healing Potion
            33448, -- Runic Mana Potion
            40077, -- Crazy Alchemist's Potion
            40087, -- Powerful Rejuvenation Potion
            40093, -- Indestructible Potion
            40211, -- Potion of Speed
            40212, -- Potion of Wild Magic
            46376, -- Flask of the Frost Wyrm
            46377, -- Flask of Endless Rage
            46378, -- Flask of Pure Mojo
            46379, -- Flask of Stoneblood
            43015, -- Fish Feast
        },
    },
    {
        name = "Thurgrim Ironvein",
        location = "Valiance Keep - Trade Goods",
        items = {
            36909, -- Cobalt Bar
            36910, -- Titanium Bar
            36913, -- Saronite Bar
            41163, -- Titansteel Bar
            33470, -- Frostweave Cloth
            33568, -- Borean Leather
            38425, -- Heavy Borean Leather
            43102, -- Frozen Orb
            35622, -- Eternal Water
            35623, -- Eternal Air
            35624, -- Eternal Earth
            36860, -- Eternal Fire
            35625, -- Eternal Life
            35627, -- Eternal Shadow
            34057, -- Abyss Crystal
        },
    },
    {
        name = "Archivist Valenthe",
        location = "Icecrown - Rare Collectibles",
        items = {
            50818, -- Invincible's Reins
            45693, -- Mimiron's Head
            49636, -- Reins of the Onyxian Drake
            13335, -- Deathcharger's Reins
            44738, -- Kirin Tor Familiar
            49623, -- Shadowmourne
            50274, -- Shadowfrost Shard
            47556, -- Crusader Orb
            45087, -- Runed Orb
            34052, -- Dream Shard
            49426, -- Emblem of Frost
            47241, -- Emblem of Triumph
            45624, -- Emblem of Conquest
            40753, -- Emblem of Valor
            40752, -- Emblem of Heroism
        },
    },
}

------------------------------------------------------------
-- State
------------------------------------------------------------

local db
local initialized = false

-- All frames live in one table (keeps upvalue counts low).
local ui = {}

local achievementButtons = {}
local visibleAchievements = {}
local groupProgress = {}      -- [expansion / vendor index] = { done, total } for the current mode
local favoriteCount = 0
local currentPage = 1

local selectedExpansion = 1
local selectedVendor = 1
local currentMode = MODE_ACHIEVEMENTS
local selectedSubTab = 1
local selectedAchievementID   -- ID of the selected entry (achievement or item)
local selectedInfo

-- Static, faction-independent index built once from EXPANSIONS.
local ALL_ENTRIES = {}       -- unique achievements: { id, group }
local EXPANSION_IDS = {}     -- [expansionIndex] = unique ids across its tabs
local ITEM_ENTRIES = {}      -- unique items: { id, group = vendor name }
local VENDOR_IDS = {}        -- [vendorIndex] = unique item ids
local ITEM_VENDORS = {}      -- [itemID] = { "Vendor (Location)", ... }

-- Forward declarations (assigned further down).
local UpdateCollection, UpdateDetails, RefreshSubTabs, RefreshProgress
local SetExpansion, SetSubTab, SetFilter, ToggleFavorite
local UpdateNavButtons
local SetMode, SetVendor, UpdateModeUI

local function IsItemMode()
    return currentMode == MODE_ITEMS
end

local function IsFavoritesView()
    if IsItemMode() then
        return selectedVendor == FAVORITES_TAB
    end
    return selectedExpansion == FAVORITES_TAB
end

local function Print(message)
    print(CHAT_PREFIX .. message)
end

local function PrintError(message)
    print(ERROR_PREFIX .. message)
end

------------------------------------------------------------
-- Static data index
------------------------------------------------------------

local function BuildStaticIndex()
    local seenGlobal = {}

    for expansionIndex, expansion in ipairs(EXPANSIONS) do
        local seenInExpansion = {}
        local expansionIDs = {}

        -- Removes duplicate IDs inside one tab and feeds the global indexes.
        local function AddList(list, groupName)
            local unique = {}
            local seenInList = {}

            for _, id in ipairs(list) do
                if not seenInList[id] then
                    seenInList[id] = true
                    unique[#unique + 1] = id

                    if not seenInExpansion[id] then
                        seenInExpansion[id] = true
                        expansionIDs[#expansionIDs + 1] = id
                    end

                    if not seenGlobal[id] then
                        seenGlobal[id] = true
                        ALL_ENTRIES[#ALL_ENTRIES + 1] = { id = id, group = groupName }
                    end
                end
            end

            return unique
        end

        if expansion.subTabs then
            for _, sub in ipairs(expansion.subTabs) do
                sub.ids = AddList(sub.achievements, expansion.name .. " - " .. sub.name)
            end
        else
            expansion.ids = AddList(expansion.achievements, expansion.name)
        end

        EXPANSION_IDS[expansionIndex] = expansionIDs
    end

    -- Items: same idea, one id list per vendor.
    local seenItems = {}

    for vendorIndex, vendor in ipairs(VENDORS) do
        local ids = {}
        local seenInVendor = {}
        local label = vendor.name

        if vendor.location and vendor.location ~= "" then
            label = label .. " (" .. vendor.location .. ")"
        end

        for _, id in ipairs(vendor.items) do
            if not seenInVendor[id] then
                seenInVendor[id] = true
                ids[#ids + 1] = id

                if not seenItems[id] then
                    seenItems[id] = true
                    ITEM_ENTRIES[#ITEM_ENTRIES + 1] = { id = id, group = vendor.name }
                end

                local list = ITEM_VENDORS[id]
                if not list then
                    list = {}
                    ITEM_VENDORS[id] = list
                end
                list[#list + 1] = label
            end
        end

        vendor.ids = ids
        VENDOR_IDS[vendorIndex] = ids
    end
end

local function GetCurrentTabIDs()
    if IsItemMode() then
        local vendor = VENDORS[selectedVendor]
        return vendor and vendor.ids or {}
    end

    local expansion = EXPANSIONS[selectedExpansion]
    if not expansion then
        return {}
    end

    if expansion.subTabs then
        local sub = expansion.subTabs[selectedSubTab] or expansion.subTabs[1]
        return sub and sub.ids or {}
    end

    return expansion.ids or {}
end

------------------------------------------------------------
-- SavedVariables
------------------------------------------------------------

local function InitializeDB()
    if type(MidnightAchievementCollectionDB) ~= "table" then
        MidnightAchievementCollectionDB = {}
    end

    db = MidnightAchievementCollectionDB

    db.expansion = tonumber(db.expansion) or 1
    db.subTab = tonumber(db.subTab) or 1
    db.search = nil -- search text is no longer persisted

    -- Toy Box style filters: two independent checkboxes. Migrates the old
    -- single "filter" setting (all / completed / incomplete).
    if type(db.showCompleted) ~= "boolean" then
        db.showCompleted = db.filter ~= FILTER_INCOMPLETE
    end
    if type(db.showIncomplete) ~= "boolean" then
        db.showIncomplete = db.filter ~= FILTER_COMPLETED
    end
    db.filter = nil

    local validSort = false
    for _, mode in ipairs(SORT_MODES) do
        if mode.key == db.sort then
            validSort = true
        end
    end
    if not validSort then
        db.sort = SORT_MODES[1].key
    end

    if type(db.favorites) ~= "table" then
        db.favorites = {}
    end

    if type(db.itemFavorites) ~= "table" then
        db.itemFavorites = {}
    end

    if db.mode ~= MODE_ITEMS then
        db.mode = MODE_ACHIEVEMENTS
    end
    currentMode = db.mode

    db.vendor = tonumber(db.vendor) or 1
    if db.vendor ~= FAVORITES_TAB and (db.vendor < 1 or db.vendor > #VENDORS) then
        db.vendor = 1
    end
    selectedVendor = db.vendor

    if type(db.minimap) ~= "table" then
        db.minimap = {}
    end
    db.minimap.angle = tonumber(db.minimap.angle) or 215
    db.minimap.hide = db.minimap.hide == true

    db.scale = tonumber(db.scale) or 1
    if db.scale < 0.6 or db.scale > 1.5 then
        db.scale = 1
    end

    if db.expansion ~= FAVORITES_TAB
        and (db.expansion < 1 or db.expansion > #EXPANSIONS)
    then
        db.expansion = 1
    end

    selectedExpansion = db.expansion

    local expansion = EXPANSIONS[selectedExpansion]
    if expansion and expansion.subTabs then
        selectedSubTab = math.min(math.max(db.subTab, 1), #expansion.subTabs)
    else
        selectedSubTab = 1
    end
    db.subTab = selectedSubTab
end

------------------------------------------------------------
-- Achievement API & faction check
------------------------------------------------------------

local function ShouldShowForCurrentFaction(id)
    if currentMode == MODE_ITEMS then
        return true -- items are not faction filtered
    end

    local playerFaction = UnitFactionGroup("player")

    if HORDE_ACHIEVEMENTS[id] then
        return playerFaction == "Horde"
    elseif ALLIANCE_ACHIEVEMENTS[id] then
        return playerFaction == "Alliance"
    end

    return true
end

local function FormatEarnedDate(month, day, year)
    if not month or not day or not year or month == 0 or day == 0 then
        return nil
    end

    if type(FormatShortDate) == "function" then
        local ok, text = pcall(FormatShortDate, day, month, year)
        if ok and text then
            return text
        end
    end

    return string.format("%02d/%02d/%02d", day, month, year % 100)
end

local requestedData = {}

local function GetAchievementInfoSafe(id)
    if type(GetAchievementInfo) == "function" then
        local ok, achievementID, name, points, completed,
            month, day, year, description, _,
            icon, rewardText, _, wasEarnedByMe, earnedBy =
            pcall(GetAchievementInfo, id)

        if ok and name then
            return {
                id = achievementID or id,
                name = name,
                points = points or 0,
                completed = completed and true or false,
                description = description or "",
                icon = icon or FALLBACK_ICON,
                rewardText = rewardText or "",
                dateText = completed and FormatEarnedDate(month, day, year) or nil,
                earnedBy = earnedBy,
                earnedByMe = wasEarnedByMe and true or false,
                unavailable = false,
            }
        end
    end

    if C_AchievementInfo
        and type(C_AchievementInfo.GetAchievementInfo) == "function"
    then
        local ok, info = pcall(C_AchievementInfo.GetAchievementInfo, id)

        if ok and type(info) == "table" and info.name then
            return {
                id = info.id or id,
                name = info.name,
                points = info.points or 0,
                completed = (info.completed or info.isCompleted) and true or false,
                description = info.description or "",
                icon = info.icon or FALLBACK_ICON,
                rewardText = info.rewardText or "",
                unavailable = false,
            }
        end
    end

    if not requestedData[id]
        and C_AchievementInfo
        and type(C_AchievementInfo.RequestAchievementData) == "function"
    then
        requestedData[id] = true
        pcall(C_AchievementInfo.RequestAchievementData, id)
    end

    return {
        id = id,
        name = "Achievement #" .. id,
        points = 0,
        completed = false,
        description = "Achievement data is not available yet.",
        icon = FALLBACK_ICON,
        rewardText = "",
        unavailable = true,
    }
end

local function GetAchievementLinkSafe(id)
    if type(GetAchievementLink) == "function" then
        local ok, link = pcall(GetAchievementLink, id)
        if ok then
            return link
        end
    end
    return nil
end

------------------------------------------------------------
-- Item API
------------------------------------------------------------

local requestedItems = {}

local function GetItemQualityColor(quality)
    local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality or 1]
    local r, g, b = 1, 1, 1

    if color then
        r, g, b = color.r or 1, color.g or 1, color.b or 1
    end

    local hex = string.format(
        "|cff%02x%02x%02x",
        math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5),
        math.floor(b * 255 + 0.5)
    )

    return hex, { r, g, b }
end

-- "Collected" for an item: carried/banked, or known through a collection
-- (toy box, mount journal, pet journal, transmog).
local function IsItemCollected(id)
    local count = 0
    if C_Item and C_Item.GetItemCount then
        local ok, result = pcall(C_Item.GetItemCount, id, true)
        if ok and type(result) == "number" then
            count = result
        end
    elseif type(GetItemCount) == "function" then
        count = GetItemCount(id, true) or 0
    end
    if count > 0 then
        return true
    end

    if type(PlayerHasToy) == "function" then
        local ok, has = pcall(PlayerHasToy, id)
        if ok and has then
            return true
        end
    end

    if C_MountJournal and C_MountJournal.GetMountFromItem
        and C_MountJournal.GetMountInfoByID
    then
        local ok, mountID = pcall(C_MountJournal.GetMountFromItem, id)
        if ok and type(mountID) == "number" and mountID > 0 then
            -- isCollected is the 11th return value (12th with the pcall flag).
            local r = { pcall(C_MountJournal.GetMountInfoByID, mountID) }
            if r[1] and r[12] then
                return true
            end
        end
    end

    if C_PetJournal and C_PetJournal.GetPetInfoByItemID
        and C_PetJournal.GetNumCollectedInfo
    then
        -- speciesID is the 13th return value (14th with the pcall flag).
        local r = { pcall(C_PetJournal.GetPetInfoByItemID, id) }
        if r[1] and type(r[14]) == "number" then
            local ok, owned = pcall(C_PetJournal.GetNumCollectedInfo, r[14])
            if ok and type(owned) == "number" and owned > 0 then
                return true
            end
        end
    end

    if C_TransmogCollection and C_TransmogCollection.PlayerHasTransmog then
        local ok, has = pcall(C_TransmogCollection.PlayerHasTransmog, id)
        if ok and has then
            return true
        end
    end

    return false
end

-- Returns an info table shaped like GetAchievementInfoSafe's, so the grid,
-- filters, favorites and detail panel work for both modes.
local function GetItemInfoSafe(id)
    local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    local name, link, quality, itemLevel, minLevel, itemType, itemSubType
    local equipLoc, icon

    if type(getInfo) == "function" then
        local ok, n, l, q, il, ml, t, st, _, el, ic = pcall(getInfo, id)
        if ok and type(n) == "string" then
            name, link, quality, itemLevel, minLevel = n, l, q, il, ml
            itemType, itemSubType, equipLoc, icon = t, st, el, ic
        end
    end

    local vendors = ITEM_VENDORS[id]
    local soldBy = vendors and ("Sold by: " .. table.concat(vendors, ", ")) or ""
    local hex, rgb = GetItemQualityColor(quality)

    if name then
        local parts = {}

        if itemType and itemType ~= "" then
            if itemSubType and itemSubType ~= "" and itemSubType ~= itemType then
                parts[#parts + 1] = itemType .. " - " .. itemSubType
            else
                parts[#parts + 1] = itemType
            end
        end

        local slot = equipLoc and equipLoc ~= "" and _G[equipLoc]
        if type(slot) == "string" then
            parts[#parts + 1] = slot
        end

        if minLevel and minLevel > 1 then
            parts[#parts + 1] = "Requires level " .. minLevel
        end

        return {
            id = id,
            name = name,
            coloredName = hex .. name .. "|r",
            qualityColor = rgb,
            points = 0,
            completed = IsItemCollected(id),
            description = #parts > 0 and table.concat(parts, "  |  ") or "Item",
            icon = icon or FALLBACK_ICON,
            rewardText = soldBy,
            link = link,
            itemLevel = itemLevel,
            isItem = true,
            unavailable = false,
        }
    end

    -- Not cached yet: ask the server once; GET_ITEM_INFO_RECEIVED refreshes us.
    if not requestedItems[id] and C_Item and C_Item.RequestLoadItemDataByID then
        requestedItems[id] = true
        pcall(C_Item.RequestLoadItemDataByID, id)
    end

    local fallbackIcon
    if C_Item and C_Item.GetItemIconByID then
        local ok, result = pcall(C_Item.GetItemIconByID, id)
        if ok then
            fallbackIcon = result
        end
    end

    return {
        id = id,
        name = "Item #" .. id,
        coloredName = "Item #" .. id,
        qualityColor = { 1, 1, 1 },
        points = 0,
        completed = IsItemCollected(id),
        description = "Item data is loading...",
        icon = fallbackIcon or FALLBACK_ICON,
        rewardText = soldBy,
        link = nil,
        isItem = true,
        unavailable = true,
    }
end

local function GetEntryInfo(id)
    if IsItemMode() then
        return GetItemInfoSafe(id)
    end
    return GetAchievementInfoSafe(id)
end

local function GetEntryLink(info)
    if not info then
        return nil
    end
    if info.isItem then
        return info.link
    end
    return GetAchievementLinkSafe(info.id)
end

-- "View in 3D" opens Blizzard's Dressing Room: mounts and companions get
-- their own model preview, wearable gear is tried on the player.
-- Returns "mount" / "pet" / "gear" (+ data) or nil when there is nothing to show.
local function GetItemPreviewKind(id)
    if type(DressUpMount) == "function"
        and C_MountJournal and C_MountJournal.GetMountFromItem
    then
        local ok, mountID = pcall(C_MountJournal.GetMountFromItem, id)
        if ok and type(mountID) == "number" and mountID > 0 then
            return "mount", mountID
        end
    end

    if type(DressUpBattlePet) == "function"
        and C_PetJournal and C_PetJournal.GetPetInfoByItemID
    then
        local r = { pcall(C_PetJournal.GetPetInfoByItemID, id) }
        if r[1] and r[2] then
            return "pet", r
        end
    end

    local dressable = false
    if C_Item and C_Item.IsDressableItemByID then
        local ok, result = pcall(C_Item.IsDressableItemByID, id)
        dressable = (ok and result) and true or false
    elseif type(IsDressableItem) == "function" then
        local ok, result = pcall(IsDressableItem, "item:" .. id)
        dressable = (ok and result) and true or false
    end

    if dressable then
        return "gear"
    end

    return nil
end

local function ViewItemIn3D(info)
    if not info or not info.isItem then
        return
    end

    local kind, data = GetItemPreviewKind(info.id)
    local handled = false

    if kind == "mount" then
        local ok, result = pcall(DressUpMount, data)
        handled = ok and result ~= false
    elseif kind == "pet" then
        -- GetPetInfoByItemID (with pcall flag): creatureID = 5, displayID = 13, speciesID = 14
        local ok, result = pcall(DressUpBattlePet, data[5], data[13], data[14])
        handled = ok and result ~= false
    elseif kind == "gear" then
        local dress = DressUpLink or DressUpItemLink
        if type(dress) == "function" then
            local ok, result = pcall(dress, info.link or ("item:" .. info.id))
            handled = ok and result ~= false
        end
    end

    if not handled then
        PrintError("This item cannot be previewed in 3D (only mounts, companions and wearable gear can).")
        return
    end

    -- Keep the Dressing Room above this window if they overlap.
    pcall(function()
        if DressUpFrame and DressUpFrame:IsShown() then
            DressUpFrame:SetFrameStrata("DIALOG")
            DressUpFrame:Raise()
        end
    end)
end

------------------------------------------------------------
-- Favorites & tracking
------------------------------------------------------------

local function CurrentFavorites()
    if not db then
        return {}
    end
    return IsItemMode() and db.itemFavorites or db.favorites
end

local function IsFavorite(id)
    return db and CurrentFavorites()[id] == true
end

local function CanTrackAchievements()
    if C_ContentTracking
        and C_ContentTracking.StartTracking
        and Enum and Enum.ContentTrackingType
    then
        return true
    end
    return type(AddTrackedAchievement) == "function"
end

local function IsAchievementTracked(id)
    if C_ContentTracking
        and C_ContentTracking.IsTracking
        and Enum and Enum.ContentTrackingType
    then
        local ok, tracked = pcall(
            C_ContentTracking.IsTracking,
            Enum.ContentTrackingType.Achievement, id
        )
        if ok then
            return tracked and true or false
        end
    end

    if type(IsTrackedAchievement) == "function" then
        local ok, tracked = pcall(IsTrackedAchievement, id)
        if ok then
            return tracked and true or false
        end
    end

    return false
end

local function ToggleTracking(id)
    if not id then
        return
    end

    local tracking = IsAchievementTracked(id)

    if C_ContentTracking
        and C_ContentTracking.StartTracking
        and C_ContentTracking.StopTracking
        and Enum and Enum.ContentTrackingType
    then
        local ok, result
        if tracking then
            local stopType = Enum.ContentTrackingStopType
                and Enum.ContentTrackingStopType.Manual or 0
            ok, result = pcall(
                C_ContentTracking.StopTracking,
                Enum.ContentTrackingType.Achievement, id, stopType
            )
        else
            ok, result = pcall(
                C_ContentTracking.StartTracking,
                Enum.ContentTrackingType.Achievement, id
            )
        end

        if not ok then
            PrintError("Could not change tracking: " .. tostring(result))
        elseif result ~= nil and not tracking then
            -- StartTracking returns an error code when it fails.
            PrintError("Could not track this achievement (the tracking limit may have been reached).")
        end
    elseif type(AddTrackedAchievement) == "function" then
        local func = tracking and RemoveTrackedAchievement or AddTrackedAchievement
        if type(func) == "function" then
            local ok, err = pcall(func, id)
            if not ok then
                PrintError("Could not change tracking: " .. tostring(err))
            end
        end
    end

    if selectedInfo then
        UpdateDetails(selectedInfo)
    end
end

local function InsertChatLink(link)
    if not link then
        return false
    end

    local insert = (ChatFrameUtil and ChatFrameUtil.InsertLink) or ChatEdit_InsertLink
    if type(insert) == "function" then
        local ok, inserted = pcall(insert, link)
        return (ok and inserted) and true or false
    end

    return false
end
-- Visual helpers
------------------------------------------------------------

local function SetTextureColor(texture, r, g, b, a)
    if texture then
        texture:SetColorTexture(r, g, b, a or 1)
    end
end

local function SetStarTexture(texture)
    local atlas = "PetJournal-FavoritesIcon"

    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
        texture:SetAtlas(atlas)
    else
        texture:SetTexture("Interface\\COMMON\\FavoritesIcon")
    end
end

local function CreatePanel(parent, width, height)
    local panel = CreateFrame("Frame", nil, parent)
    panel:SetSize(width, height)

    panel.Background = panel:CreateTexture(nil, "BACKGROUND")
    panel.Background:SetAllPoints()
    SetTextureColor(panel.Background, 0.045, 0.045, 0.055, 0.98)

    panel.TopLine = panel:CreateTexture(nil, "BORDER")
    panel.TopLine:SetPoint("TOPLEFT", 1, -1)
    panel.TopLine:SetPoint("TOPRIGHT", -1, -1)
    panel.TopLine:SetHeight(1)
    SetTextureColor(panel.TopLine, 0.42, 0.31, 0.17, 1)

    return panel
end

local function CreateLabel(parent, text, font, point, relativeTo,
    relativePoint, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK", font)
    label:SetPoint(point, relativeTo, relativePoint, x or 0, y or 0)
    label:SetText(text or "")
    return label
end

local function CreateTextButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)

    button.Background = button:CreateTexture(nil, "BACKGROUND")
    button.Background:SetAllPoints()
    SetTextureColor(button.Background, 0.10, 0.095, 0.08, 1)

    button.Highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.Highlight:SetAllPoints()
    SetTextureColor(button.Highlight, 0.45, 0.35, 0.18, 0.22)

    button.Label = button:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    button.Label:SetPoint("CENTER")
    button.Label:SetText(text)
    button.Label:SetTextColor(0.86, 0.81, 0.70)

    return button
end

-------------------------------------------------------------- Tooltip
------------------------------------------------------------

local function ShowItemTooltip(button)
    local info = button.info

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")

    local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, info.link or ("item:" .. info.id))
    if not ok then
        GameTooltip:SetText(info.name, 1, 0.82, 0)
    end

    GameTooltip:AddLine(" ")

    if info.rewardText and info.rewardText ~= "" then
        GameTooltip:AddLine(info.rewardText, 0.6, 0.6, 0.6, true)
    end

    if info.completed then
        GameTooltip:AddLine("Collected", 0.25, 1, 0.25)
    end

    if IsFavorite(info.id) then
        GameTooltip:AddLine("Favorite", 1, 0.82, 0)
    end

    GameTooltip:AddLine("Right-click: options  |  Shift-click: link", 0.5, 0.8, 1)
    GameTooltip:AddLine("Double-click / Ctrl-click: view in 3D", 0.5, 0.8, 1)

    GameTooltip:Show()
end

local function ShowAchievementTooltip(button)
    local info = button.info
    if not info then
        return
    end

    if info.isItem then
        ShowItemTooltip(button)
        return
    end

    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")

    local link = GetAchievementLinkSafe(info.id)

    if link and GameTooltip.SetHyperlink then
        GameTooltip:SetHyperlink(link)
    else
        GameTooltip:SetText(info.name, 1, 0.82, 0)

        if info.description ~= "" then
            GameTooltip:AddLine(info.description, 1, 1, 1, true)
        end

        GameTooltip:AddLine("ID: " .. info.id, 0.65, 0.65, 0.65)

        if info.completed then
            GameTooltip:AddLine("Completed", 0.25, 1, 0.25)
        else
            GameTooltip:AddLine("Incomplete", 0.75, 0.75, 0.75)
        end

        if info.points > 0 then
            GameTooltip:AddLine(info.points .. " points", 1, 0.82, 0)
        end
    end

    GameTooltip:AddLine(" ")

    if info.group then
        GameTooltip:AddLine(info.group, 0.6, 0.6, 0.6)
    end

    if IsFavorite(info.id) then
        GameTooltip:AddLine("Favorite", 1, 0.82, 0)
    end

    GameTooltip:AddLine("Right-click: options  |  Shift-click: link", 0.5, 0.8, 1)
    GameTooltip:AddLine("Double-click: open in achievement window", 0.5, 0.8, 1)

    GameTooltip:Show()
end

-------------------------------------------------------------- Opening the Blizzard achievement window / WowHead popup
------------------------------------------------------------

local function OpenAchievement(id)
    if InCombatLockdown and InCombatLockdown() then
        PrintError("Cannot open the achievement window while in combat.")
        return
    end

    if not AchievementFrame
        and type(AchievementFrame_LoadUI) == "function"
    then
        AchievementFrame_LoadUI()
    end

    if not AchievementFrame then
        PrintError("The achievement window is unavailable.")
        return
    end

    if type(OpenAchievementFrameToAchievement) == "function" then
        OpenAchievementFrameToAchievement(id)
        return
    end

    if type(ShowUIPanel) == "function" then
        ShowUIPanel(AchievementFrame)
    else
        AchievementFrame:Show()
    end

    if type(AchievementFrame_SelectAchievement) == "function" then
        AchievementFrame_SelectAchievement(id)
    end
end

local function GetPopupEditBox(dialog)
    if dialog.GetEditBox then
        local editBox = dialog:GetEditBox()
        if editBox then
            return editBox
        end
    end

    if dialog.EditBox then
        return dialog.EditBox
    end

    if dialog.editBox then
        return dialog.editBox
    end

    local name = dialog.GetName and dialog:GetName()
    return name and _G[name .. "EditBox"] or nil
end

local function CloseEditBoxDialog(editBox)
    local parent = editBox:GetParent()
    if parent then
        parent:Hide()
    end
end

StaticPopupDialogs["FOST_WOWHEAD_LINK"] = {
    text = "WowHead link for %s #%s (Ctrl+C to copy):",
    button1 = CLOSE,
    hasEditBox = true,
    editBoxWidth = 300,
    OnShow = function(dialog, url)
        local editBox = GetPopupEditBox(dialog)
        if editBox and url then
            editBox:SetText(url)
            editBox:HighlightText()
            editBox:SetFocus()
        end
    end,
    EditBoxOnEnterPressed = CloseEditBoxDialog,
    EditBoxOnEscapePressed = CloseEditBoxDialog,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = STATICPOPUP_NUMDIALOGS or 3,
}

StaticPopupDialogs["FOST_CLEAR_FAVORITES"] = {
    text = "Remove all favorite %s from Feats of Strength Tracker?",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        if db then
            wipe(CurrentFavorites())
            RefreshProgress()
            UpdateCollection()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = STATICPOPUP_NUMDIALOGS or 3,
}

local function OpenWowheadPopup(id)
    if not id then
        return
    end

    local kind, url
    if IsItemMode() then
        kind = "item"
        url = "https://www.wowhead.com/item=" .. id
    else
        kind = "achievement"
        url = "https://www.wowhead.com/achievement=" .. id
    end

    StaticPopup_Show("FOST_WOWHEAD_LINK", kind, tostring(id), url)
end

------------------------------------------------------------
-- Achievement details
------------------------------------------------------------

UpdateDetails = function(info)
    local detail = ui.detail
    if not detail then
        return
    end

    local itemMode = IsItemMode()

    selectedInfo = info
    selectedAchievementID = info and info.id or nil

    detail.Icon:SetTexture(info and info.icon or FALLBACK_ICON)
    detail.Name:SetText(
        info and (info.coloredName or info.name)
        or (itemMode and "Select an item" or "Select an achievement")
    )

    if info then
        local parts = {}
        if info.points > 0 then
            parts[#parts + 1] = info.points .. " points"
        end
        if info.isItem and info.itemLevel and info.itemLevel > 1 then
            parts[#parts + 1] = "Item Level " .. info.itemLevel
        end
        parts[#parts + 1] = "ID: " .. info.id
        if info.group then
            parts[#parts + 1] = info.group
        end
        detail.Meta:SetText(table.concat(parts, "  |  "))
    else
        detail.Meta:SetText("")
    end

    detail.Description:SetText(
        info and info.description
        or (itemMode and "Click an item icon to view its details."
            or "Click an achievement icon to view its description.")
    )

    if info and info.completed then
        detail.Status:SetText(itemMode and "COLLECTED" or "COMPLETED")
        detail.Status:SetTextColor(0.25, 1, 0.25)
    elseif info and info.unavailable then
        detail.Status:SetText(itemMode and "LOADING ITEM DATA" or "DATA UNAVAILABLE")
        detail.Status:SetTextColor(1, 0.65, 0.25)
    elseif info then
        detail.Status:SetText(itemMode and "NOT COLLECTED" or "INCOMPLETE")
        detail.Status:SetTextColor(0.8, 0.8, 0.8)
    else
        detail.Status:SetText("")
    end

    local earned = {}
    if info and info.completed then
        if info.dateText then
            earned[#earned + 1] = "Earned " .. info.dateText
        end
        if info.earnedBy and info.earnedBy ~= "" and not info.earnedByMe then
            earned[#earned + 1] = "by " .. info.earnedBy
        end
    end
    detail.Earned:SetText(table.concat(earned, " "))

    if info and info.rewardText ~= "" then
        detail.Reward:SetText(info.rewardText)
        detail.Reward:Show()
    else
        detail.Reward:SetText("")
        detail.Reward:Hide()
    end

    detail.BlackMarketNotice:SetShown(
        (info ~= nil and not info.isItem and BLACK_MARKET_ACHIEVEMENTS[info.id]) and true or false
    )

    detail.OpenButton:SetShown((info ~= nil and not info.isItem) and true or false)
    detail.View3DButton:SetShown((info ~= nil and info.isItem) and true or false)
    detail.WowheadButton:SetShown(info ~= nil)
    detail.FavoriteButton:SetShown(info ~= nil)

    if info and info.isItem then
        local canPreview = GetItemPreviewKind(info.id) ~= nil
        detail.View3DButton:SetEnabled(canPreview)
        if canPreview then
            detail.View3DButton.Label:SetTextColor(0.86, 0.81, 0.70)
        else
            detail.View3DButton.Label:SetTextColor(0.45, 0.45, 0.45)
        end
    end

    if info then
        detail.FavoriteButton.Label:SetText(
            IsFavorite(info.id) and "Remove Favorite" or "Add Favorite"
        )
    end

    local canTrack = info ~= nil
        and not info.isItem
        and not info.completed
        and not info.unavailable
        and CanTrackAchievements()

    detail.TrackButton:SetShown(canTrack and true or false)
    if canTrack then
        detail.TrackButton.Label:SetText(
            IsAchievementTracked(info.id) and "Stop Tracking" or "Track"
        )
    end
end

local function RefreshSelectionHighlight()
    for _, button in ipairs(achievementButtons) do
        local selected = (button.info ~= nil
            and button.info.id == selectedAchievementID
            and button:IsShown()) and true or false

        button.Selected:SetShown(selected)
        button.SelectedBG:SetShown(selected)
    end
end

ToggleFavorite = function(id)
    if not id or not db then
        return
    end

    local favorites = CurrentFavorites()
    if favorites[id] then
        favorites[id] = nil
    else
        favorites[id] = true
    end

    RefreshProgress()
    UpdateCollection()
end

------------------------------------------------------------
-- Navigation: paging, sub tabs, filters, sorting, expansions
------------------------------------------------------------

local function ResetPage()
    currentPage = 1
end

local function ClearSearch()
    if ui.search and (ui.search:GetText() or "") ~= "" then
        ui.search:SetText("")
    end
end

local function SetPage(page)
    currentPage = page
    UpdateCollection()
end

local function ProgressSuffix(done, total)
    if not total or total == 0 then
        return ""
    end

    local color = (done == total) and "|cff40ff40" or "|cff9d9d9d"
    return string.format("  %s%d/%d|r", color, done, total)
end

-- Safe wrappers: DropdownButton methods differ slightly between builds.
local function RegenerateMenu(dropdown)
    if dropdown and dropdown.GenerateMenu then
        dropdown:GenerateMenu()
    end
end

local function OverrideDropdownText(dropdown, text)
    if dropdown and dropdown.OverrideText then
        dropdown:OverrideText(text)
    end
end

RefreshSubTabs = function()
    local dropdown = ui.categoryDropdown
    if not dropdown then
        return
    end

    local expansion = EXPANSIONS[selectedExpansion]
    local subTabs = expansion and expansion.subTabs

    if IsItemMode() or not subTabs then
        dropdown:Hide()
        return
    end

    dropdown:Show()
    RegenerateMenu(dropdown)

    local sub = subTabs[selectedSubTab] or subTabs[1]
    OverrideDropdownText(dropdown, sub and sub.name or "Category")
end

SetSubTab = function(index)
    selectedSubTab = index
    db.subTab = index

    ClearSearch()
    ResetPage()
    RefreshSubTabs()
    UpdateCollection()
end

-- Used by the slash commands: all | completed | incomplete.
SetFilter = function(filter)
    db.showCompleted = filter ~= FILTER_INCOMPLETE
    db.showIncomplete = filter ~= FILTER_COMPLETED

    ResetPage()
    UpdateCollection()
end

UpdateNavButtons = function()
    local modeDropdown = ui.modeDropdown
    if modeDropdown then
        RegenerateMenu(modeDropdown)
        OverrideDropdownText(modeDropdown, IsItemMode() and "Vendors" or "Achievements")
    end

    local dropdown, text

    if IsItemMode() then
        dropdown = ui.vendorDropdown
        if selectedVendor == FAVORITES_TAB then
            text = "Favorites"
        else
            local vendor = VENDORS[selectedVendor]
            text = vendor and vendor.name or "Vendor"
        end
    else
        dropdown = ui.expansionDropdown
        if selectedExpansion == FAVORITES_TAB then
            text = "Favorites"
        else
            local expansion = EXPANSIONS[selectedExpansion]
            text = expansion and expansion.name or "Expansion"
        end
    end

    if dropdown then
        RegenerateMenu(dropdown)
        OverrideDropdownText(dropdown, text)
    end
end

SetExpansion = function(index)
    if index ~= FAVORITES_TAB and not EXPANSIONS[index] then
        return
    end

    selectedExpansion = index
    db.expansion = index
    selectedSubTab = 1
    db.subTab = 1
    selectedAchievementID = nil

    ClearSearch()
    ResetPage()
    UpdateNavButtons()
    RefreshSubTabs()
    UpdateCollection()
end

SetVendor = function(index)
    if index ~= FAVORITES_TAB and not VENDORS[index] then
        return
    end

    selectedVendor = index
    db.vendor = index
    selectedAchievementID = nil

    ClearSearch()
    ResetPage()
    UpdateNavButtons()
    RefreshSubTabs()
    UpdateCollection()
end

-- Shows the controls that belong to the current mode (achievements / items).
UpdateModeUI = function()
    local itemMode = IsItemMode()

    if ui.expansionDropdown then
        ui.expansionDropdown:SetShown(not itemMode)
    end
    if ui.vendorDropdown then
        ui.vendorDropdown:SetShown(itemMode)
    end

    if ui.search and ui.search.Instructions then
        ui.search.Instructions:SetText(
            itemMode and "Search all items..." or "Search all achievements..."
        )
    end

    RegenerateMenu(ui.filterDropdown)
    UpdateNavButtons()
    RefreshSubTabs()
end

SetMode = function(mode)
    if (mode ~= MODE_ACHIEVEMENTS and mode ~= MODE_ITEMS) or mode == currentMode then
        return
    end

    ClearSearch()

    currentMode = mode
    db.mode = mode
    selectedAchievementID = nil
    selectedInfo = nil

    ResetPage()
    UpdateModeUI()
    RefreshProgress()
    UpdateCollection()
end

------------------------------------------------------------
-- Dropdown menus (same widgets the Collections journal uses)
------------------------------------------------------------

local function CreateDropdown(parent, template)
    local ok, dropdown = pcall(CreateFrame, "DropdownButton", nil, parent, template)
    if not ok or not dropdown then
        ok, dropdown = pcall(CreateFrame, "Button", nil, parent, template)
    end

    if not ok or not dropdown or not dropdown.SetupMenu then
        PrintError("Dropdown template '" .. template .. "' is unavailable on this client.")
        return nil
    end

    return dropdown
end

local function SetupExpansionMenu(dropdown)
    dropdown:SetupMenu(function(_, root)
        root:CreateRadio(
            "Favorites  |cffffd100" .. favoriteCount .. "|r",
            function() return selectedExpansion == FAVORITES_TAB end,
            function() SetExpansion(FAVORITES_TAB) end
        )

        for index, expansion in ipairs(EXPANSIONS) do
            local progress = groupProgress[index]
            local suffix = progress and ProgressSuffix(progress[1], progress[2]) or ""

            root:CreateRadio(
                expansion.name .. suffix,
                function() return selectedExpansion == index end,
                function() SetExpansion(index) end
            )
        end
    end)
end

local function SetupVendorMenu(dropdown)
    dropdown:SetupMenu(function(_, root)
        root:CreateRadio(
            "Favorites  |cffffd100" .. favoriteCount .. "|r",
            function() return selectedVendor == FAVORITES_TAB end,
            function() SetVendor(FAVORITES_TAB) end
        )

        for index, vendor in ipairs(VENDORS) do
            local progress = groupProgress[index]
            local suffix = progress and ProgressSuffix(progress[1], progress[2]) or ""

            root:CreateRadio(
                vendor.name .. suffix,
                function() return selectedVendor == index end,
                function() SetVendor(index) end
            )
        end
    end)
end

local function SetupModeMenu(dropdown)
    dropdown:SetupMenu(function(_, root)
        root:CreateRadio(
            "Achievements",
            function() return currentMode == MODE_ACHIEVEMENTS end,
            function() SetMode(MODE_ACHIEVEMENTS) end
        )

        root:CreateRadio(
            "Vendors",
            function() return currentMode == MODE_ITEMS end,
            function() SetMode(MODE_ITEMS) end
        )
    end)
end

local function SetupCategoryMenu(dropdown)
    dropdown:SetupMenu(function(_, root)
        local expansion = EXPANSIONS[selectedExpansion]
        if not expansion or not expansion.subTabs then
            return
        end

        for index, sub in ipairs(expansion.subTabs) do
            root:CreateRadio(
                sub.name,
                function() return selectedSubTab == index end,
                function() SetSubTab(index) end
            )
        end
    end)
end

local function SetupFilterMenu(dropdown)
    local function Changed()
        ResetPage()
        UpdateCollection()
    end

    dropdown:SetupMenu(function(_, root)
        root:CreateCheckbox(
            IsItemMode() and "Collected" or "Completed",
            function() return db.showCompleted end,
            function()
                db.showCompleted = not db.showCompleted
                Changed()
            end
        )

        root:CreateCheckbox(
            IsItemMode() and "Not Collected" or "Not Completed",
            function() return db.showIncomplete end,
            function()
                db.showIncomplete = not db.showIncomplete
                Changed()
            end
        )

        local sortMenu = root:CreateButton("Sort by")
        for _, mode in ipairs(SORT_MODES) do
            sortMenu:CreateRadio(
                (IsItemMode() and mode.itemLabel) or mode.label,
                function() return db.sort == mode.key end,
                function()
                    db.sort = mode.key
                    Changed()
                end
            )
        end
    end)
end

------------------------------------------------------------
-- Right-click context menu (like the Toy Box)
------------------------------------------------------------

local function ShowAchievementMenu(button)
    local info = button.info
    if not info then
        return
    end

    GameTooltip:Hide()

    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        ToggleFavorite(info.id)
        return
    end

    MenuUtil.CreateContextMenu(button, function(_, root)
        root:CreateTitle(info.name)

        root:CreateButton(
            IsFavorite(info.id) and "Remove from Favorites" or "Add to Favorites",
            function() ToggleFavorite(info.id) end
        )

        if not info.isItem and not info.completed and not info.unavailable
            and CanTrackAchievements()
        then
            root:CreateButton(
                IsAchievementTracked(info.id) and "Stop Tracking" or "Track",
                function() ToggleTracking(info.id) end
            )
        end

        root:CreateDivider()

        if info.isItem then
            root:CreateButton("View in 3D", function()
                ViewItemIn3D(info)
            end)
        else
            root:CreateButton("Open in Achievement Window", function()
                OpenAchievement(info.id)
            end)
        end

        root:CreateButton("Copy WowHead Link", function()
            OpenWowheadPopup(info.id)
        end)

        root:CreateButton("Link in Chat", function()
            if not InsertChatLink(GetEntryLink(info)) then
                PrintError("Open a chat edit box first to insert the link.")
            end
        end)
    end)
end

------------------------------------------------------------
-- Achievement cells (icon with the name beside it)
------------------------------------------------------------

local function CreateAchievementButton(index)
    local button = CreateFrame("Button", nil, ui.iconsFrame)
    button:SetSize(CELL_WIDTH, CELL_HEIGHT)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    button.SelectedBG = button:CreateTexture(nil, "BACKGROUND")
    button.SelectedBG:SetAllPoints()
    SetTextureColor(button.SelectedBG, 1, 0.82, 0.30, 0.12)
    button.SelectedBG:Hide()

    button.IconBorder = button:CreateTexture(nil, "BORDER")
    button.IconBorder:SetSize(ICON_SIZE + 2, ICON_SIZE + 2)
    button.IconBorder:SetPoint("LEFT", 1, 0)
    SetTextureColor(button.IconBorder, 0.40, 0.31, 0.16, 1)

    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetSize(ICON_SIZE, ICON_SIZE)
    button.Icon:SetPoint("CENTER", button.IconBorder, "CENTER")
    button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.Icon:SetTexture(FALLBACK_ICON)

    button.IconHighlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.IconHighlight:SetAllPoints(button.Icon)
    button.IconHighlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    button.IconHighlight:SetBlendMode("ADD")

    button.Selected = button:CreateTexture(nil, "OVERLAY", nil, 2)
    button.Selected:SetPoint("TOPLEFT", button.Icon, "TOPLEFT", -4, 4)
    button.Selected:SetPoint("BOTTOMRIGHT", button.Icon, "BOTTOMRIGHT", 4, -4)
    button.Selected:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    button.Selected:SetBlendMode("ADD")
    button.Selected:Hide()

    button.CompletedMark = button:CreateTexture(nil, "OVERLAY")
    button.CompletedMark:SetSize(16, 16)
    button.CompletedMark:SetPoint("BOTTOMRIGHT", button.Icon, "BOTTOMRIGHT", 3, -3)
    button.CompletedMark:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
    button.CompletedMark:Hide()

    button.Favorite = button:CreateTexture(nil, "OVERLAY", nil, 3)
    button.Favorite:SetSize(16, 16)
    button.Favorite:SetPoint("TOPLEFT", button.Icon, "TOPLEFT", -4, 4)
    SetStarTexture(button.Favorite)
    button.Favorite:Hide()

    button.Name = button:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    button.Name:SetPoint("LEFT", button.Icon, "RIGHT", 8, 0)
    button.Name:SetSize(CELL_WIDTH - ICON_SIZE - 16, CELL_HEIGHT - 6)
    button.Name:SetJustifyH("LEFT")
    button.Name:SetJustifyV("MIDDLE")
    button.Name:SetWordWrap(true)
    if button.Name.SetMaxLines then
        button.Name:SetMaxLines(2)
    end

    button:SetScript("OnEnter", ShowAchievementTooltip)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:SetScript("OnClick", function(self, mouseButton)
        local info = self.info
        if not info then
            return
        end

        if mouseButton == "RightButton" then
            UpdateDetails(info)
            RefreshSelectionHighlight()
            ShowAchievementMenu(self)
            return
        end

        if IsModifiedClick and IsModifiedClick("CHATLINK")
            and InsertChatLink(GetEntryLink(info))
        then
            return
        end

        if info.isItem and IsModifiedClick and IsModifiedClick("DRESSUP") then
            UpdateDetails(info)
            RefreshSelectionHighlight()
            ViewItemIn3D(info)
            return
        end

        UpdateDetails(info)
        RefreshSelectionHighlight()
    end)

    button:SetScript("OnDoubleClick", function(self, mouseButton)
        if mouseButton == "LeftButton" and self.info then
            if self.info.isItem then
                ViewItemIn3D(self.info)
            else
                OpenAchievement(self.info.id)
            end
        end
    end)

    local column = (index - 1) % GRID_COLUMNS
    local row = math.floor((index - 1) / GRID_COLUMNS)
    button:SetPoint(
        "TOPLEFT", ui.iconsFrame, "TOPLEFT",
        GRID_PAD_X + column * (CELL_WIDTH + CELL_GAP_X),
        -GRID_PAD_Y - row * CELL_STEP_Y
    )

    achievementButtons[index] = button
    return button
end

------------------------------------------------------------
-- Collecting, filtering and sorting
------------------------------------------------------------

local function MatchesQuery(info, query)
    if query == "" then
        return true
    end

    if info.name:lower():find(query, 1, true)
        or tostring(info.id):find(query, 1, true)
    then
        return true
    end

    if info.unavailable then
        return false
    end

    return (info.description:lower():find(query, 1, true)
        or info.rewardText:lower():find(query, 1, true)) and true or false
end

local function MatchesStatusFilter(info)
    if info.completed then
        return db.showCompleted
    end
    return db.showIncomplete
end

local SORTERS = {
    status = function(a, b)
        if a.completed ~= b.completed then
            return a.completed
        end
        local an, bn = a.name:lower(), b.name:lower()
        if an ~= bn then
            return an < bn
        end
        return a.order < b.order
    end,

    incomplete = function(a, b)
        if a.completed ~= b.completed then
            return not a.completed
        end
        local an, bn = a.name:lower(), b.name:lower()
        if an ~= bn then
            return an < bn
        end
        return a.order < b.order
    end,

    name = function(a, b)
        local an, bn = a.name:lower(), b.name:lower()
        if an ~= bn then
            return an < bn
        end
        return a.order < b.order
    end,

    list = function(a, b)
        return a.order < b.order
    end,
}

-- Returns the achievements that belong to the current view, before the
-- search text and the status filter are applied, plus the view's scope:
--   "favorites"  the Favorites tab
--   "search"     a search across every tab
--   "tab"        the selected expansion / sub tab
local function CollectSource(query)
    local infos = {}
    local scope

    local function Add(id, group, order)
        if ShouldShowForCurrentFaction(id) then
            local info = GetEntryInfo(id)
            info.order = order
            info.group = group
            infos[#infos + 1] = info
        end
    end

    local entries = IsItemMode() and ITEM_ENTRIES or ALL_ENTRIES

    if IsFavoritesView() then
        local favorites = CurrentFavorites()
        scope = "favorites"
        for index, entry in ipairs(entries) do
            if favorites[entry.id] then
                Add(entry.id, entry.group, index)
            end
        end
    elseif query ~= "" then
        scope = "search"
        for index, entry in ipairs(entries) do
            Add(entry.id, entry.group, index)
        end
    else
        scope = "tab"
        for index, id in ipairs(GetCurrentTabIDs()) do
            Add(id, nil, index)
        end
    end

    return infos, scope
end
------------------------------------------------------------
-- Refresh the grid
------------------------------------------------------------

local STATUS_FORMATS = {
    tab = "%d of %d completed  |  %d shown",
    favorites = "%d of %d favorites completed  |  %d shown",
    search = "%d of %d matches completed  |  %d shown",
}

local ITEM_STATUS_FORMATS = {
    tab = "%d of %d collected  |  %d shown",
    favorites = "%d of %d favorites collected  |  %d shown",
    search = "%d of %d matches collected  |  %d shown",
}

local function UpdateAchievementButton(button, info)
    button.info = info
    button.Icon:SetTexture(info.icon or FALLBACK_ICON)
    button.Name:SetText(info.name)

    if info.completed then
        button.Name:SetFontObject("GameFontNormal")
        button.Icon:SetDesaturated(false)
        button.Icon:SetVertexColor(1, 1, 1)
        button.CompletedMark:Show()
    else
        button.Name:SetFontObject("GameFontDisable")
        button.Icon:SetDesaturated(true)
        button.Icon:SetVertexColor(0.55, 0.55, 0.55)
        button.CompletedMark:Hide()
    end

    -- Items are named in their quality colour (dimmed until collected).
    if info.isItem and info.qualityColor then
        local c = info.qualityColor
        local dim = info.completed and 1 or 0.6
        button.Name:SetTextColor(c[1] * dim, c[2] * dim, c[3] * dim)
    else
        -- SetFontObject does not clear an earlier SetTextColor, so restore the
        -- font's own colour (original achievement look).
        local fontObject = info.completed and GameFontNormal or GameFontDisable
        button.Name:SetTextColor(fontObject:GetTextColor())
    end

    button:SetAlpha(info.unavailable and 0.5 or 1)
    button.Favorite:SetShown(IsFavorite(info.id))
    button:Show()
end

UpdateCollection = function()
    if not initialized or not ui.main or not ui.iconsFrame then
        return
    end

    local query = ui.search and (ui.search:GetText() or "") or ""
    query = query:lower():match("^%s*(.-)%s*$")

    local infos, scope = CollectSource(query)

    local scoped = {}
    local completedCount = 0
    visibleAchievements = {}

    for _, info in ipairs(infos) do
        if MatchesQuery(info, query) then
            scoped[#scoped + 1] = info

            if info.completed then
                completedCount = completedCount + 1
            end

            if MatchesStatusFilter(info) then
                visibleAchievements[#visibleAchievements + 1] = info
            end
        end
    end

    table.sort(visibleAchievements, SORTERS[db.sort] or SORTERS.status)

    -- Empty state
    local total = #visibleAchievements
    if total == 0 then
        local noun = IsItemMode() and "item" or "achievement"

        if scope == "favorites" and #scoped == 0 and query == "" then
            ui.emptyText:SetText(
                "No favorites yet.\nRight-click an " .. noun .. " and choose Add to Favorites."
            )
        else
            ui.emptyText:SetText("No " .. noun .. "s match the current filters.")
        end
        ui.emptyText:Show()
    else
        ui.emptyText:Hide()
    end

    -- Paging
    local maxPage = math.max(1, math.ceil(total / ITEMS_PER_PAGE))
    currentPage = math.min(math.max(currentPage, 1), maxPage)

    local first = (currentPage - 1) * ITEMS_PER_PAGE

    for slot = 1, ITEMS_PER_PAGE do
        local button = achievementButtons[slot] or CreateAchievementButton(slot)
        local info = visibleAchievements[first + slot]

        if info then
            UpdateAchievementButton(button, info)
        else
            button.info = nil
            button:Hide()
        end
    end

    ui.pageText:SetFormattedText("Page %d of %d", currentPage, maxPage)
    ui.prevPage:SetEnabled(currentPage > 1)
    ui.nextPage:SetEnabled(currentPage < maxPage)

    ui.status:SetText(
        string.format(
            (IsItemMode() and ITEM_STATUS_FORMATS or STATUS_FORMATS)[scope],
            completedCount, #scoped, total
        )
    )

    -- Keep the detail panel in sync with the (possibly changed) selection.
    local found
    if selectedAchievementID then
        for _, info in ipairs(visibleAchievements) do
            if info.id == selectedAchievementID then
                found = info
                break
            end
        end
    end
    UpdateDetails(found)
    RefreshSelectionHighlight()
end

------------------------------------------------------------
-- Progress (per-expansion counters for the menu + the header bar)
------------------------------------------------------------

RefreshProgress = function()
    if not initialized or not ui.main then
        return
    end

    local itemMode = IsItemMode()
    local groups = itemMode and VENDORS or EXPANSIONS
    local idLists = itemMode and VENDOR_IDS or EXPANSION_IDS
    local entries = itemMode and ITEM_ENTRIES or ALL_ENTRIES
    local favorites = CurrentFavorites()

    local seen = {}
    local overallDone, overallTotal = 0, 0

    wipe(groupProgress)

    for groupIndex = 1, #groups do
        local done, total = 0, 0

        for _, id in ipairs(idLists[groupIndex] or {}) do
            if ShouldShowForCurrentFaction(id) then
                local info = GetEntryInfo(id)

                -- Items still loading are counted (their ID is known).
                if not info.unavailable or info.isItem then
                    total = total + 1
                    if info.completed then
                        done = done + 1
                    end

                    if not seen[id] then
                        seen[id] = true
                        overallTotal = overallTotal + 1
                        if info.completed then
                            overallDone = overallDone + 1
                        end
                    end
                end
            end
        end

        groupProgress[groupIndex] = { done, total }
    end

    favoriteCount = 0
    for _, entry in ipairs(entries) do
        if favorites[entry.id] and ShouldShowForCurrentFaction(entry.id) then
            favoriteCount = favoriteCount + 1
        end
    end

    local percent = 0
    if overallTotal > 0 then
        percent = math.floor(overallDone / overallTotal * 100 + 0.5)
    end

    ui.progress:SetMinMaxValues(0, math.max(overallTotal, 1))
    ui.progress:SetValue(overallDone)
    ui.progress.Text:SetText(
        string.format("%d / %d  (%d%%)", overallDone, overallTotal, percent)
    )

    -- Counts shown inside the dropdown menus changed.
    UpdateNavButtons()
end

------------------------------------------------------------
-- Window position
------------------------------------------------------------

local function SavePosition()
    local point, _, relativePoint, x, y = ui.main:GetPoint()
    if point then
        db.position = {
            point = point,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end
end

local function RestorePosition()
    local position = db.position

    ui.main:ClearAllPoints()

    if type(position) == "table" and position.point then
        ui.main:SetPoint(
            position.point,
            UIParent,
            position.relativePoint or position.point,
            position.x or 0,
            position.y or 0
        )
    else
        ui.main:SetPoint("CENTER")
    end
end
------------------------------------------------------------
-- Main window construction (Collections journal layout)
------------------------------------------------------------
--
--  +--------------------------------------------------------+
--  | (portrait)        Feats of Strength Tracker         [X] |
--  |  [progress bar]   [search box]              [Filter v]  |
--  | +----------------------------------------------------+ |
--  | | [Expansion v] [Category v]            status text   | |
--  | |  icon Name     icon Name     icon Name              | |
--  | |  ... 3 columns x 6 rows per page ...                | |
--  | |            <  Page 1 of 3  >                        | |
--  | | +------------------------------------------------+ | |
--  | | | selected achievement details + actions          | | |
--  | | +------------------------------------------------+ | |
--  | +----------------------------------------------------+ |
--  +--------------------------------------------------------+

local INSET_TOP = -60

local function CreateFrameShell(frameName)
    local ok, frame = pcall(
        CreateFrame, "Frame", frameName, UIParent, "ButtonFrameTemplate"
    )

    if ok and frame and frame.Inset then
        if ButtonFrameTemplate_HideButtonBar then
            ButtonFrameTemplate_HideButtonBar(frame)
        end

        if frame.SetPortraitToAsset then
            frame:SetPortraitToAsset(PORTRAIT_ICON)
        end

        if frame.SetTitle then
            frame:SetTitle(TITLE)
        elseif frame.TitleContainer and frame.TitleContainer.TitleText then
            frame.TitleContainer.TitleText:SetText(TITLE)
        end

        if frame.CloseButton then
            frame.CloseButton:SetScript("OnClick", function()
                frame:Hide()
            end)
        end

        ui.inset = frame.Inset
        frame:SetSize(LAYOUT.frameWidth, LAYOUT.frameHeight)

        ui.inset:ClearAllPoints()
        ui.inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, INSET_TOP)
        ui.inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 5)

        return frame
    end

    -- Fallback: plain dark window if the template is missing.
    frame = CreateFrame("Frame", frameName, UIParent)
    frame:SetSize(LAYOUT.frameWidth, LAYOUT.frameHeight)

    frame.Background = frame:CreateTexture(nil, "BACKGROUND")
    frame.Background:SetAllPoints()
    SetTextureColor(frame.Background, 0.025, 0.025, 0.03, 0.98)

    local title = CreateLabel(
        frame, TITLE, "GameFontNormalLarge", "TOP", frame, "TOP", 0, -14
    )
    title:SetTextColor(1, 0.82, 0)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -1, -1)
    close:SetScript("OnClick", function()
        frame:Hide()
    end)

    ui.inset = CreatePanel(frame, 10, 10)
    ui.inset:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, INSET_TOP)
    ui.inset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 5)

    return frame
end

-- Progress bar, search box and filter dropdown: the row to the right of the
-- portrait, exactly where the Toy Box keeps them.
local function CreateHeader()
    local main = ui.main

    local bar = CreateFrame("StatusBar", nil, main)
    bar:SetSize(190, 18)
    bar:SetPoint("TOPLEFT", main, "TOPLEFT", 72, -35)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.20, 0.62, 0.28)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    bar.Border = bar:CreateTexture(nil, "BACKGROUND", nil, -2)
    bar.Border:SetPoint("TOPLEFT", -1, 1)
    bar.Border:SetPoint("BOTTOMRIGHT", 1, -1)
    SetTextureColor(bar.Border, 0.45, 0.35, 0.18, 1)

    bar.Background = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
    bar.Background:SetAllPoints()
    SetTextureColor(bar.Background, 0.06, 0.06, 0.07, 1)

    bar.Text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.Text:SetPoint("CENTER")

    ui.progress = bar

    -- Search box (falls back to a plain input box if the template is missing)
    local ok, box = pcall(CreateFrame, "EditBox", nil, main, "SearchBoxTemplate")
    if not ok or not box then
        box = CreateFrame("EditBox", nil, main, "InputBoxTemplate")
    end

    box:SetSize(190, 20)
    box:SetPoint("LEFT", bar, "RIGHT", 14, 0)
    box:SetAutoFocus(false)
    box:SetMaxLetters(60)

    if box.Instructions then
        box.Instructions:SetText("Search all achievements...")
    end

    box:HookScript("OnTextChanged", function()
        ResetPage()
        UpdateCollection()
    end)

    box:HookScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    box:HookScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    box:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Search", 1, 0.82, 0)
        GameTooltip:AddLine(
            "Matches names, descriptions, rewards and IDs in every tab.",
            1, 1, 1, true
        )
        GameTooltip:Show()
    end)

    box:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    ui.search = box

    -- Filter dropdown (top right)
    local filter = CreateDropdown(main, "WowStyle1FilterDropdownTemplate")
    if filter then
        filter:SetPoint("TOPRIGHT", main, "TOPRIGHT", -14, -33)
        filter:SetWidth(100)
        SetupFilterMenu(filter)
    end
    ui.filterDropdown = filter
end

-- Expansion / category dropdowns and the status text on top of the grid.
local function CreateNavigationStrip()
    -- [View v] [Expansion / Vendor v] [Category v]            status text
    local mode = CreateDropdown(ui.main, "WowStyle1DropdownTemplate")
    if mode then
        mode:SetPoint("TOPLEFT", ui.inset, "TOPLEFT", 8, -7)
        mode:SetWidth(100)
        if mode.SetDefaultText then
            mode:SetDefaultText("View")
        end
        SetupModeMenu(mode)
    end
    ui.modeDropdown = mode

    local function PlaceAfterMode(dropdown, width)
        dropdown:SetWidth(width)
        if mode then
            dropdown:SetPoint("LEFT", mode, "RIGHT", 6, 0)
        else
            dropdown:SetPoint("TOPLEFT", ui.inset, "TOPLEFT", 8, -7)
        end
    end

    local expansion = CreateDropdown(ui.main, "WowStyle1DropdownTemplate")
    if expansion then
        PlaceAfterMode(expansion, 180)
        if expansion.SetDefaultText then
            expansion:SetDefaultText("Expansion")
        end
        SetupExpansionMenu(expansion)
    end
    ui.expansionDropdown = expansion

    -- Vendor picker: takes the expansion dropdown's place in Items mode.
    local vendor = CreateDropdown(ui.main, "WowStyle1DropdownTemplate")
    if vendor then
        PlaceAfterMode(vendor, 180)
        if vendor.SetDefaultText then
            vendor:SetDefaultText("Vendor")
        end
        SetupVendorMenu(vendor)
        vendor:Hide()
    end
    ui.vendorDropdown = vendor

    local category = CreateDropdown(ui.main, "WowStyle1DropdownTemplate")
    if category then
        category:SetWidth(120)
        if expansion then
            category:SetPoint("LEFT", expansion, "RIGHT", 6, 0)
        else
            category:SetPoint("TOPLEFT", ui.inset, "TOPLEFT", 8, -7)
        end
        if category.SetDefaultText then
            category:SetDefaultText("Category")
        end
        SetupCategoryMenu(category)
        category:Hide()
    end
    ui.categoryDropdown = category

    ui.status = CreateLabel(
        ui.main, "", "GameFontNormalSmall",
        "TOPRIGHT", ui.inset, "TOPRIGHT", -12, -12
    )
    ui.status:SetJustifyH("RIGHT")
    ui.status:SetWordWrap(false)
    ui.status:SetTextColor(0.75, 0.75, 0.75)
end

local function CreatePageButton(parent, direction)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(32, 32)

    local prefix = "Interface\\Buttons\\UI-SpellbookIcon-" .. direction .. "Page-"
    button:SetNormalTexture(prefix .. "Up")
    button:SetPushedTexture(prefix .. "Down")
    button:SetDisabledTexture(prefix .. "Disabled")
    button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

    return button
end

local function CreateGrid()
    local frame = CreateFrame("Frame", nil, ui.main)
    frame:SetPoint("TOPLEFT", ui.inset, "TOPLEFT", 6, -(LAYOUT.headerStripHeight + 4))
    frame:SetPoint("TOPRIGHT", ui.inset, "TOPRIGHT", -6, -(LAYOUT.headerStripHeight + 4))
    frame:SetHeight(LAYOUT.gridHeight)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then
            SetPage(currentPage - 1)
        else
            SetPage(currentPage + 1)
        end
    end)
    ui.iconsFrame = frame

    frame.Background = frame:CreateTexture(nil, "BACKGROUND")
    frame.Background:SetAllPoints()
    SetTextureColor(frame.Background, 0.045, 0.045, 0.055, 0.55)

    for index = 1, ITEMS_PER_PAGE do
        CreateAchievementButton(index)
    end

    ui.emptyText = CreateLabel(
        frame, "", "GameFontNormal", "CENTER", frame, "CENTER", 0, 20
    )
    ui.emptyText:SetTextColor(0.6, 0.6, 0.6)
    ui.emptyText:Hide()

    -- Paging controls, bottom centre
    ui.pageText = CreateLabel(
        frame, "", "GameFontNormal", "BOTTOM", frame, "BOTTOM", 0, 14
    )

    ui.prevPage = CreatePageButton(frame, "Prev")
    ui.prevPage:SetPoint("RIGHT", ui.pageText, "LEFT", -18, 0)
    ui.prevPage:SetScript("OnClick", function()
        SetPage(currentPage - 1)
    end)

    ui.nextPage = CreatePageButton(frame, "Next")
    ui.nextPage:SetPoint("LEFT", ui.pageText, "RIGHT", 18, 0)
    ui.nextPage:SetScript("OnClick", function()
        SetPage(currentPage + 1)
    end)
end

local function CreateDetailPanel()
    local detail = CreatePanel(ui.main, 100, 150)
    detail:SetPoint("TOPLEFT", ui.iconsFrame, "BOTTOMLEFT", 0, -6)
    detail:SetPoint("BOTTOMRIGHT", ui.inset, "BOTTOMRIGHT", -6, 6)
    ui.detail = detail

    detail.Icon = detail:CreateTexture(nil, "ARTWORK")
    detail.Icon:SetSize(58, 58)
    detail.Icon:SetPoint("TOPLEFT", 12, -12)
    detail.Icon:SetTexture(FALLBACK_ICON)

    detail.Name = CreateLabel(
        detail, "Select an achievement", "GameFontNormalLarge",
        "TOPLEFT", detail, "TOPLEFT", 82, -12
    )
    detail.Name:SetWidth(380)
    detail.Name:SetJustifyH("LEFT")

    detail.Meta = CreateLabel(
        detail, "", "GameFontNormalSmall",
        "TOPLEFT", detail.Name, "BOTTOMLEFT", 0, -5
    )
    detail.Meta:SetTextColor(0.65, 0.65, 0.65)

    detail.Status = CreateLabel(
        detail, "", "GameFontNormal",
        "TOPLEFT", detail.Meta, "BOTTOMLEFT", 0, -5
    )

    detail.Earned = CreateLabel(
        detail, "", "GameFontNormalSmall",
        "LEFT", detail.Status, "RIGHT", 10, 0
    )
    detail.Earned:SetTextColor(0.65, 0.65, 0.65)

    detail.BlackMarketNotice = CreateLabel(
        detail, "Can only be obtained through the Black Market Auction House.",
        "GameFontNormalSmall",
        "TOPLEFT", detail.Status, "BOTTOMLEFT", 0, -3
    )
    detail.BlackMarketNotice:SetTextColor(1, 0.1, 0.1)
    detail.BlackMarketNotice:Hide()

    detail.Description = CreateLabel(
        detail,
        "Click an achievement icon to view its description.",
        "GameFontHighlightSmall",
        "TOPLEFT", detail.Icon, "BOTTOMLEFT", 0, -9
    )
    detail.Description:SetWidth(340)
    detail.Description:SetJustifyH("LEFT")
    detail.Description:SetJustifyV("TOP")
    detail.Description:SetWordWrap(true)

    detail.Reward = CreateLabel(
        detail, "", "GameFontNormalSmall",
        "BOTTOMLEFT", detail, "BOTTOMLEFT", 12, 8
    )
    detail.Reward:SetWidth(340)
    detail.Reward:SetJustifyH("LEFT")

    -- 2x2 button grid in the bottom-right corner
    detail.OpenButton = CreateTextButton(detail, "Open Achievement", 150, 26)
    detail.OpenButton:SetPoint("BOTTOMRIGHT", -12, 12)
    detail.OpenButton:SetScript("OnClick", function()
        if selectedAchievementID then
            OpenAchievement(selectedAchievementID)
        end
    end)

    -- Items only: sits where "Open Achievement" sits in achievement mode.
    detail.View3DButton = CreateTextButton(detail, "View in 3D", 150, 26)
    detail.View3DButton:SetPoint("BOTTOMRIGHT", -12, 12)
    detail.View3DButton:Hide()
    detail.View3DButton:SetScript("OnClick", function()
        if selectedInfo and selectedInfo.isItem then
            ViewItemIn3D(selectedInfo)
        end
    end)
    detail.View3DButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if self:IsEnabled() then
            GameTooltip:SetText("View in 3D", 1, 0.82, 0)
            GameTooltip:AddLine("Opens the Dressing Room with this item.", 1, 1, 1, true)
        else
            GameTooltip:SetText("No 3D preview", 1, 0.82, 0)
            GameTooltip:AddLine("Only mounts, companions and wearable gear can be previewed.", 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    detail.View3DButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    detail.WowheadButton = CreateTextButton(detail, "Copy WowHead Link", 150, 26)
    detail.WowheadButton:SetPoint("RIGHT", detail.OpenButton, "LEFT", -6, 0)
    detail.WowheadButton:SetScript("OnClick", function()
        OpenWowheadPopup(selectedAchievementID)
    end)

    detail.FavoriteButton = CreateTextButton(detail, "Add Favorite", 150, 26)
    detail.FavoriteButton:SetPoint("BOTTOMRIGHT", detail.OpenButton, "TOPRIGHT", 0, 6)
    detail.FavoriteButton:SetScript("OnClick", function()
        ToggleFavorite(selectedAchievementID)
    end)

    detail.TrackButton = CreateTextButton(detail, "Track", 150, 26)
    detail.TrackButton:SetPoint("RIGHT", detail.FavoriteButton, "LEFT", -6, 0)
    detail.TrackButton:SetScript("OnClick", function()
        ToggleTracking(selectedAchievementID)
    end)
end

------------------------------------------------------------
-- Window toggle
------------------------------------------------------------

local function ToggleWindow()
    if not initialized or not ui.main then
        return
    end

    if ui.main:IsShown() then
        ui.main:Hide()
    else
        ui.main:Show()
    end
end

------------------------------------------------------------
-- Side column: Power / Talents / Currency / Phase
------------------------------------------------------------
-- Four stacked sub-frames to the right of the main window. They are children
-- of the main frame, so they open, close, scale and move with it, while their
-- own border keeps them visually separate. Dragging them moves the main frame.

local function AddBorder(frame, r, g, b)
    local function Edge(point1, point2, width, height)
        local edge = frame:CreateTexture(nil, "BORDER")
        edge:SetPoint(point1)
        edge:SetPoint(point2)
        if width then edge:SetWidth(width) end
        if height then edge:SetHeight(height) end
        SetTextureColor(edge, r, g, b, 1)
    end

    Edge("TOPLEFT", "TOPRIGHT", nil, 1)
    Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
    Edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
    Edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)
end

local function CreateSidePanel()
    local main = ui.main
    local gap = LAYOUT.sideGap
    local usable = LAYOUT.frameHeight - gap * (#SIDE_SECTIONS - 1)

    ui.sections = {}

    local previous

    for index, def in ipairs(SIDE_SECTIONS) do
        local isLast = index == #SIDE_SECTIONS
        local height = math.floor(usable * def.weight)
        local section = CreatePanel(main, LAYOUT.sideWidth, height)

        if not previous then
            section:SetPoint("TOPLEFT", main, "TOPRIGHT", LAYOUT.sideOffset, 0)
        else
            section:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -gap)
        end

        if isLast then
            -- Fill whatever is left so the stack ends exactly at the main
            -- frame's bottom edge (never taller than the main frame).
            section:SetPoint("BOTTOMLEFT", main, "BOTTOMRIGHT", LAYOUT.sideOffset, 0)
        end

        AddBorder(section, 0.42, 0.31, 0.17)

        section.Title = section:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        section.Title:SetPoint("TOPLEFT", 12, -9)
        section.Title:SetText(def.label)
        section.Title:SetTextColor(1, 0.82, 0)

        section.Divider = section:CreateTexture(nil, "ARTWORK")
        section.Divider:SetPoint("TOPLEFT", 8, -28)
        section.Divider:SetPoint("TOPRIGHT", -8, -28)
        section.Divider:SetHeight(1)
        SetTextureColor(section.Divider, 0.30, 0.23, 0.12, 1)

        section.Body = section:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        section.Body:SetPoint("TOPLEFT", section.Divider, "BOTTOMLEFT", 4, -8)
        section.Body:SetPoint("TOPRIGHT", section.Divider, "BOTTOMRIGHT", -4, -8)
        section.Body:SetJustifyH("LEFT")
        section.Body:SetJustifyV("TOP")
        section.Body:SetWordWrap(true)
        section.Body:SetTextColor(0.7, 0.7, 0.7)
        section.Body:SetText("Placeholder: " .. def.label .. " will go here")

        -- Drag the whole window from the side column as well.
        section:EnableMouse(true)
        section:RegisterForDrag("LeftButton")
        section:SetScript("OnDragStart", function()
            if not (InCombatLockdown and InCombatLockdown()) then
                main:StartMoving()
            end
        end)
        section:SetScript("OnDragStop", function()
            main:StopMovingOrSizing()
            SavePosition()
        end)

        ui.sections[def.label] = section
        previous = section
    end
end

------------------------------------------------------------
-- Minimap button
------------------------------------------------------------

local function UpdateMinimapButtonPosition()
    local button = ui.minimapButton
    if not button or not Minimap then
        return
    end

    local angle = math.rad(db.minimap.angle or 215)
    local cosine, sine = math.cos(angle), math.sin(angle)
    local radius = Minimap:GetWidth() / 2 + 5
    local x, y = cosine * radius, sine * radius

    -- Square minimaps: keep the button on the edge instead of a circle.
    local shape = type(GetMinimapShape) == "function" and GetMinimapShape() or "ROUND"
    if shape == "SQUARE" then
        local diagonal = math.sqrt(2 * radius * radius) - 10
        x = math.max(-radius, math.min(cosine * diagonal, radius))
        y = math.max(-radius, math.min(sine * diagonal, radius))
    end

    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function MinimapButtonDragUpdate()
    local centerX, centerY = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()

    cursorX, cursorY = cursorX / scale, cursorY / scale

    db.minimap.angle = math.deg(math.atan2(cursorY - centerY, cursorX - centerX)) % 360
    UpdateMinimapButtonPosition()
end

local function CreateMinimapButton()
    if ui.minimapButton or not Minimap then
        return
    end

    local button = CreateFrame("Button", "FoSTMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    button.Background = button:CreateTexture(nil, "BACKGROUND")
    button.Background:SetSize(20, 20)
    button.Background:SetPoint("TOPLEFT", 7, -5)
    button.Background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    button.Icon = button:CreateTexture(nil, "ARTWORK")
    button.Icon:SetSize(18, 18)
    button.Icon:SetPoint("TOPLEFT", 7, -6)
    button.Icon:SetTexture(MINIMAP_ICON)
    button.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    button.Border = button:CreateTexture(nil, "OVERLAY")
    button.Border:SetSize(53, 53)
    button.Border:SetPoint("TOPLEFT")
    button.Border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button:SetScript("OnClick", function()
        ToggleWindow()
    end)

    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:LockHighlight()
        self:SetScript("OnUpdate", MinimapButtonDragUpdate)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(TITLE, 1, 0.82, 0)
        GameTooltip:AddLine("Left-click: show / hide the window", 1, 1, 1)
        GameTooltip:AddLine("Drag: move this button", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    ui.minimapButton = button

    UpdateMinimapButtonPosition()
    button:SetShown(not db.minimap.hide)
end

local function CreateMainFrame()
    if ui.main then
        return
    end

    local frameName = "MidnightAchievementCollectionFrame"

    ui.main = CreateFrameShell(frameName)
    ui.main:SetFrameStrata("DIALOG")
    ui.main:SetClampedToScreen(true)
    -- Count the side column as part of the window when clamping to the screen.
    ui.main:SetClampRectInsets(0, -(LAYOUT.sideWidth + LAYOUT.sideOffset), 0, 0)
    ui.main:SetMovable(true)
    ui.main:EnableMouse(true)
    ui.main:RegisterForDrag("LeftButton")
    ui.main:SetScale(db.scale)
    RestorePosition()

    ui.main:SetScript("OnDragStart", function(self)
        if not (InCombatLockdown and InCombatLockdown()) then
            self:StartMoving()
        end
    end)

    ui.main:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)

    CreateHeader()
    CreateNavigationStrip()
    CreateGrid()
    CreateDetailPanel()
    CreateSidePanel()

    ui.main:SetScript("OnShow", function()
        RefreshSubTabs()
        RefreshProgress()
        UpdateCollection()
    end)

    -- Close with Escape.
    tinsert(UISpecialFrames, frameName)

    ui.main:Hide()
end

------------------------------------------------------------
-- Slash commands
------------------------------------------------------------

local function ShowHelp()
    Print("Commands (/rhe, /mac, /achjournal):")
    print("  /rhe - toggle the window")
    print("  /rhe all | completed | incomplete - set the status filter")
    print("  /rhe items - switch to the Items (vendors) view")
    print("  /rhe achievements - switch to the Achievements view")
    print("  /rhe favorites - open the Favorites tab")
    print("  /rhe search <text> - search every tab")
    print("  /rhe refresh - re-read achievement data")
    print("  /rhe scale <0.6-1.5> - change the window scale")
    print("  /rhe minimap - show or hide the minimap button")
    print("  /rhe reset - reset window position and scale")
    print("  /rhe clearfavorites - remove all favorites")
end

local function ShowWindow()
    if not ui.main:IsShown() then
        ui.main:Show()
    end
end

SLASH_MIDNIGHTACHIEVEMENTCOLLECTION1 = "/achjournal"
SLASH_MIDNIGHTACHIEVEMENTCOLLECTION2 = "/mac"
SLASH_MIDNIGHTACHIEVEMENTCOLLECTION3 = "/rhe"

SlashCmdList["MIDNIGHTACHIEVEMENTCOLLECTION"] = function(message)
    if not initialized or not ui.main then
        Print("Addon is still loading.")
        return
    end

    message = (message or ""):match("^%s*(.-)%s*$")
    local command, rest = message:match("^(%S*)%s*(.-)$")
    command = (command or ""):lower()

    if command == "" then
        ToggleWindow()
    elseif command == "all" then
        SetFilter(FILTER_ALL)
        ShowWindow()
    elseif command == "completed" then
        SetFilter(FILTER_COMPLETED)
        ShowWindow()
    elseif command == "incomplete" then
        SetFilter(FILTER_INCOMPLETE)
        ShowWindow()
    elseif command == "items" or command == "item" or command == "vendors" then
        SetMode(MODE_ITEMS)
        ShowWindow()
    elseif command == "achievements" or command == "achievement" then
        SetMode(MODE_ACHIEVEMENTS)
        ShowWindow()
    elseif command == "fav" or command == "favs" or command == "favorites" then
        if IsItemMode() then
            SetVendor(FAVORITES_TAB)
        else
            SetExpansion(FAVORITES_TAB)
        end
        ShowWindow()
    elseif command == "search" then
        ShowWindow()
        if IsFavoritesView() and rest ~= "" then
            -- Search is scoped to favorites there; searching "everywhere"
            -- needs a normal tab.
            if IsItemMode() then
                SetVendor(1)
            else
                SetExpansion(1)
            end
        end
        ui.search:SetText(rest or "")
    elseif command == "minimap" then
        db.minimap.hide = not db.minimap.hide
        if ui.minimapButton then
            ui.minimapButton:SetShown(not db.minimap.hide)
        end
        Print(db.minimap.hide and "Minimap button hidden." or "Minimap button shown.")
    elseif command == "refresh" then
        RefreshProgress()
        UpdateCollection()
        Print("Data updated.")
    elseif command == "scale" then
        local scale = tonumber(rest)
        if scale and scale >= 0.6 and scale <= 1.5 then
            db.scale = scale
            ui.main:SetScale(scale)
            Print(string.format("Scale set to %.2f.", scale))
        else
            PrintError("Usage: /rhe scale <0.6 - 1.5>")
        end
    elseif command == "reset" then
        db.position = nil
        db.scale = 1
        ui.main:SetScale(1)
        RestorePosition()
        Print("Window position and scale reset.")
    elseif command == "clearfavorites" or command == "clearfavs" then
        StaticPopup_Show("FOST_CLEAR_FAVORITES", IsItemMode() and "items" or "achievements")
    else
        ShowHelp()
    end
end

------------------------------------------------------------
-- Events
------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("ACHIEVEMENT_EARNED")

-- Optional events: not every client version has both, and registering an
-- unknown event raises an error, so guard them.
for _, optionalEvent in ipairs({
    "TRACKED_ACHIEVEMENT_LIST_CHANGED",
    "CONTENT_TRACKING_UPDATE",
}) do
    pcall(eventFrame.RegisterEvent, eventFrame, optionalEvent)
end

-- Item mode: item data arriving from the server, and collection changes.
local ITEM_REFRESH_EVENTS = {
    GET_ITEM_INFO_RECEIVED = true,
    BAG_UPDATE_DELAYED = true,
    NEW_MOUNT_ADDED = true,
    NEW_PET_ADDED = true,
    TOYS_UPDATED = true,
    TRANSMOG_COLLECTION_UPDATED = true,
}

for itemEvent in pairs(ITEM_REFRESH_EVENTS) do
    pcall(eventFrame.RegisterEvent, eventFrame, itemEvent)
end

-- These events can fire in bursts, so refresh once shortly after the last one.
local itemRefreshPending = false

local function ScheduleItemRefresh()
    if itemRefreshPending or not IsItemMode() then
        return
    end
    if not (ui.main and ui.main:IsShown()) then
        return
    end

    itemRefreshPending = true
    C_Timer.After(0.3, function()
        itemRefreshPending = false
        if IsItemMode() and ui.main and ui.main:IsShown() then
            RefreshProgress()
            UpdateCollection()
        end
    end)
end

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedName = ...

        if loadedName ~= addonName then
            return
        end

        InitializeDB()
        BuildStaticIndex()
        CreateMainFrame()
        CreateMinimapButton()
        initialized = true

        -- Data itself is loaded lazily in OnShow; only set up button states.
        UpdateModeUI()

        self:UnregisterEvent("ADDON_LOADED")

        Print("loaded. Type /rhe (or /mac) to open, /rhe help for commands.")
        return
    end

    if not initialized then
        return
    end

    if event == "ACHIEVEMENT_EARNED" then
        local id, alreadyEarned = ...

        if id and not alreadyEarned and db.favorites[id] then
            local link = GetAchievementLinkSafe(id)
            Print("Favorite achievement earned: " .. (link or ("#" .. id)))
        end

        if not IsItemMode() then
            RefreshProgress()
            if ui.main:IsShown() then
                UpdateCollection()
            end
        end
    elseif ITEM_REFRESH_EVENTS[event] then
        ScheduleItemRefresh()
    elseif ui.main:IsShown() and selectedInfo and not selectedInfo.isItem then
        -- Tracking list changed: refresh the Track button label.
        UpdateDetails(selectedInfo)
    end
end)