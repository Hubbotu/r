-------------------------------------------------------------------------------
-- Farm Ledger
-- Tracks specific items you obtain and values them with Oribos Exchange data.
--  * Per-day snapshots of value (server AND region price stored at acquisition)
--  * Totals for Today / This week (Mon-Fri) / This month
--  * "Held / Gained" counter per item: moving an item to the bank lowers "held"
--    but the gained count and its value stay in the daily total.
--  * Settings: language (English / Russian / German) and frame color.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

-------------------------------------------------------------------------------
-- Tracked items.  Window tabs (left column) > groups (expansions, right column)
--   every item is { itemID, iconFileID }
-- To add an item later, append it to the `items` table of the right group.
-- Empty groups are kept on purpose so there is already a slot ready to fill.
-------------------------------------------------------------------------------
local ZG_ICON = 1500867                      -- shared icon of the Zul'Gurub set items (2038xx / 203968)
local ZG_FARM = {
    { 20520, 136192 }, { 12655, 133229 }, { 14256, 132888 }, { 19931, 134711 },   -- own icons
}
for _, id in ipairs({
    203831, 203834, 203838, 203826, 203833, 203829, 203840, 203847, 203843, 203849,
    203845, 203830, 203841, 203861, 203842, 203851, 203837, 203848, 203832, 203824,
    203828, 203850, 203968, 203839, 203836, 203827, 203846, 203835, 203825, 203844,
}) do ZG_FARM[#ZG_FARM + 1] = { id, ZG_ICON } end

-- Zul'Gurub exchange: { itemID, iconFileID, amount needed for ONE reward }
local ZG_EXCHANGE = {
    { 203772, 132533, 2 }, { 203768, 132529, 3 }, { 203767, 132528, 3 },
    { 203766, 132527, 2 }, { 203771, 132532, 3 }, { 203769, 132530, 2 },
    { 203773, 132534, 3 }, { 203770, 132531, 2 }, { 203765, 132526, 3 },
}
local ZG_REWARD = { 203959, 901746 }         -- 1 reward per exchange set

local TABS = {
    {
        key = "general", kind = "list", expansions = true,
        groups = {
            { name = "Vanilla", items = {
                { 1604, 135323 },
            } },
            { name = "The Burning Crusade", items = {} },
            { name = "Wrath of the Lich King", items = {} },
            { name = "Cataclysm", items = {
                { 67151, 433440 }, { 52496, 134941 }, { 52494, 134941 }, { 52495, 134941 },
                { 67541, 134941 }, { 71965, 134941 }, { 69843, 376833 },
            } },
            { name = "Pandaria", items = {
                { 92426, 666474 },
            } },
            { name = "Draenor", items = {
                { 108631, 879998 }, { 108633, 1035038 }, { 108634, 1035047 }, { 119431, 136221 },
                { 128315, 237560 }, { 128314, 236313 }, { 128671, 1245298 },
            } },
            { name = "Legion", items = {} },
            { name = "Battle for Azeroth", items = {} },
            { name = "Shadowlands", items = {
                { 181267, 3386335 }, { 181265, 3860399 }, { 181266, 3860398 }, { 181172, 2027855 },
                { 180869, 656319 },
            } },
            { name = "Dragonflight", items = {
                { 205463, 1032477 }, { 205419, 133841 },
            } },
            { name = "The War Within", items = {} },
            { name = "Midnight", items = {} },
        },
    },
    {
        key = "naxx", kind = "list",
        groups = {
            { items = {
                { 207702, 4622301 }, { 22682, 134422 },
                { 206604, 133124 },  { 206605, 135042 },  { 206606, 132627 },  { 206607, 132614 },
                { 206608, 132965 },  { 206609, 132524 },  { 206610, 134693 },  { 206611, 132548 },
            } },
        },
    },
    { key = "icc", kind = "icc" },                           -- custom panel
    { key = "zg", kind = "list", exchange = true,            -- exchange block on top + farm list below
      groups = { { items = ZG_FARM } } },
}

-- Flat list of every tracked item (used for bag scanning / gain tracking)
local ITEMS = {}
local MAX_LIST_ROWS = 0
for _, tab in ipairs(TABS) do
    if tab.groups then
        local n = 0
        for _, g in ipairs(tab.groups) do
            for _, it in ipairs(g.items) do ITEMS[#ITEMS + 1] = it end
            n = n + #g.items + (g.name and 1 or 0)
        end
        MAX_LIST_ROWS = math.max(MAX_LIST_ROWS, n)
    end
end

-------------------------------------------------------------------------------
-- Icecrown Citadel tab data
-------------------------------------------------------------------------------
local ICC_QUESTS = { 24545, 24743, 24547, 24749, 24756, 24757, 24548, 24549, 24748 }  -- 1st .. 9th
local ICC_FINAL_QUEST = 24748
local ICC_INSTANCE_ID = 631                         -- Icecrown Citadel (raid instance ID)
local ICC_CLASSES = { "PALADIN", "WARRIOR", "DEATHKNIGHT" }
local ICC_CLASS_SET = { PALADIN = true, WARRIOR = true, DEATHKNIGHT = true }
local ICC_ITEMS = {                                 -- { itemID, iconFileID }
    { 52200, 237534 }, { 52252, 135026 }, { 52251, 133308 }, { 52201, 135850 }, { 52253, 133876 },
}
local SHARD_ITEM, SHARD_ICON, SHARD_NEEDED = 50274, 340336, 50   -- Shadowfrost Shard
local SHARD_ITEM, SHARD_ICON = 50274, 340336        -- Shadowfrost Shard

-- Battle pets: the list shows the ITEM, but the price is looked up by the pet's speciesID.
local PET_SPECIES = {
    [181267] = 2957,
    [181265] = 2955,
    [181266] = 2956,
    [181172] = 2948,
    [180869] = 2940,
    [119431] = 1601,
}
local PET_CAGE_ITEM = 82800          -- every caged battle pet is item 82800 with a battlepet link
local SPECIES_TO_ITEM = {}
for itemID, species in pairs(PET_SPECIES) do SPECIES_TO_ITEM[species] = itemID end

-- Base stats from OE's speciesStats.lua (health, power, speed multipliers)
-- Used to build battlepet links that OE can match to a specific breed.
local SPECIES_STATS = {
    [2957] = {8, 7.625, 8.375},   -- 181267
    [2955] = {7.625, 8.375, 8},   -- 181265
    [2956] = {7.625, 8.375, 8},   -- 181266
    [2948] = {7.5, 8.175, 8.325}, -- 181172
    [2940] = {7.625, 8, 8.375},   -- 180869
    [1601] = {6.75, 9.25, 8},     -- 119431
}

-- Same breed points OE uses
local BREED_POINTS = {
    [3]  = {0.5, 0.5, 0.5},  -- B/B
    [4]  = {0, 2, 0},        -- P/P
    [5]  = {0, 0, 2},        -- S/S
    [6]  = {2, 0, 0},        -- H/H
    [7]  = {0.9, 0.9, 0},    -- H/P
    [8]  = {0, 0.9, 0.9},    -- P/S
    [9]  = {0.9, 0, 0.9},    -- H/S
    [10] = {0.4, 0.9, 0.4},  -- P/B
    [11] = {0.4, 0.4, 0.9},  -- S/B
    [12] = {0.9, 0.4, 0.4},  -- H/B
}

local function roundToOdd(value)
    local floored = math.floor(value)
    if math.floor((value - floored) * 1000000) == 500000 then
        if floored % 2 == 0 then return floored + 1 end
        return floored
    end
    return math.floor(value + 0.5)
end

-- Build a battlepet link whose health/power/speed match a specific breed
-- so OE's getBreedFromPetLink can resolve it correctly.
local function MakeBreedLink(species, breed, level, quality)
    level = level or 1
    quality = quality or 3
    local stats = SPECIES_STATS[species]
    local points = BREED_POINTS[breed]
    if not stats or not points then return nil end
    local qualityFactor = level * (1 + quality / 10)
    local health = roundToOdd((stats[1] + points[1]) * 5 * qualityFactor + 100)
    local power  = roundToOdd((stats[2] + points[2]) * qualityFactor)
    local speed  = roundToOdd((stats[3] + points[3]) * qualityFactor)
    return string.format("battlepet:%d:%d:%d:%d:%d:%d", species, level, quality, health, power, speed)
end

-------------------------------------------------------------------------------
-- Localization
-------------------------------------------------------------------------------
local LOCALES = {
    { code = "en", name = "English" },
    { code = "ru", name = "Русский" },
    { code = "de", name = "Deutsch" },
}

local L = {
    en = {
        settings = "Settings", back = "Back", language = "Language",
        frameColor = "Frame color", customColor = "Custom color...",
        allChars = "All characters", thisChar = "This character", hideEmpty = "Hide empty",
        serverPrice = "Server price", regionPrice = "Region price",
        cardDay = "TODAY", cardWeek = "THIS WEEK", cardMonth = "THIS MONTH", weekSub = "Mon-Fri",
        day = "Today", week = "This week (Mon-Fri)", month = "This month",
        colItem = "ITEM", colHeld = "HELD / GAINED", colValue = "VALUE",
        empty = "Nothing gained in this period yet.",
        gained = "gained:", value = "Value:", serverLine = "Server price:", regionLine = "Region price:",
        noData = "no data", noPrice = "no price", itemsCount = "Items: %d",
        priceTipTitle = "Price source",
        priceTipServer = "Server price: Oribos Exchange data for your realm.",
        priceTipRegion = "Region price: Oribos Exchange data for the whole region.",
        priceTipNote = "Switching recalculates all totals instantly.",
        noOE = "Oribos Exchange not detected - values will be 0",
        mmHint = "Click: open / close  -  Drag: move",
        cleared = "all recorded data cleared.",
        resetHint = "type /fl reset confirm to erase ALL recorded data.",
        srcLabel = "Price source", srcOE = "Oribos Exchange", srcAuc = "Auctionator", srcNone = "None",
        srcDetected = "detected", srcMissing = "not detected", aucLine = "Auctionator:",
        noAuc = "Auctionator not detected - values will be 0", priceOff = "Prices off",
        priceTipSource = "Region price needs Oribos Exchange. Change the price source in Settings.",
        theme_midnight = "Midnight", theme_graphite = "Graphite", theme_forest = "Forest",
        theme_wine = "Wine", theme_royal = "Royal", theme_amber = "Amber", theme_custom = "Custom",
        adjTip = "Click to adjust today's gained count (±1). Value recalculates from current prices.",
        tab_general = "General", tab_naxx = "Naxxramas", tab_icc = "Icecrown Citadel", tab_zg = "Zul'Gurub",
        expAll = "All", noItemsYet = "no items yet",
        iccInappropriate = "Inappropriate class", iccEligible = "Eligible classes:",
        iccAllObtained = "All rewards obtained.", iccProgress = "Progress %d/%d",
        iccItems = "REWARDS", iccTotal = "Total", lkName = "The Lich King", iccShardsFallback = "Shadowfrost Shard",
        iccPending = "Characters who have not completed quest The Lich King's Last Stand",
        iccNonePending = "No eligible characters left.",
        iccMissingPrices = "%d without price", iccPickSource = "Pick a price source to see prices.",
        colChar = "CHARACTER", colClass = "CLASS", colQuests = "PROGRESS", colShards = "SHARDS", colLK = "LICH KING",
        zgExchange = "EXCHANGE", zgOwned = "OWNED / NEEDED", zgYieldCol = "YIELD", zgPotential = "Potential yield",
        tipPrices = "Price lines in item tooltips", on = "On", off = "Off",
    },
    ru = {
        settings = "Настройки", back = "Назад", language = "Язык",
        frameColor = "Цвет окна", customColor = "Свой цвет...",
        allChars = "Все персонажи", thisChar = "Этот персонаж", hideEmpty = "Скрыть пустые",
        serverPrice = "Цена сервера", regionPrice = "Цена региона",
        cardDay = "СЕГОДНЯ", cardWeek = "ЭТА НЕДЕЛЯ", cardMonth = "ЭТОТ МЕСЯЦ", weekSub = "Пн-Пт",
        day = "Сегодня", week = "Эта неделя (Пн-Пт)", month = "Этот месяц",
        colItem = "ПРЕДМЕТ", colHeld = "ЕСТЬ / ПОЛУЧЕНО", colValue = "СТОИМОСТЬ",
        empty = "За этот период ничего не получено.",
        gained = "получено:", value = "Стоимость:", serverLine = "Цена сервера:", regionLine = "Цена региона:",
        noData = "нет данных", noPrice = "нет цены", itemsCount = "Предметов: %d",
        priceTipTitle = "Источник цен",
        priceTipServer = "Цена сервера: данные Oribos Exchange для вашего игрового мира.",
        priceTipRegion = "Цена региона: данные Oribos Exchange для всего региона.",
        priceTipNote = "Переключение мгновенно пересчитывает все суммы.",
        noOE = "Oribos Exchange не найден - стоимость будет равна 0",
        mmHint = "Клик: открыть / закрыть  -  Перетащить: переместить",
        cleared = "все записанные данные удалены.",
        resetHint = "введите /fl reset confirm, чтобы удалить ВСЕ данные.",
        srcLabel = "Источник цен", srcOE = "Oribos Exchange", srcAuc = "Auctionator", srcNone = "Нет",
        srcDetected = "найден", srcMissing = "не найден", aucLine = "Auctionator:",
        noAuc = "Auctionator не найден - стоимость будет равна 0", priceOff = "Цены отключены",
        priceTipSource = "Цена региона доступна только в Oribos Exchange. Источник цен меняется в настройках.",
        theme_midnight = "Полночь", theme_graphite = "Графит", theme_forest = "Лес",
        theme_wine = "Вино", theme_royal = "Королевский", theme_amber = "Янтарь", theme_custom = "Свой",
        tab_general = "Общее", tab_naxx = "Наксрамас", tab_icc = "Цитадель Ледяной Короны", tab_zg = "Зул'Гуруб",
        expAll = "Все", noItemsYet = "пока нет предметов",
        iccInappropriate = "Неподходящий класс", iccEligible = "Подходящие классы:",
        iccAllObtained = "Все награды получены.", iccProgress = "Прогресс %d/%d",
        iccItems = "НАГРАДЫ", iccTotal = "Итого", lkName = "Король-лич", iccShardsFallback = "Осколок",
        iccPending = "Персонажи, не выполнившие задание Последняя битва Короля-лича",
        iccNonePending = "Подходящих персонажей не осталось.",
        iccMissingPrices = "без цены: %d", iccPickSource = "Выберите источник цен, чтобы увидеть цены.",
        colChar = "ПЕРСОНАЖ", colClass = "КЛАСС", colQuests = "ПРОГРЕСС", colShards = "ОСКОЛКИ", colLK = "КОРОЛЬ-ЛИЧ",
        zgExchange = "ОБМЕН", zgOwned = "ЕСТЬ / НУЖНО", zgYieldCol = "ВЫХОД", zgPotential = "Возможный выход",
        tipPrices = "Строки цен в подсказках предметов", on = "Вкл", off = "Выкл",
    },
    de = {
        settings = "Einstellungen", back = "Zurück", language = "Sprache",
        frameColor = "Fensterfarbe", customColor = "Eigene Farbe...",
        allChars = "Alle Charaktere", thisChar = "Dieser Charakter", hideEmpty = "Leere ausblenden",
        serverPrice = "Serverpreis", regionPrice = "Regionspreis",
        cardDay = "HEUTE", cardWeek = "DIESE WOCHE", cardMonth = "DIESER MONAT", weekSub = "Mo-Fr",
        day = "Heute", week = "Diese Woche (Mo-Fr)", month = "Dieser Monat",
        colItem = "GEGENSTAND", colHeld = "BESITZ / ERHALTEN", colValue = "WERT",
        empty = "In diesem Zeitraum noch nichts erhalten.",
        gained = "erhalten:", value = "Wert:", serverLine = "Serverpreis:", regionLine = "Regionspreis:",
        noData = "keine Daten", noPrice = "kein Preis", itemsCount = "Gegenstände: %d",
        priceTipTitle = "Preisquelle",
        priceTipServer = "Serverpreis: Oribos-Exchange-Daten für deinen Realm.",
        priceTipRegion = "Regionspreis: Oribos-Exchange-Daten für die gesamte Region.",
        priceTipNote = "Beim Umschalten werden alle Summen sofort neu berechnet.",
        noOE = "Oribos Exchange nicht gefunden - Werte sind 0",
        mmHint = "Klick: öffnen / schließen  -  Ziehen: verschieben",
        cleared = "alle gespeicherten Daten gelöscht.",
        resetHint = "Gib /fl reset confirm ein, um ALLE Daten zu löschen.",
        srcLabel = "Preisquelle", srcOE = "Oribos Exchange", srcAuc = "Auctionator", srcNone = "Keine",
        srcDetected = "gefunden", srcMissing = "nicht gefunden", aucLine = "Auctionator:",
        noAuc = "Auctionator nicht gefunden - Werte sind 0", priceOff = "Preise aus",
        priceTipSource = "Der Regionspreis benötigt Oribos Exchange. Preisquelle in den Einstellungen ändern.",
        theme_midnight = "Mitternacht", theme_graphite = "Graphit", theme_forest = "Wald",
        theme_wine = "Wein", theme_royal = "Königsblau", theme_amber = "Bernstein", theme_custom = "Eigene",
        tab_general = "Allgemein", tab_naxx = "Naxxramas", tab_icc = "Eiskronenzitadelle", tab_zg = "Zul'Gurub",
        expAll = "Alle", noItemsYet = "noch keine Gegenstände",
        iccInappropriate = "Ungeeignete Klasse", iccEligible = "Geeignete Klassen:",
        iccAllObtained = "Alle Belohnungen erhalten.", iccProgress = "Fortschritt %d/%d",
        iccItems = "BELOHNUNGEN", iccTotal = "Gesamt", lkName = "Der Lichkönig", iccShardsFallback = "Splitter",
        iccPending = "Charaktere ohne abgeschlossene Quest Das letzte Gefecht des Lichkönigs",
        iccNonePending = "Keine geeigneten Charaktere übrig.",
        iccMissingPrices = "%d ohne Preis", iccPickSource = "Wähle eine Preisquelle, um Preise zu sehen.",
        colChar = "CHARAKTER", colClass = "KLASSE", colQuests = "FORTSCHRITT", colShards = "SPLITTER", colLK = "LICHKÖNIG",
        zgExchange = "TAUSCH", zgOwned = "BESITZ / BENÖTIGT", zgYieldCol = "ERTRAG", zgPotential = "Möglicher Ertrag",
        tipPrices = "Preiszeilen in Gegenstands-Tooltips", on = "An", off = "Aus",
    },
}

-------------------------------------------------------------------------------
-- Style
-------------------------------------------------------------------------------
local WHITE = "Interface\\Buttons\\WHITE8X8"
local FONT = "Fonts\\ARIALN.TTF"
do
    local loc = GetLocale()
    if loc == "koKR" or loc == "zhCN" or loc == "zhTW" then FONT = STANDARD_TEXT_FONT end
end
local FONT_BUMP = (FONT == STANDARD_TEXT_FONT) and 0 or 1

local C = {
    bg     = { 0.055, 0.058, 0.075, 0.96 },
    panel  = { 0.095, 0.100, 0.130, 1 },
    border = { 0.180, 0.190, 0.240, 1 },
    accent = { 0.250, 0.720, 0.960 },
    text   = { 0.920, 0.930, 0.950 },
    dim    = { 0.550, 0.570, 0.630 },
    warm   = { 0.780, 0.640, 0.380 },
    good   = { 0.450, 0.850, 0.500 },
    bad    = { 0.950, 0.400, 0.400 },
}
local WHITE_C = { 1, 1, 1, 1 }

local THEMES = {
    { key = "midnight", bg = { 0.055, 0.058, 0.075 }, accent = { 0.25, 0.72, 0.96 } },
    { key = "graphite", bg = { 0.085, 0.085, 0.090 }, accent = { 0.80, 0.82, 0.88 } },
    { key = "forest",   bg = { 0.040, 0.075, 0.060 }, accent = { 0.35, 0.85, 0.55 } },
    { key = "wine",     bg = { 0.095, 0.040, 0.060 }, accent = { 0.95, 0.40, 0.50 } },
    { key = "royal",    bg = { 0.070, 0.050, 0.115 }, accent = { 0.70, 0.52, 1.00 } },
    { key = "amber",    bg = { 0.090, 0.070, 0.040 }, accent = { 1.00, 0.75, 0.25 } },
}

local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
local PAD, GAP, ROW_H = 10, 8, 30
local HEADER_H = 24                           -- expansion header rows in the item list
local AREA_Y = 34                             -- content area starts under the title bar
local LEFT_W, RIGHT_W, SIDE_GAP = 140, 130, 8 -- left tab column / right expansion column
local SCOPE_Y, CARD_Y, COLHEAD_Y, SCROLL_Y = 8, 40, 110, 130   -- relative to the content area
local TOP_OFFSET_SCROLL = AREA_Y + SCROLL_Y   -- distance from the window top to the list
local ICC_Y = 8
local ICC_ROW_H = 22
local BOTTOM_OFFSET_SCROLL = 26

local PERIODS = {
    { key = "day",   card = "cardDay" },
    { key = "week",  card = "cardWeek", sub = true },
    { key = "month", card = "cardMonth" },
}

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------
local db, charKey
local main, Refresh, RequestRefresh, ApplyTheme, ApplyLanguage, RefreshSettings
local RefreshICC, UpdateICCScroll
local UI = { buttons = {}, swatches = {}, langButtons = {}, srcButtons = {} }
local baseline = {}                
local baselineCaged = {}           
local cagedLinks, cagedCounts = {}, {}   
local suppressUntil = 0            
local openInteractions = {}        
local ignoredTypes = {}            

-------------------------------------------------------------------------------
-- Helpers
-------------------------------------------------------------------------------
local function T(key)
    local lang = db and db.settings and db.settings.lang or "en"
    return (L[lang] and L[lang][key]) or L.en[key] or key
end

local function PeriodLabel(key) return T(key) end   

local function Hex(c)
    return string.format("|cff%02x%02x%02x",
        math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

local function Lift(c, d, a)
    return { math.min(1, c[1] + d), math.min(1, c[2] + d), math.min(1, c[3] + d), a or 1 }
end

local function FormatGold(copper)
    copper = copper or 0
    local gold = math.floor(copper / 10000)
    if gold == 0 and copper > 0 then
        return "< 1 " .. GOLD_ICON
    end
    return string.format("%s %s", BreakUpLargeNumbers(gold), GOLD_ICON)
end

local function CountInBags(itemID)
    if C_Item and C_Item.GetItemCount then
        return C_Item.GetItemCount(itemID, false, false, false, false) or 0
    end
    return GetItemCount(itemID, false, false, false) or 0
end

local function ForEachCaged(fn)
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return end
    local lastBag = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    for bag = 0, lastBag do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID == PET_CAGE_ITEM and info.hyperlink then
                fn(info.hyperlink, info.stackCount or 1, tonumber(info.hyperlink:match("battlepet:(%d+)")))
            end
        end
    end
end

local function ScanCagedPets()
    local counts = {}
    cagedLinks = {}
    ForEachCaged(function(link, stack, species)
        local itemID = species and SPECIES_TO_ITEM[species]
        if itemID then
            counts[itemID] = (counts[itemID] or 0) + stack
            local t = cagedLinks[itemID]
            if not t then t = {}; cagedLinks[itemID] = t end
            t[#t + 1] = link
        end
    end)
    return counts
end

local function GetItemNameQuality(itemID)
    local name, quality
    if C_Item and C_Item.GetItemInfo then
        name, _, quality = C_Item.GetItemInfo(itemID)
    else
        name, _, quality = GetItemInfo(itemID)
    end
    return name, quality
end

-------------------------------------------------------------------------------
-- Oribos Exchange integration
-------------------------------------------------------------------------------
local function OEAvailable()
    return type(OEMarketInfo) == "function"
end

local function QueryOE(key)
    local info = {}
    local ok = pcall(OEMarketInfo, key, info)
    if not ok then return nil end
    local m, r = tonumber(info.market), tonumber(info.region)
    if m and m <= 0 then m = nil end
    if r and r <= 0 then r = nil end
    if m or r then return m, r end
    return nil
end

local speciesCache = {}
local function GetSpeciesID(itemID)
    if PET_SPECIES[itemID] then return PET_SPECIES[itemID] end
    if speciesCache[itemID] then return speciesCache[itemID] end
    local species
    if C_PetJournal and C_PetJournal.GetPetInfoByItemID then
        local ok, speciesName, _, _, _, _, _, _, _, _, _, _, _, speciesID = pcall(C_PetJournal.GetPetInfoByItemID, itemID)
        if ok then
            species = speciesID
            if not species and speciesName and C_PetJournal.FindPetIDByName then
                species = C_PetJournal.FindPetIDByName(speciesName)
            end
        end
    end
    if species then speciesCache[itemID] = species end
    return species
end

local function PriceCandidates(itemID)
    local list = {}
    local sp = GetSpeciesID(itemID)
    if sp and SPECIES_STATS[sp] then
        -- Build real battlepet links for every common breed so OE can match them.
        -- This is the only way OEMarketInfo returns a price without a live caged pet.
        for breed = 3, 12 do
            local link = MakeBreedLink(sp, breed, 1, 3)
            if link then
                list[#list + 1] = { "breed " .. breed, link }
            end
        end
        -- Also try level 25 rare (common for caged pets)
        for breed = 3, 12 do
            local link = MakeBreedLink(sp, breed, 25, 3)
            if link then
                list[#list + 1] = { "lvl25 breed " .. breed, link }
            end
        end
    elseif sp then
        list[#list + 1] = { "battlepet link", string.format("battlepet:%d:1:3:0:0:0", sp) }
    end
    list[#list + 1] = { "itemID", itemID }
    local name = GetItemNameQuality(itemID)
    if name then list[#list + 1] = { "item name", name } end
    return list
end

local workingKey = {}   
local function GetPrices(itemID, petLink)
    if not OEAvailable() then return nil end
    if petLink then
        local m, r = QueryOE(petLink)
        if m or r then return m, r end
    end
    local cached = workingKey[itemID]
    if cached ~= nil then
        local m, r = QueryOE(cached)
        if m or r then return m, r end
    end
    for _, c in ipairs(PriceCandidates(itemID)) do
        local m, r = QueryOE(c[2])
        if m or r then
            workingKey[itemID] = c[2]
            return m, r
        end
    end
    return nil
end

-------------------------------------------------------------------------------
-- Auctionator integration (Auctionator.API.v1)
-------------------------------------------------------------------------------
local AUC_CALLER = "FarmLedger"

local function AuctionatorAvailable()
    return type(Auctionator) == "table" and type(Auctionator.API) == "table"
        and type(Auctionator.API.v1) == "table"
        and type(Auctionator.API.v1.GetAuctionPriceByItemID) == "function"
end

local function GetAuctionatorPrice(itemID, petLink)
    if not AuctionatorAvailable() then return nil end
    local api = Auctionator.API.v1
    local price
    if petLink and api.GetAuctionPriceByItemLink then
        local ok, p = pcall(api.GetAuctionPriceByItemLink, AUC_CALLER, petLink)
        if ok and tonumber(p) and p > 0 then return p end
    end
    local sp = GetSpeciesID(itemID)
    if sp and api.GetAuctionPriceByItemLink then
        local link = string.format("|cff0070dd|Hbattlepet:%d:1:3:0:0:0:0000000000000000|h[Pet]|h|r", sp)
        local ok, p = pcall(api.GetAuctionPriceByItemLink, AUC_CALLER, link)
        if ok and tonumber(p) and p > 0 then price = p end
    end
    if not price then
        local ok, p = pcall(api.GetAuctionPriceByItemID, AUC_CALLER, itemID)
        if ok and tonumber(p) and p > 0 then price = p end
    end
    return price
end

local function GetGainPrices(itemID, caged)
    local links = caged and cagedLinks[itemID]
    if links and #links > 0 then
        local sm, sr, sa, nm, nr, na = 0, 0, 0, 0, 0, 0
        for _, link in ipairs(links) do
            local m, r = GetPrices(itemID, link)
            local a = GetAuctionatorPrice(itemID, link)
            if m then sm = sm + m; nm = nm + 1 end
            if r then sr = sr + r; nr = nr + 1 end
            if a then sa = sa + a; na = na + 1 end
        end
        return nm > 0 and sm / nm or nil, nr > 0 and sr / nr or nil, na > 0 and sa / na or nil
    end
    local m, r = GetPrices(itemID)
    return m, r, GetAuctionatorPrice(itemID)
end

local function GetLivePrices(itemID)
    local links = cagedLinks[itemID]
    return GetGainPrices(itemID, links ~= nil and #links > 0)
end

-------------------------------------------------------------------------------
-- Database
-------------------------------------------------------------------------------
local function InitDB()
    FarmLedgerDB = FarmLedgerDB or {}
    db = FarmLedgerDB
    db.days = db.days or {}       
    db.held = db.held or {}       
    db.chars = db.chars or {}     -- per-character class / ICC quest progress / shards / Lich King lockout
    db.settings = db.settings or {}
    local s = db.settings
    if s.allChars == nil then s.allChars = true end
    if s.hideEmpty == nil then s.hideEmpty = false end
    s.period = s.period or "day"
    s.tab = s.tab or "general"
    s.expansion = s.expansion or "all"
    if s.tipPrices == nil then s.tipPrices = true end
    s.priceMode = s.priceMode or "server"      
    s.priceSource = s.priceSource or "oe"      
    s.lang = s.lang or "en"
    s.theme = s.theme or "midnight"
    s.minimapAngle = s.minimapAngle or 215
    s.width = s.width or 460
    s.height = s.height or 620
    if not s.widened then s.widened = true; s.width = math.max(s.width, 800) end   -- room for the side columns

    local cutoff = date("%Y-%m-%d", time() - 400 * 86400)
    for k in pairs(db.days) do
        if k < cutoff then db.days[k] = nil end
    end
end

local function RecordGain(dayKey, itemID, delta, caged)
    local server, region, auc = GetGainPrices(itemID, caged)
    local day = db.days[dayKey]
    if not day then day = {}; db.days[dayKey] = day end
    local ch = day[charKey]
    if not ch then ch = {}; day[charKey] = ch end
    local e = ch[itemID]
    if not e then e = { n = 0, v = 0, r = 0, a = 0 }; ch[itemID] = e end
    if e.r == nil then                          
        local _, liveRegion = GetPrices(itemID)
        e.r = (liveRegion or 0) * e.n
    end
    if e.a == nil then e.a = (auc or 0) * e.n end
    e.n = e.n + delta
    e.v = e.v + (server or 0) * delta           
    e.r = e.r + (region or 0) * delta           
    e.a = e.a + (auc or 0) * delta              
end

-- Manual ±1 adjustment for today's gained count (works even if the item is not in bags).
local function AdjustGain(itemID, delta)
    if not db or not charKey or not itemID or delta == 0 then return end
    local dayKey = date("%Y-%m-%d")
    local day = db.days[dayKey]
    local ch = day and day[charKey]
    local e = ch and ch[itemID]
    local current = e and e.n or 0
    if delta < 0 and current + delta < 0 then
        delta = -current
    end
    if delta == 0 then return end
    local useCaged = (cagedCounts[itemID] or 0) > 0 or (cagedLinks[itemID] and #cagedLinks[itemID] > 0)
    RecordGain(dayKey, itemID, delta, useCaged)
    RequestRefresh()
end

-------------------------------------------------------------------------------
-- Per-character tracking (Icecrown Citadel questline)
-------------------------------------------------------------------------------
local function QuestState(id)     -- 2 = completed, 1 = in quest log, 0 = not started
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(id) then return 2 end
    if C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(id) then return 1 end
    return 0
end

local function OwnedCount(id)          -- bags + bank + reagent bank
    if C_Item and C_Item.GetItemCount then
        return C_Item.GetItemCount(id, true, false, true, false) or 0
    end
    return GetItemCount(id, true) or 0
end

local function ShardCount() return OwnedCount(SHARD_ITEM) end

local function UpdateCharData()
    if not db or not charKey then return end
    local rec = db.chars[charKey]
    if not rec then rec = {}; db.chars[charKey] = rec end
    local _, token = UnitClass("player")
    rec.class = token
    rec.female = (UnitSex("player") == 3)
    rec.name = UnitName("player")
    rec.realm = GetNormalizedRealmName() or GetRealmName()
    rec.zg = rec.zg or {}
    for _, e in ipairs(ZG_EXCHANGE) do rec.zg[e[1]] = OwnedCount(e[1]) end
    if token and ICC_CLASS_SET[token] then
        rec.quests = rec.quests or {}
        for _, id in ipairs(ICC_QUESTS) do
            -- a completed quest never becomes "not completed" again (guards against flags not loaded yet at login)
            if rec.quests[id] ~= 2 then rec.quests[id] = QuestState(id) end
        end
        rec.shards = ShardCount()
    end
end

-- Lich King lockout (only valid after the UPDATE_INSTANCE_INFO event)
local function UpdateLockout()
    if not db or not charKey or not GetNumSavedInstances then return end
    local rec = db.chars[charKey]
    if not rec or not rec.class or not ICC_CLASS_SET[rec.class] then return end
    local killed, expires = false, nil
    for i = 1, GetNumSavedInstances() do
        local _, _, reset, _, locked, extended, _, isRaid, _, _, numEncounters, _, _, instanceID = GetSavedInstanceInfo(i)
        if isRaid and instanceID == ICC_INSTANCE_ID and (locked or extended) and numEncounters and numEncounters > 0 then
            local _, _, isKilled = GetSavedInstanceEncounterInfo(i, numEncounters)   -- The Lich King is the last encounter
            if isKilled then
                killed = true
                expires = time() + (reset or 0)
            end
        end
    end
    rec.lkKilled, rec.lkExpires, rec.lkChecked = killed, expires, time()
end

local function LastWeeklyReset()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local secs = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if secs then return time() + secs - 7 * 86400 end
    end
    return 0
end

-- true = killed this week, false = not killed this week, nil = unknown (not checked since the last reset)
local function LKStatus(rec)
    if rec.lkKilled and rec.lkExpires and rec.lkExpires > time() then return true end
    if rec.lkChecked and rec.lkChecked >= LastWeeklyReset() then return false end
    return nil
end

local charUpdatePending = false
local function ScheduleCharUpdate()
    if charUpdatePending then return end
    charUpdatePending = true
    C_Timer.After(1, function()
        charUpdatePending = false
        UpdateCharData()
        if RequestRefresh then RequestRefresh() end
    end)
end

-------------------------------------------------------------------------------
-- Bag scanning
-------------------------------------------------------------------------------
local function Scan()
    if not db or not charKey then return end
    local suppressed = GetTime() < suppressUntil or next(openInteractions) ~= nil
    local dayKey = date("%Y-%m-%d")
    local held = db.held[charKey]
    if not held then held = {}; db.held[charKey] = held end

    cagedCounts = ScanCagedPets()
    local journalOpen = CollectionsJournal and CollectionsJournal:IsShown()

    local changed = false
    for _, it in ipairs(ITEMS) do
        local id = it[1]
        local loose = CountInBags(id)
        local caged = cagedCounts[id] or 0
        local oldLoose, oldCaged = baseline[id], baselineCaged[id]
        if oldLoose ~= nil and loose > oldLoose and not suppressed then
            RecordGain(dayKey, id, loose - oldLoose, false)
            changed = true
        end
        if oldCaged ~= nil and caged > oldCaged and not suppressed and not journalOpen then
            RecordGain(dayKey, id, caged - oldCaged, true)
            changed = true
        end
        baseline[id] = loose
        baselineCaged[id] = caged
        held[id] = loose + caged
    end
    UpdateCharData()
    if changed or main then RequestRefresh() end
end

-------------------------------------------------------------------------------
-- Aggregation
-------------------------------------------------------------------------------
local function GetPeriodBounds()
    local now = time()
    local t = date("*t", now)
    local sinceMonday = (t.wday + 5) % 7        
    local monday = time({ year = t.year, month = t.month, day = t.day - sinceMonday, hour = 12 })
    local friday = time({ year = t.year, month = t.month, day = t.day - sinceMonday + 4, hour = 12 })
    return date("%Y-%m-%d", now), date("%Y-%m-%d", monday), date("%Y-%m-%d", friday), date("%Y-%m", now)
end

local function ComputeTotals()
    local today, weekStart, weekEnd, monthPrefix = GetPeriodBounds()
    local agg = { day = {}, week = {}, month = {} }
    local tot = { day = { n = 0, v = 0 }, week = { n = 0, v = 0 }, month = { n = 0, v = 0 } }
    local allChars = db.settings.allChars
    local source = db.settings.priceSource
    local regionMode = source == "oe" and db.settings.priceMode == "region"
    local live = {}                              

    local function add(period, id, e)
        local val = 0
        if source ~= "none" then
            if source == "auctionator" then val = e.a else val = regionMode and e.r or e.v end
            if not val or val <= 0 then
                local p = live[id]
                if not p then
                    p = {}
                    p.m, p.r, p.a = GetLivePrices(id)
                    live[id] = p
                end
                local unit
                if source == "auctionator" then unit = p.a else unit = regionMode and p.r or p.m end
                val = unit and unit * e.n or 0
            end
        end
        local a = agg[period][id]
        if not a then a = { n = 0, v = 0 }; agg[period][id] = a end
        a.n = a.n + e.n
        a.v = a.v + val
        tot[period].n = tot[period].n + e.n
        tot[period].v = tot[period].v + val
    end

    for dayKey, chars in pairs(db.days) do
        local inDay = dayKey == today
        local inWeek = dayKey >= weekStart and dayKey <= weekEnd
        local inMonth = dayKey:sub(1, 7) == monthPrefix
        if inDay or inWeek or inMonth then
            for ck, items in pairs(chars) do
                if allChars or ck == charKey then
                    for id, e in pairs(items) do
                        if inDay then add("day", id, e) end
                        if inWeek then add("week", id, e) end
                        if inMonth then add("month", id, e) end
                    end
                end
            end
        end
    end
    return agg, tot
end

local function GetHeld(itemID)
    local mine = CountInBags(itemID) + (cagedCounts[itemID] or 0)   
    if not db.settings.allChars then return mine end
    local total = mine
    for ck, h in pairs(db.held) do
        if ck ~= charKey then total = total + (h[itemID] or 0) end
    end
    return total
end

local function PriceModeText()
    local s = db.settings
    if s.priceSource == "auctionator" then return T("srcAuc") end
    if s.priceSource == "none" then return T("priceOff") end
    return s.priceMode == "region" and T("regionPrice") or T("serverPrice")
end

-------------------------------------------------------------------------------
-- Theme
-------------------------------------------------------------------------------
local function ComputeTheme()
    local s = db.settings
    local bg, accent, alpha
    alpha = 0.96
    if s.theme == "custom" and s.customColor then
        bg = { s.customColor[1], s.customColor[2], s.customColor[3] }
        alpha = s.customColor[4] or 0.96
        accent = s.customAccent or THEMES[1].accent
    else
        for _, t in ipairs(THEMES) do
            if t.key == s.theme then bg, accent = t.bg, t.accent end
        end
        if not bg then
            s.theme = "midnight"
            bg, accent = THEMES[1].bg, THEMES[1].accent
        end
    end
    C.bg = { bg[1], bg[2], bg[3], alpha }
    C.panel = Lift(bg, 0.04)
    C.border = Lift(bg, 0.12)
    C.accent = { accent[1], accent[2], accent[3] }
end

-------------------------------------------------------------------------------
-- UI helpers
-------------------------------------------------------------------------------
local function ApplyBackdrop(f, bg, border)
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(unpack(bg))
    f:SetBackdropBorderColor(unpack(border))
end

local function MakeText(parent, size, color, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size + FONT_BUMP, "")
    fs:SetTextColor(unpack(color))
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function SetActive(btn, active)
    btn.active = active
    btn:SetBackdropBorderColor(unpack(active and C.accent or C.border))
    btn.text:SetTextColor(unpack(active and C.accent or C.text))
end

local function MakeButton(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    ApplyBackdrop(b, C.panel, C.border)
    b.text = MakeText(b, 11, C.text, "CENTER")
    b.text:SetPoint("CENTER")
    b.text:SetText(text)
    b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(C.accent)) end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(self.active and C.accent or C.border))
    end)
    UI.buttons[#UI.buttons + 1] = b
    return b
end

-------------------------------------------------------------------------------
-- Main window
-------------------------------------------------------------------------------
local cards, rows = {}, {}
local area, content, scroll, scrollBar, emptyText, footerText, scopeBtn, hideBtn, priceBtn

local function GetActiveTab()
    local s = db.settings
    for _, t in ipairs(TABS) do
        if t.key == s.tab then return t end
    end
    return TABS[1]
end

-- The right column (expansions) only exists on the "General" tab
local function RightColumnWidth()
    return GetActiveTab().expansions and (RIGHT_W + SIDE_GAP) or 0
end

local function AreaWidth()
    return math.max(1, main:GetWidth() - PAD - LEFT_W - SIDE_GAP - PAD - RightColumnWidth())
end

local function AnchorArea()
    area:ClearAllPoints()
    area:SetPoint("TOPLEFT", main, "TOPLEFT", PAD + LEFT_W + SIDE_GAP, -AREA_Y)
    area:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -(PAD + RightColumnWidth()), 0)
end

local function UpdateScrollRange()
    if not scroll then return end
    local viewH = math.max(1, main:GetHeight() - TOP_OFFSET_SCROLL - BOTTOM_OFFSET_SCROLL)
    local maxScroll = math.max(0, content:GetHeight() - viewH)
    scrollBar:SetMinMaxValues(0, maxScroll)
    if maxScroll <= 0 then
        scrollBar:Hide()
        scroll:SetVerticalScroll(0)
    else
        scrollBar:Show()
        if scrollBar:GetValue() > maxScroll then scrollBar:SetValue(maxScroll) end
    end
end

local function Layout()
    if not main or not area then return end
    AnchorArea()
    local w = AreaWidth()
    local cw = (w - 2 * GAP) / 3
    for _, card in ipairs(cards) do card:SetWidth(cw) end
    content:SetWidth(math.max(1, w - 8))
    if UI.icc then UI.icc.content:SetWidth(math.max(1, w - 8)) end
    UpdateScrollRange()
    if UpdateICCScroll then UpdateICCScroll() end
end

local function CreateRow(i)
    local r = CreateFrame("Button", nil, content)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)      -- re-anchored in Refresh()
    r:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)

    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(0, 0, 0, 0)

    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.10)

    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(22, 22)
    r.icon:SetPoint("LEFT", 6, 0)
    r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    r.value = MakeText(r, 12, C.text, "RIGHT")
    r.value:SetPoint("RIGHT", -8, 0)
    r.value:SetWidth(100)

    -- ± adjust buttons (visible only on "Today")
    r.plusBtn = CreateFrame("Button", nil, r, "BackdropTemplate")
    r.plusBtn:SetSize(18, 18)
    r.plusBtn:SetPoint("RIGHT", r.value, "LEFT", -4, 0)
    ApplyBackdrop(r.plusBtn, C.panel, C.border)
    r.plusBtn.text = MakeText(r.plusBtn, 11, C.good, "CENTER")
    r.plusBtn.text:SetPoint("CENTER")
    r.plusBtn.text:SetText("+")
    r.plusBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(C.accent))
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(T("adjTip") or "Adjust today's gained count (±1)", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    r.plusBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(C.border))
        GameTooltip:Hide()
    end)
    r.plusBtn:SetScript("OnClick", function()
        if r.itemID and AdjustGain then AdjustGain(r.itemID, 1) end
    end)

    r.minusBtn = CreateFrame("Button", nil, r, "BackdropTemplate")
    r.minusBtn:SetSize(18, 18)
    r.minusBtn:SetPoint("RIGHT", r.plusBtn, "LEFT", -2, 0)
    ApplyBackdrop(r.minusBtn, C.panel, C.border)
    r.minusBtn.text = MakeText(r.minusBtn, 11, C.bad, "CENTER")
    r.minusBtn.text:SetPoint("CENTER")
    r.minusBtn.text:SetText("-")
    r.minusBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(C.accent))
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(T("adjTip") or "Adjust today's gained count (±1)", nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    r.minusBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(C.border))
        GameTooltip:Hide()
    end)
    r.minusBtn:SetScript("OnClick", function()
        if r.itemID and AdjustGain then AdjustGain(r.itemID, -1) end
    end)

    r.count = MakeText(r, 12, C.text, "RIGHT")
    r.count:SetPoint("RIGHT", r.minusBtn, "LEFT", -6, 0)
    r.count:SetWidth(70)

    r.name = MakeText(r, 12, C.text, "LEFT")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
    r.name:SetPoint("RIGHT", r.count, "LEFT", -8, 0)

    -- expansion header text (only used when this row is a group header)
    r.hdr = MakeText(r, 11, C.accent, "LEFT")
    r.hdr:SetPoint("LEFT", 8, 0)
    r.hdr:SetPoint("RIGHT", -8, 0)
    r.hdr:Hide()

    r:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(PeriodLabel(db.settings.period) .. " " .. T("gained"), tostring(self.gained or 0), 0.6, 0.6, 0.7, 1, 1, 1)
        GameTooltip:AddDoubleLine(T("value"), FormatGold(self.gainedValue or 0), 0.6, 0.6, 0.7, 1, 1, 1)
        if db.settings.tipPrices then       -- Settings > "Price lines in item tooltips"
            local m, rg, au = GetLivePrices(self.itemID)
            GameTooltip:AddDoubleLine(T("serverLine"), m and FormatGold(m) or T("noData"), 0.6, 0.6, 0.7, 1, 1, 1)
            GameTooltip:AddDoubleLine(T("regionLine"), rg and FormatGold(rg) or T("noData"), 0.6, 0.6, 0.7, 1, 1, 1)
            GameTooltip:AddDoubleLine(T("aucLine"), au and FormatGold(au) or T("noData"), 0.6, 0.6, 0.7, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

-- Zul'Gurub exchange block (sits at the top of the scrolling list) ------------
local ZG_TITLE_H, ZG_ROW_H, ZG_SUM_H = 24, 26, 40
local ZG_BLOCK_H = ZG_TITLE_H + #ZG_EXCHANGE * ZG_ROW_H + ZG_SUM_H + 22
local zg = { rows = {} }

-- Owned amount: this character, or every known character when "All characters" is on
local function ZGOwnedTotal(id)
    if not db.settings.allChars then return OwnedCount(id) end
    local total = 0
    for ck, rec in pairs(db.chars) do
        if ck == charKey then total = total + OwnedCount(id)
        elseif rec.zg then total = total + (rec.zg[id] or 0) end
    end
    if not db.chars[charKey] then total = total + OwnedCount(id) end
    return total
end

local function ItemTip(self)           -- OnEnter passes (self, motion): no extra args used
    if not self.itemID then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(self.itemID)
    GameTooltip:Show()
end

local function BuildZGBlock()
    local f = CreateFrame("Frame", nil, content)
    f:SetHeight(ZG_BLOCK_H)
    f:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    f:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
    f:Hide()
    zg.frame = f

    zg.title = MakeText(f, 10, C.accent, "LEFT")
    zg.title:SetPoint("TOPLEFT", 8, -8)
    zg.hYield = MakeText(f, 9, C.dim, "RIGHT")
    zg.hYield:SetPoint("TOPRIGHT", -8, -9)
    zg.hYield:SetWidth(60)
    zg.hOwned = MakeText(f, 9, C.dim, "RIGHT")
    zg.hOwned:SetPoint("RIGHT", zg.hYield, "LEFT", -8, 0)
    zg.hOwned:SetWidth(110)

    for i, e in ipairs(ZG_EXCHANGE) do
        local r = CreateFrame("Button", nil, f)
        r:SetHeight(ZG_ROW_H)
        local ry = -(ZG_TITLE_H + (i - 1) * ZG_ROW_H)
        r:SetPoint("TOPLEFT", f, "TOPLEFT", 0, ry)
        r:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, ry)
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.hl = r:CreateTexture(nil, "HIGHLIGHT")
        r.hl:SetAllPoints()
        r.hl:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.10)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(20, 20)
        r.icon:SetPoint("LEFT", 8, 0)
        r.icon:SetTexture(e[2])
        r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        r.yield = MakeText(r, 12, C.text, "RIGHT")
        r.yield:SetPoint("RIGHT", -8, 0)
        r.yield:SetWidth(60)
        r.owned = MakeText(r, 12, C.text, "RIGHT")
        r.owned:SetPoint("RIGHT", r.yield, "LEFT", -8, 0)
        r.owned:SetWidth(110)
        r.name = MakeText(r, 12, C.text, "LEFT")
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
        r.name:SetPoint("RIGHT", r.owned, "LEFT", -8, 0)
        r.itemID = e[1]
        r:SetScript("OnEnter", ItemTip)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        zg.rows[i] = r
    end

    local sumY = -(ZG_TITLE_H + #ZG_EXCHANGE * ZG_ROW_H + 8)
    local sum = CreateFrame("Button", nil, f)
    sum:SetHeight(ZG_SUM_H)
    sum:SetPoint("TOPLEFT", f, "TOPLEFT", 0, sumY)
    sum:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, sumY)
    sum.bg = sum:CreateTexture(nil, "BACKGROUND")
    sum.bg:SetAllPoints()
    sum.icon = sum:CreateTexture(nil, "ARTWORK")
    sum.icon:SetSize(30, 30)
    sum.icon:SetPoint("LEFT", 8, 0)
    sum.icon:SetTexture(ZG_REWARD[2])
    sum.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    sum.value = MakeText(sum, 20, C.good, "RIGHT")
    sum.value:SetPoint("RIGHT", -10, 0)
    sum.value:SetWidth(90)
    sum.name = MakeText(sum, 12, C.text, "LEFT")
    sum.name:SetPoint("LEFT", sum.icon, "RIGHT", 8, 7)
    sum.name:SetPoint("RIGHT", sum.value, "LEFT", -8, 0)
    sum.sub = MakeText(sum, 10, C.dim, "LEFT")
    sum.sub:SetPoint("LEFT", sum.icon, "RIGHT", 8, -8)
    sum.itemID = ZG_REWARD[1]
    sum:SetScript("OnEnter", ItemTip)
    sum:SetScript("OnLeave", function() GameTooltip:Hide() end)
    zg.sum = sum

    zg.line = f:CreateTexture(nil, "ARTWORK")
    zg.line:SetHeight(1)
    zg.line:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -(ZG_BLOCK_H - 8))
    zg.line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -(ZG_BLOCK_H - 8))
    zg.line:SetColorTexture(1, 1, 1, 0.12)
end

-- Returns true while item data is still loading
local function RefreshZGBlock()
    local missing = false
    zg.title:SetText(T("zgExchange"))
    zg.title:SetTextColor(unpack(C.accent))
    zg.hOwned:SetText(T("zgOwned"))
    zg.hYield:SetText(T("zgYieldCol"))

    local total = 0
    for i, e in ipairs(ZG_EXCHANGE) do
        local r = zg.rows[i]
        local have = ZGOwnedTotal(e[1])
        local per = math.floor(have / e[3])
        total = total + per

        local name, quality = GetItemNameQuality(e[1])
        if name then
            r.name:SetText(name)
            local qc = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
            if qc then r.name:SetTextColor(qc.r, qc.g, qc.b) else r.name:SetTextColor(unpack(C.text)) end
        else
            missing = true
            r.name:SetText("Item " .. e[1])
            r.name:SetTextColor(unpack(C.dim))
            if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(e[1]) end
        end
        r.owned:SetText(string.format("%d / %d", have, e[3]))
        r.owned:SetTextColor(unpack(per > 0 and C.text or C.dim))
        r.yield:SetText("= " .. per)
        r.yield:SetTextColor(unpack(per > 0 and C.good or C.dim))
        r.hl:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.10)
        if i % 2 == 0 then r.bg:SetColorTexture(1, 1, 1, 0.035) else r.bg:SetColorTexture(0, 0, 0, 0) end
    end

    local name, quality = GetItemNameQuality(ZG_REWARD[1])
    if name then
        zg.sum.name:SetText(name)
        local qc = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
        if qc then zg.sum.name:SetTextColor(qc.r, qc.g, qc.b) else zg.sum.name:SetTextColor(unpack(C.text)) end
    else
        missing = true
        zg.sum.name:SetText("Item " .. ZG_REWARD[1])
        zg.sum.name:SetTextColor(unpack(C.dim))
        if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(ZG_REWARD[1]) end
    end
    zg.sum.sub:SetText(T("zgPotential"))
    zg.sum.value:SetText(tostring(total))
    zg.sum.value:SetTextColor(unpack(total > 0 and C.good or C.dim))
    zg.sum.bg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.10)
    return missing
end

-- Icecrown Citadel tab -------------------------------------------------------
local function ClassRGB(token)
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    if c then return { c.r, c.g, c.b } end
    return C.text
end

local function ClassName(token, female)
    local tbl = (female and LOCALIZED_CLASS_NAMES_FEMALE) or LOCALIZED_CLASS_NAMES_MALE
    return (tbl and tbl[token]) or token or "?"
end

local function CharLabel(rec, ck)
    local name = rec.name or (ck and ck:match("^(.-)%-")) or "?"
    local home = GetNormalizedRealmName and GetNormalizedRealmName() or nil
    if rec.realm and home and rec.realm ~= home then return name .. "-" .. rec.realm end
    return name
end

local function ICCProgress(rec)
    local n = 0
    if rec.quests then
        for _, id in ipairs(ICC_QUESTS) do
            if rec.quests[id] == 2 then n = n + 1 end
        end
    end
    return n
end

local function ICCDone(rec)
    return rec.quests ~= nil and rec.quests[ICC_FINAL_QUEST] == 2
end

-- Price of one item from the selected source (Oribos Exchange server/region, or Auctionator)
local function ICCUnitPrice(itemID)
    local s = db.settings
    if s.priceSource == "auctionator" then
        return GetAuctionatorPrice(itemID)
    elseif s.priceSource == "oe" then
        local m, r = GetPrices(itemID)
        if s.priceMode == "region" then return r end
        return m
    end
    return nil
end

local function FitButton(b, minW)
    b:SetWidth(math.max(minW or 60, b.text:GetStringWidth() + 20))
end

-- One line of the character table (or its header): name | class | progress | shards | Lich King
local function BuildCharRow(parent, header)
    local r = CreateFrame("Button", nil, parent)
    r:SetHeight(header and 18 or 24)
    local size = header and 9 or 12
    local col = header and C.dim or C.text
    if header then
        r:EnableMouse(false)
    else
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.bg:SetColorTexture(0, 0, 0, 0)
        r.hl = r:CreateTexture(nil, "HIGHLIGHT")
        r.hl:SetAllPoints()
        r.hl:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.10)
    end

    r.lk = MakeText(r, size, col, "RIGHT")
    r.lk:SetPoint("RIGHT", -6, 0)
    r.lk:SetWidth(100)

    r.shText = MakeText(r, size, col, "RIGHT")
    r.shText:SetPoint("RIGHT", r.lk, "LEFT", -8, 0)
    r.shText:SetWidth(header and 58 or 42)
    local anchor = r.shText
    if not header then
        r.shIcon = r:CreateTexture(nil, "ARTWORK")
        r.shIcon:SetSize(14, 14)
        r.shIcon:SetTexture(SHARD_ICON)
        r.shIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        r.shIcon:SetPoint("RIGHT", r.shText, "LEFT", -2, 0)
        anchor = r.shIcon
    end

    r.prog = MakeText(r, size, col, "RIGHT")
    r.prog:SetPoint("RIGHT", anchor, "LEFT", -8, 0)
    r.prog:SetWidth(header and 70 or 44)

    r.class = MakeText(r, size, col, "LEFT")
    r.class:SetPoint("RIGHT", r.prog, "LEFT", -8, 0)
    r.class:SetWidth(96)

    r.name = MakeText(r, size, col, "LEFT")
    r.name:SetPoint("LEFT", 6, 0)
    r.name:SetPoint("RIGHT", r.class, "LEFT", -8, 0)
    return r
end

local function BuildICCPanel()
    local W = { it = {}, cls = {}, pend = {} }
    UI.icc = W

    local f = CreateFrame("Frame", nil, main)
    f:SetPoint("TOPLEFT", area, "TOPLEFT", 0, -ICC_Y)
    f:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -8, BOTTOM_OFFSET_SCROLL)
    f:Hide()
    W.frame = f

    local sf = CreateFrame("ScrollFrame", nil, f)
    sf:SetAllPoints()
    sf:EnableMouseWheel(true)
    local c = CreateFrame("Frame", nil, sf)
    c:SetSize(400, 1)
    sf:SetScrollChild(c)
    W.scroll, W.content = sf, c

    local bar = CreateFrame("Slider", nil, main)
    bar:SetOrientation("VERTICAL")
    bar:SetPoint("TOPRIGHT", area, "TOPRIGHT", 0, -ICC_Y)
    bar:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", 0, BOTTOM_OFFSET_SCROLL)
    bar:SetWidth(5)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(1, 1, 1, 0.05)
    W.thumb = bar:CreateTexture(nil, "OVERLAY")
    W.thumb:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.8)
    W.thumb:SetSize(5, 40)
    bar:SetThumbTexture(W.thumb)
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    bar:SetValue(0)
    bar:SetScript("OnValueChanged", function(_, v) sf:SetVerticalScroll(v) end)
    bar:Hide()
    sf:SetScript("OnMouseWheel", function(_, delta)
        bar:SetValue(bar:GetValue() - delta * ROW_H * 2)
    end)
    W.bar = bar

    local function fs(size, color, justify) return MakeText(c, size, color, justify) end

    -- rewards + prices (very top)
    W.iTitle = fs(10, C.accent, "LEFT")
    W.srcOE = MakeButton(c, "", 110, 20)
    W.srcAuc = MakeButton(c, "", 90, 20)
    W.modeBtn = MakeButton(c, "", 90, 20)
    W.srcOE:SetScript("OnClick", function() db.settings.priceSource = "oe"; Refresh() end)
    W.srcAuc:SetScript("OnClick", function() db.settings.priceSource = "auctionator"; Refresh() end)
    W.modeBtn:SetScript("OnClick", function()
        local s = db.settings
        s.priceMode = (s.priceMode == "region") and "server" or "region"
        Refresh()
    end)
    for i = 1, #ICC_ITEMS do
        local r = CreateFrame("Button", nil, c)
        r:SetHeight(28)
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.hl = r:CreateTexture(nil, "HIGHLIGHT")
        r.hl:SetAllPoints()
        r.hl:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.10)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(22, 22)
        r.icon:SetPoint("LEFT", 6, 0)
        r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        r.price = MakeText(r, 12, C.text, "RIGHT")
        r.price:SetPoint("RIGHT", -8, 0)
        r.price:SetWidth(120)
        r.name = MakeText(r, 12, C.text, "LEFT")
        r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
        r.name:SetPoint("RIGHT", r.price, "LEFT", -8, 0)
        r:SetScript("OnEnter", ItemTip)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r:Hide()
        W.it[i] = r
    end
    W.totalLine = c:CreateTexture(nil, "ARTWORK")
    W.totalLine:SetHeight(1)
    W.totalLine:SetColorTexture(1, 1, 1, 0.15)
    W.totalLabel = fs(12, C.text, "LEFT")
    W.totalValue = fs(14, C.good, "RIGHT")
    W.totalNote = fs(10, C.dim, "RIGHT")

    -- current character
    W.meName = fs(13, C.text, "LEFT")
    W.meLine = fs(12, C.text, "LEFT")
    W.msg = fs(16, C.bad, "CENTER")
    W.msg2 = fs(11, C.dim, "CENTER")
    for i = 1, #ICC_CLASSES do W.cls[i] = fs(13, C.text, "CENTER") end

    -- all characters that still need quest 24748
    W.pTitle = fs(10, C.accent, "LEFT")
    W.pNone = fs(11, C.dim, "LEFT")
    W.pHead = BuildCharRow(c, true)
    W.pHead:Hide()
end

UpdateICCScroll = function()
    local W = UI.icc
    if not W or not main then return end
    local shown = W.frame:IsShown()
    local viewH = math.max(1, main:GetHeight() - AREA_Y - ICC_Y - BOTTOM_OFFSET_SCROLL)
    local maxScroll = math.max(0, W.content:GetHeight() - viewH)
    W.bar:SetMinMaxValues(0, maxScroll)
    if not shown then
        W.bar:Hide()
    elseif maxScroll <= 0 then
        W.bar:Hide()
        W.scroll:SetVerticalScroll(0)
    else
        W.bar:Show()
        if W.bar:GetValue() > maxScroll then W.bar:SetValue(maxScroll) end
    end
end

-- Returns true while some item data is still loading (so Refresh can retry)
RefreshICC = function()
    local W = UI.icc
    if not W or not db then return false end
    UpdateCharData()
    local s = db.settings
    local c = W.content
    local rec = db.chars[charKey] or {}
    local eligible = rec.class ~= nil and ICC_CLASS_SET[rec.class] == true
    local done = eligible and ICCDone(rec)
    local missing = false

    local function place(w, y, l, r)
        w:ClearAllPoints()
        w:SetPoint("TOPLEFT", c, "TOPLEFT", l or 0, -y)
        w:SetPoint("TOPRIGHT", c, "TOPRIGHT", r or 0, -y)
    end

    for _, w in ipairs({ W.msg, W.msg2, W.meName, W.meLine, W.iTitle, W.srcOE, W.srcAuc, W.modeBtn,
                         W.totalLine, W.totalLabel, W.totalValue, W.totalNote, W.pTitle, W.pNone, W.pHead }) do
        w:Hide()
    end
    for _, w in ipairs(W.cls) do w:Hide() end
    for _, w in ipairs(W.it) do w:Hide() end
    for _, w in ipairs(W.pend) do w:Hide() end

    local y = 0

    -- 1. Rewards + prices, very top --------------------------------------------
    W.iTitle:SetText(T("iccItems"))
    W.iTitle:SetTextColor(unpack(C.accent))
    place(W.iTitle, y + 3); W.iTitle:Show()

    W.srcOE.text:SetText(T("srcOE")); FitButton(W.srcOE, 70)
    W.srcAuc.text:SetText(T("srcAuc")); FitButton(W.srcAuc, 70)
    SetActive(W.srcOE, s.priceSource == "oe")
    SetActive(W.srcAuc, s.priceSource == "auctionator")
    W.srcAuc:ClearAllPoints()
    W.srcAuc:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -y)
    W.srcOE:ClearAllPoints()
    W.srcOE:SetPoint("RIGHT", W.srcAuc, "LEFT", -6, 0)
    W.srcOE:Show(); W.srcAuc:Show()
    if s.priceSource == "oe" then
        W.modeBtn.text:SetText(s.priceMode == "region" and T("regionPrice") or T("serverPrice"))
        FitButton(W.modeBtn, 70)
        SetActive(W.modeBtn, true)
        W.modeBtn:ClearAllPoints()
        W.modeBtn:SetPoint("RIGHT", W.srcOE, "LEFT", -6, 0)
        W.modeBtn:Show()
    end
    y = y + 28

    local total, noPrice = 0, 0
    for i, it in ipairs(ICC_ITEMS) do
        local r = W.it[i]
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)
        r:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -y)
        r.itemID = it[1]
        r.icon:SetTexture(it[2])
        local name, quality = GetItemNameQuality(it[1])
        if name then
            r.name:SetText(name)
            local qc = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
            if qc then r.name:SetTextColor(qc.r, qc.g, qc.b) else r.name:SetTextColor(unpack(C.text)) end
        else
            missing = true
            r.name:SetText("Item " .. it[1])
            r.name:SetTextColor(unpack(C.dim))
            if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(it[1]) end
        end
        if s.priceSource == "none" then
            r.price:SetText("-"); r.price:SetTextColor(unpack(C.dim))
        else
            local price = ICCUnitPrice(it[1])
            if price and price > 0 then
                total = total + price
                r.price:SetText(FormatGold(price)); r.price:SetTextColor(unpack(C.good))
            else
                noPrice = noPrice + 1
                r.price:SetText(T("noPrice")); r.price:SetTextColor(unpack(C.bad))
            end
        end
        r.hl:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.10)
        if i % 2 == 0 then r.bg:SetColorTexture(1, 1, 1, 0.035) else r.bg:SetColorTexture(0, 0, 0, 0) end
        r:Show()
        y = y + 28
    end

    W.totalLine:ClearAllPoints()
    W.totalLine:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -(y + 2))
    W.totalLine:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, -(y + 2))
    W.totalLine:Show()
    W.totalLabel:SetText(T("iccTotal"))
    W.totalLabel:SetTextColor(unpack(C.text))
    place(W.totalLabel, y + 9, 8)
    W.totalLabel:Show()
    if s.priceSource == "none" then
        W.totalValue:SetText("-"); W.totalValue:SetTextColor(unpack(C.dim))
    else
        W.totalValue:SetText(FormatGold(total)); W.totalValue:SetTextColor(unpack(C.good))
    end
    place(W.totalValue, y + 8, 0, -8)
    W.totalValue:Show()
    y = y + 32
    if s.priceSource == "none" then
        W.totalNote:SetText(T("iccPickSource"))
        place(W.totalNote, y, 0, -8); W.totalNote:Show()
        y = y + 16
    elseif noPrice > 0 then
        W.totalNote:SetText(string.format(T("iccMissingPrices"), noPrice))
        place(W.totalNote, y, 0, -8); W.totalNote:Show()
        y = y + 16
    end
    y = y + 18

    -- 2. Current character -------------------------------------------------------
    W.meName:SetText(CharLabel(rec, charKey))
    W.meName:SetTextColor(unpack(ClassRGB(rec.class)))
    place(W.meName, y, 4); W.meName:Show()
    y = y + 22

    if not eligible then
        -- Not a Paladin / Warrior / Death Knight
        y = y + 6
        W.msg:SetText(T("iccInappropriate"))
        W.msg:SetTextColor(unpack(C.bad))
        place(W.msg, y); W.msg:Show()
        y = y + 30
        W.msg2:SetText(T("iccEligible"))
        W.msg2:SetTextColor(unpack(C.dim))
        place(W.msg2, y); W.msg2:Show()
        y = y + 24
        for i, token in ipairs(ICC_CLASSES) do
            local line = W.cls[i]
            line:SetText(ClassName(token))
            line:SetTextColor(unpack(ClassRGB(token)))
            place(line, y)
            line:Show()
            y = y + 20
        end
        y = y + 8

    elseif done then
        -- Quest 24748 already completed
        W.msg:SetText(T("iccAllObtained"))
        W.msg:SetTextColor(unpack(C.good))
        place(W.msg, y + 2); W.msg:Show()
        y = y + 34

    else
        -- "Progress 3/9.  [icon] Shadowfrost Shard 14/50.  The Lich King"
        local shardName = GetItemNameQuality(SHARD_ITEM)
        if not shardName then
            missing = true
            shardName = T("iccShardsFallback")
            if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(SHARD_ITEM) end
        end
        local lkCol = Hex(LKStatus(rec) == true and C.good or C.dim)
        W.meLine:SetText(string.format("%s.   |T%d:14:14|t %s %d/%d.   %s%s|r",
            string.format(T("iccProgress"), ICCProgress(rec), #ICC_QUESTS),
            SHARD_ICON, shardName, rec.shards or 0, SHARD_NEEDED, lkCol, T("lkName")))
        W.meLine:SetTextColor(unpack(C.text))
        place(W.meLine, y, 4); W.meLine:Show()
        y = y + 28
    end
    y = y + 10

    -- 3. All characters that have not completed quest 24748 ----------------------
    W.pTitle:SetText(T("iccPending"))
    W.pTitle:SetTextColor(unpack(C.accent))
    place(W.pTitle, y); W.pTitle:Show()
    y = y + 18

    local pend = {}
    for ck, r2 in pairs(db.chars) do
        if r2.class and ICC_CLASS_SET[r2.class] and not ICCDone(r2) then pend[#pend + 1] = ck end
    end
    if #pend == 0 then
        W.pNone:SetText(T("iccNonePending"))
        place(W.pNone, y + 2, 4); W.pNone:Show()
        y = y + 26
    else
        table.sort(pend, function(a, b)
            local pa, pb = ICCProgress(db.chars[a]), ICCProgress(db.chars[b])
            if pa ~= pb then return pa > pb end
            return (db.chars[a].name or a) < (db.chars[b].name or b)
        end)

        local h = W.pHead
        h.name:SetText(T("colChar")); h.class:SetText(T("colClass")); h.prog:SetText(T("colQuests"))
        h.shText:SetText(T("colShards")); h.lk:SetText(T("colLK"))
        for _, fsx in ipairs({ h.name, h.class, h.prog, h.shText, h.lk }) do fsx:SetTextColor(unpack(C.dim)) end
        place(h, y)
        h:Show()
        y = y + 20

        for i, ck in ipairs(pend) do
            local r = W.pend[i]
            if not r then
                r = BuildCharRow(c, false)
                W.pend[i] = r
            end
            local r2 = db.chars[ck]
            place(r, y)
            local col = ClassRGB(r2.class)
            r.name:SetText(CharLabel(r2, ck))
            r.name:SetTextColor(unpack(col))
            r.class:SetText(ClassName(r2.class, r2.female))
            r.class:SetTextColor(unpack(col))
            r.prog:SetText(string.format("%d/%d", ICCProgress(r2), #ICC_QUESTS))
            r.prog:SetTextColor(unpack(C.text))
            r.shText:SetText(string.format("%d/%d", r2.shards or 0, SHARD_NEEDED))
            r.shText:SetTextColor(unpack(C.text))
            r.hl:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.10)
            r.lk:SetText(T("lkName"))
            r.lk:SetTextColor(unpack(LKStatus(r2) == true and C.good or C.dim))
            if ck == charKey then
                r.bg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.12)
            elseif i % 2 == 0 then
                r.bg:SetColorTexture(1, 1, 1, 0.035)
            else
                r.bg:SetColorTexture(0, 0, 0, 0)
            end
            r:Show()
            y = y + 24
        end
    end

    c:SetHeight(math.max(1, y + 8))
    UpdateICCScroll()
    return missing
end

-- Settings panel -------------------------------------------------------------
local function OpenColorPicker()
    local s = db.settings
    if not (ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow) then return end
    local prevTheme, prevColor, prevAccent = s.theme, s.customColor, s.customAccent
    local cur = s.customColor or { C.bg[1], C.bg[2], C.bg[3], C.bg[4] }

    local function apply()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        local a = cur[4] or 0.96
        if ColorPickerFrame.GetColorAlpha then a = ColorPickerFrame:GetColorAlpha() end
        s.customColor = { r, g, b, math.max(0.35, a) }
        s.customAccent = prevAccent or { C.accent[1], C.accent[2], C.accent[3] }
        s.theme = "custom"
        ApplyTheme()
    end

    ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    ColorPickerFrame:SetupColorPickerAndShow({
        r = cur[1], g = cur[2], b = cur[3],
        opacity = cur[4] or 0.96, hasOpacity = true,
        swatchFunc = apply, opacityFunc = apply,
        cancelFunc = function()
            s.theme, s.customColor, s.customAccent = prevTheme, prevColor, prevAccent
            ApplyTheme()
        end,
    })
end

local function BuildSettingsPanel()
    local s = db.settings
    local p = CreateFrame("Frame", nil, main, "BackdropTemplate")
    p:SetPoint("TOPLEFT", main, "TOPLEFT", 0, -34)
    p:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", 0, 0)
    p:SetFrameLevel(main:GetFrameLevel() + 20)
    p:EnableMouse(true)
    ApplyBackdrop(p, { C.bg[1], C.bg[2], C.bg[3], 1 }, C.border)
    p:Hide()
    UI.settingsPanel = p

    UI.settingsTitle = MakeText(p, 15, C.text, "LEFT")
    UI.settingsTitle:SetPoint("TOPLEFT", PAD + 4, -16)

    -- Language
    UI.langLabel = MakeText(p, 11, C.dim, "LEFT")
    UI.langLabel:SetPoint("TOPLEFT", PAD + 4, -52)
    local prev
    for _, loc in ipairs(LOCALES) do
        local b = MakeButton(p, loc.name, 104, 28)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 8, 0) else b:SetPoint("TOPLEFT", PAD + 4, -72) end
        b:SetScript("OnClick", function()
            s.lang = loc.code
            ApplyLanguage()
        end)
        UI.langButtons[loc.code] = b
        prev = b
    end

    -- Price source
    UI.srcLabel = MakeText(p, 11, C.dim, "LEFT")
    UI.srcLabel:SetPoint("TOPLEFT", PAD + 4, -112)
    prev = nil
    for _, src in ipairs({ { "oe", "srcOE" }, { "auctionator", "srcAuc" }, { "none", "srcNone" } }) do
        local b = MakeButton(p, "", 112, 28)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 8, 0) else b:SetPoint("TOPLEFT", PAD + 4, -132) end
        b.src, b.labelKey = src[1], src[2]
        b:SetScript("OnClick", function(self)
            s.priceSource = self.src
            Refresh()                      
            RefreshSettings()
        end)
        UI.srcButtons[src[1]] = b
        prev = b
    end
    UI.srcStatus = MakeText(p, 10, C.dim, "LEFT")
    UI.srcStatus:SetPoint("TOPLEFT", PAD + 4, -166)

    -- Frame color
    UI.colorLabel = MakeText(p, 11, C.dim, "LEFT")
    UI.colorLabel:SetPoint("TOPLEFT", PAD + 4, -184)
    prev = nil
    for _, t in ipairs(THEMES) do
        local sw = CreateFrame("Button", nil, p, "BackdropTemplate")
        sw:SetSize(36, 36)
        ApplyBackdrop(sw, Lift(t.bg, 0.03), C.border)
        if prev then sw:SetPoint("LEFT", prev, "RIGHT", 8, 0) else sw:SetPoint("TOPLEFT", PAD + 4, -204) end
        local strip = sw:CreateTexture(nil, "OVERLAY")
        strip:SetColorTexture(t.accent[1], t.accent[2], t.accent[3], 1)
        strip:SetPoint("BOTTOMLEFT", 1, 1); strip:SetPoint("BOTTOMRIGHT", -1, 1); strip:SetHeight(6)
        sw.key = t.key
        sw:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(T("theme_" .. self.key))
            GameTooltip:Show()
        end)
        sw:SetScript("OnLeave", function() GameTooltip:Hide() end)
        sw:SetScript("OnClick", function(self)
            s.theme = self.key
            ApplyTheme()
        end)
        UI.swatches[t.key] = sw
        prev = sw
    end

    UI.customBtn = MakeButton(p, "", 160, 26)
    UI.customBtn:SetPoint("TOPLEFT", PAD + 4, -250)
    UI.customBtn:SetScript("OnClick", OpenColorPicker)

    -- Oribos Exchange / Auctionator already add their own lines to item tooltips,
    -- so the extra price lines this addon appends can be switched off.
    UI.tipBtn = MakeButton(p, "", 340, 28)
    UI.tipBtn:SetPoint("TOPLEFT", PAD + 4, -296)
    UI.tipBtn:SetScript("OnClick", function()
        s.tipPrices = not s.tipPrices
        RefreshSettings()
    end)

    UI.backBtn = MakeButton(p, "", 110, 26)
    UI.backBtn:SetPoint("BOTTOMLEFT", PAD + 4, 16)
    UI.backBtn:SetScript("OnClick", function() p:Hide() end)
end

function RefreshSettings()
    if not UI.settingsPanel then return end
    local s = db.settings
    UI.settingsTitle:SetText(T("settings"))
    UI.langLabel:SetText(T("language"))
    UI.colorLabel:SetText(T("frameColor"))
    UI.customBtn.text:SetText(T("customColor"))
    UI.backBtn.text:SetText(T("back"))
    UI.srcLabel:SetText(T("srcLabel"))
    for src, b in pairs(UI.srcButtons) do
        b.text:SetText(T(b.labelKey))
        SetActive(b, s.priceSource == src)
    end
    local function status(ok)
        return ok and ("|cff73d97f" .. T("srcDetected") .. "|r") or ("|cfff26666" .. T("srcMissing") .. "|r")
    end
    UI.srcStatus:SetText(string.format("Oribos Exchange: %s    Auctionator: %s",
        status(OEAvailable()), status(AuctionatorAvailable())))
    UI.settingsPanel:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 1)
    UI.settingsPanel:SetBackdropBorderColor(unpack(C.border))
    for code, b in pairs(UI.langButtons) do SetActive(b, s.lang == code) end
    for key, sw in pairs(UI.swatches) do
        sw:SetBackdropBorderColor(unpack(s.theme == key and WHITE_C or C.border))
    end
    SetActive(UI.customBtn, s.theme == "custom")
    UI.tipBtn.text:SetText(T("tipPrices") .. ": " .. (s.tipPrices and T("on") or T("off")))
    SetActive(UI.tipBtn, s.tipPrices)
end

-- Window ---------------------------------------------------------------------
local function BuildMainFrame()
    local s = db.settings

    main = CreateFrame("Frame", "FarmLedgerFrame", UIParent, "BackdropTemplate")
    main:SetSize(s.width, s.height)
    main:SetFrameStrata("HIGH")
    main:SetClampedToScreen(true)
    main:SetMovable(true)
    main:SetResizable(true)
    main:SetResizeBounds(680, 460, 1400, 1000)
    ApplyBackdrop(main, C.bg, C.border)
    if s.point then
        main:SetPoint(s.point[1], UIParent, s.point[2], s.point[3], s.point[4])
    else
        main:SetPoint("CENTER")
    end
    main:Hide()
    table.insert(UISpecialFrames, "FarmLedgerFrame")
    UI.main = main

    local function SaveGeometry()
        local p, _, rp, x, y = main:GetPoint()
        s.point = { p, rp, x, y }
        s.width, s.height = main:GetWidth(), main:GetHeight()
    end

    local header = CreateFrame("Frame", nil, main, "BackdropTemplate")
    header:SetPoint("TOPLEFT"); header:SetPoint("TOPRIGHT"); header:SetHeight(34)
    ApplyBackdrop(header, C.panel, C.border)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() main:StartMoving() end)
    header:SetScript("OnDragStop", function() main:StopMovingOrSizing(); SaveGeometry() end)
    UI.header = header

    UI.accentBar = header:CreateTexture(nil, "OVERLAY")
    UI.accentBar:SetColorTexture(unpack(C.accent))
    UI.accentBar:SetPoint("TOPLEFT", 1, -1); UI.accentBar:SetPoint("BOTTOMLEFT", 1, 1); UI.accentBar:SetWidth(3)

    UI.title = MakeText(header, 14, C.text, "LEFT")
    UI.title:SetPoint("LEFT", 14, 0)

    local close = MakeButton(header, "X", 24, 20)
    close:SetPoint("RIGHT", -8, 0)
    close:SetScript("OnClick", function() main:Hide() end)

    UI.settingsBtn = MakeButton(header, "", 100, 20)
    UI.settingsBtn:SetPoint("RIGHT", close, "LEFT", -6, 0)

    -- Content area (between the left tab column and the optional right column)
    area = CreateFrame("Frame", nil, main)
    area:SetPoint("TOPLEFT", main, "TOPLEFT", PAD + LEFT_W + SIDE_GAP, -AREA_Y)
    area:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -PAD, 0)

    -- Left column: tabs as toggle buttons
    UI.tabButtons = {}
    for i, t in ipairs(TABS) do
        local b = MakeButton(main, "", LEFT_W, 30)
        b:SetPoint("TOPLEFT", main, "TOPLEFT", PAD, -(AREA_Y + 8 + (i - 1) * 36))
        b.text:SetWidth(LEFT_W - 12)
        b.text:SetWordWrap(true)
        b.tab = t
        b:SetScript("OnClick", function(self)
            s.tab = self.tab.key
            Refresh()
        end)
        UI.tabButtons[i] = b
    end

    -- Right column: expansions (only visible on the "General" tab)
    UI.expBar = CreateFrame("Frame", nil, main)
    UI.expBar:SetPoint("TOPRIGHT", main, "TOPRIGHT", -PAD, -(AREA_Y + 8))
    UI.expBar:SetSize(RIGHT_W, 10)
    UI.expButtons = {}
    local expList = { { key = "all" } }
    for _, t in ipairs(TABS) do
        if t.expansions then
            for _, g in ipairs(t.groups) do expList[#expList + 1] = { key = g.name, group = g } end
        end
    end
    for i, e in ipairs(expList) do
        local b = MakeButton(UI.expBar, "", RIGHT_W, 26)
        b:SetPoint("TOPLEFT", UI.expBar, "TOPLEFT", 0, -((i - 1) * 30))
        b.text:SetWidth(RIGHT_W - 12)
        b.text:SetWordWrap(true)
        b.key, b.group = e.key, e.group
        b:SetScript("OnClick", function(self)
            s.expansion = self.key
            Refresh()
        end)
        UI.expButtons[i] = b
    end

    scopeBtn = MakeButton(main, "", 130, 24)
    scopeBtn:SetPoint("TOPLEFT", area, "TOPLEFT", 0, -SCOPE_Y)
    scopeBtn:SetScript("OnClick", function()
        s.allChars = not s.allChars
        Refresh()
    end)

    hideBtn = MakeButton(main, "", 106, 24)
    hideBtn:SetPoint("LEFT", scopeBtn, "RIGHT", 6, 0)
    hideBtn:SetScript("OnClick", function()
        s.hideEmpty = not s.hideEmpty
        Refresh()
    end)

    priceBtn = MakeButton(main, "", 106, 24)
    priceBtn:SetPoint("LEFT", hideBtn, "RIGHT", 6, 0)
    priceBtn:SetScript("OnClick", function()
        if s.priceSource ~= "oe" then return end    
        s.priceMode = (s.priceMode == "region") and "server" or "region"
        Refresh()                                   
    end)
    priceBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(C.accent))
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(T("priceTipTitle"), C.accent[1], C.accent[2], C.accent[3])
        GameTooltip:AddLine(T("priceTipServer"), 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(T("priceTipRegion"), 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(T("priceTipNote"), 0.5, 0.5, 0.55, true)
        if s.priceSource ~= "oe" then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(T("priceTipSource"), 0.95, 0.75, 0.4, true)
        end
        GameTooltip:Show()
    end)
    priceBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    for i, p in ipairs(PERIODS) do
        local card = CreateFrame("Button", nil, main, "BackdropTemplate")
        card:SetHeight(62)
        ApplyBackdrop(card, C.panel, C.border)
        if i == 1 then
            card:SetPoint("TOPLEFT", area, "TOPLEFT", 0, -CARD_Y)
        else
            card:SetPoint("TOPLEFT", cards[i - 1], "TOPRIGHT", GAP, 0)
        end
        card.key = p.key
        card.bar = card:CreateTexture(nil, "OVERLAY")
        card.bar:SetColorTexture(unpack(C.accent))
        card.bar:SetPoint("TOPLEFT", 1, -1); card.bar:SetPoint("TOPRIGHT", -1, -1); card.bar:SetHeight(2)
        card.bar:Hide()

        card.label = MakeText(card, 10, C.dim, "LEFT")
        card.label:SetPoint("TOPLEFT", 10, -9)
        card.label:SetPoint("TOPRIGHT", -6, -9)

        card.value = MakeText(card, 17, C.text, "LEFT")
        card.value:SetPoint("LEFT", 10, -2)

        card.sub = MakeText(card, 10, C.dim, "LEFT")
        card.sub:SetPoint("BOTTOMLEFT", 10, 7)

        card:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(C.accent)) end)
        card:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(unpack(s.period == self.key and C.accent or C.border))
        end)
        card:SetScript("OnClick", function(self)
            s.period = self.key
            Refresh()
        end)
        cards[i] = card
    end

    local colHeader = CreateFrame("Frame", nil, main)
    colHeader:SetPoint("TOPLEFT", area, "TOPLEFT", 0, -COLHEAD_Y)
    colHeader:SetPoint("TOPRIGHT", area, "TOPRIGHT", -8, -COLHEAD_Y)
    colHeader:SetHeight(18)
    UI.colHeader = colHeader
    UI.hVal = MakeText(colHeader, 9, C.dim, "RIGHT")
    UI.hVal:SetPoint("RIGHT", -8, 0); UI.hVal:SetWidth(100)
    UI.hCnt = MakeText(colHeader, 9, C.dim, "RIGHT")
    UI.hCnt:SetPoint("RIGHT", UI.hVal, "LEFT", -8, 0); UI.hCnt:SetWidth(120)
    UI.hName = MakeText(colHeader, 9, C.dim, "LEFT")
    UI.hName:SetPoint("LEFT", 36, 0)

    scroll = CreateFrame("ScrollFrame", nil, main)
    scroll:SetPoint("TOPLEFT", area, "TOPLEFT", 0, -SCROLL_Y)
    scroll:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -8, BOTTOM_OFFSET_SCROLL)
    scroll:EnableMouseWheel(true)

    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(400, 1)
    scroll:SetScrollChild(content)

    scrollBar = CreateFrame("Slider", nil, main)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetPoint("TOPRIGHT", area, "TOPRIGHT", 0, -SCROLL_Y)
    scrollBar:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", 0, BOTTOM_OFFSET_SCROLL)
    scrollBar:SetWidth(5)
    local track = scrollBar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints(); track:SetColorTexture(1, 1, 1, 0.05)
    UI.thumb = scrollBar:CreateTexture(nil, "OVERLAY")
    UI.thumb:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.8)
    UI.thumb:SetSize(5, 40)
    scrollBar:SetThumbTexture(UI.thumb)
    scrollBar:SetMinMaxValues(0, 0)
    scrollBar:SetValueStep(1)
    scrollBar:SetValue(0)
    scrollBar:SetScript("OnValueChanged", function(_, v) scroll:SetVerticalScroll(v) end)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        scrollBar:SetValue(scrollBar:GetValue() - delta * ROW_H * 2)
    end)

    emptyText = MakeText(scroll, 12, C.dim, "CENTER")
    emptyText:SetPoint("TOP", scroll, "TOP", 0, -30)
    emptyText:Hide()

    for i = 1, MAX_LIST_ROWS do rows[i] = CreateRow(i) end
    BuildZGBlock()

    footerText = MakeText(main, 10, C.dim, "LEFT")
    footerText:SetPoint("BOTTOMLEFT", PAD + LEFT_W + SIDE_GAP, 8)
    footerText:SetPoint("BOTTOMRIGHT", -26, 8)

    local grip = CreateFrame("Button", nil, main)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    grip:SetFrameLevel(main:GetFrameLevel() + 40)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() main:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() main:StopMovingOrSizing(); SaveGeometry(); Layout() end)

    BuildICCPanel()
    BuildSettingsPanel()
    UI.settingsBtn:SetScript("OnClick", function()
        local p = UI.settingsPanel
        if p:IsShown() then p:Hide() else RefreshSettings(); p:Show() end
    end)

    main:SetScript("OnSizeChanged", Layout)
    main:SetScript("OnShow", function() Layout(); Refresh() end)
    main:SetScript("OnHide", function() UI.settingsPanel:Hide() end)
    Layout()
end

-------------------------------------------------------------------------------
-- Language / theme application
-------------------------------------------------------------------------------
function ApplyLanguage()
    if not main then return end
    UI.settingsBtn.text:SetText(T("settings"))
    for i, p in ipairs(PERIODS) do
        local txt = T(p.card)
        if p.sub then txt = txt .. "  |cff6b6e7a" .. T("weekSub") .. "|r" end
        cards[i].label:SetText(txt)
    end
    UI.hName:SetText(T("colItem"))
    UI.hCnt:SetText(T("colHeld"))
    UI.hVal:SetText(T("colValue"))
    emptyText:SetText(T("empty"))
    RefreshSettings()
    Refresh()
end

function ApplyTheme()
    ComputeTheme()
    if not main then return end
    main:SetBackdropColor(unpack(C.bg))
    main:SetBackdropBorderColor(unpack(C.border))
    UI.header:SetBackdropColor(unpack(C.panel))
    UI.header:SetBackdropBorderColor(unpack(C.border))
    UI.accentBar:SetColorTexture(unpack(C.accent))
    UI.title:SetText(Hex(C.accent) .. "Farm|r Ledger")
    UI.thumb:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.8)
    if UI.icc then UI.icc.thumb:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.8) end
    for _, b in ipairs(UI.buttons) do
        b:SetBackdropColor(unpack(C.panel))
        b:SetBackdropBorderColor(unpack(b.active and C.accent or C.border))
    end
    for _, card in ipairs(cards) do
        card:SetBackdropColor(unpack(C.panel))
        card.bar:SetColorTexture(unpack(C.accent))
    end
    for _, r in ipairs(rows) do
        r.hl:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.10)
        r.hdr:SetTextColor(unpack(C.accent))
    end
    RefreshSettings()   
    Refresh()           
end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------
local function UpdateTabs()
    local tab = GetActiveTab()
    for _, b in ipairs(UI.tabButtons) do
        b.text:SetText(T("tab_" .. b.tab.key))
        SetActive(b, b.tab == tab)
    end
    UI.expBar:SetShown(tab.expansions == true)
    if tab.expansions then
        local sel = db.settings.expansion
        for _, b in ipairs(UI.expButtons) do
            b.text:SetText(b.group and b.group.name or T("expAll"))
            SetActive(b, b.key == sel)
            b:SetAlpha((b.group and #b.group.items == 0) and 0.55 or 1)   -- empty placeholder groups look dimmer
        end
    end
end

-- Switch between the item-list widgets and the Icecrown Citadel panel
local function SetMode(mode)
    local icc = (mode == "icc")
    for _, card in ipairs(cards) do card:SetShown(not icc) end
    scopeBtn:SetShown(not icc)
    hideBtn:SetShown(not icc)
    priceBtn:SetShown(not icc)
    UI.colHeader:SetShown(not icc)
    scroll:SetShown(not icc)
    if icc then scrollBar:Hide() end
    if UI.icc then
        UI.icc.frame:SetShown(icc)
        if not icc then UI.icc.bar:Hide() end
    end
end

function Refresh()
    if not main or not db then return end
    local s = db.settings
    local tab = GetActiveTab()
    UpdateTabs()
    Layout()                    -- the right column appears / disappears with the tab

    local green, red = "|cff73d97f", "|cfff26666"
    local function UpdateFooter(label)
        if s.priceSource == "oe" then
            footerText:SetText(string.format("%s  |  %s: %s", label, PriceModeText(),
                OEAvailable() and (green .. "Oribos Exchange|r") or (red .. T("noOE") .. "|r")))
        elseif s.priceSource == "auctionator" then
            footerText:SetText(string.format("%s  |  %s: %s", label, T("srcLabel"),
                AuctionatorAvailable() and (green .. "Auctionator|r") or (red .. T("noAuc") .. "|r")))
        else
            footerText:SetText(string.format("%s  |  %s", label, T("priceOff")))
        end
    end

    -- Icecrown Citadel: custom panel -------------------------------------------
    if tab.kind == "icc" then
        SetMode("icc")
        local missing = RefreshICC()
        UpdateFooter(T("tab_icc"))
        if missing then
            C_Timer.After(1, function() if main:IsShown() then Refresh() end end)
        end
        return
    end

    -- Item list ----------------------------------------------------------------
    SetMode("list")
    cagedCounts = ScanCagedPets()
    local agg, tot = ComputeTotals()

    scopeBtn.text:SetText(s.allChars and T("allChars") or T("thisChar"))
    SetActive(scopeBtn, s.allChars)
    hideBtn.text:SetText(T("hideEmpty"))
    SetActive(hideBtn, s.hideEmpty)
    if s.priceSource == "oe" then
        priceBtn.text:SetText(s.priceMode == "region" and T("regionPrice") or T("serverPrice"))
        SetActive(priceBtn, true)
    else
        priceBtn.text:SetText(s.priceSource == "auctionator" and T("srcAuc") or T("srcNone"))
        SetActive(priceBtn, false)
    end
    for _, b in ipairs({ scopeBtn, hideBtn, priceBtn }) do b:SetBackdropColor(unpack(C.panel)) end

    for _, card in ipairs(cards) do
        local t = tot[card.key]
        card.value:SetText(FormatGold(t.v))
        card.sub:SetText(string.format(T("itemsCount"), t.n))
        local sel = s.period == card.key
        card.bar:SetShown(sel)
        card:SetBackdropBorderColor(unpack(sel and C.accent or C.border))
    end

    -- Which groups: all of them, or just the expansion picked in the right column
    local groups, single = tab.groups, false
    if tab.expansions and s.expansion ~= "all" then
        for _, g in ipairs(tab.groups) do
            if g.name == s.expansion then groups, single = { g }, true end
        end
    end

    -- Build the display list: [group header] + its items, group by group
    local period = s.period
    local display = {}
    for _, g in ipairs(groups) do
        local items = {}
        for idx, it in ipairs(g.items) do
            local e = agg[period][it[1]]
            local n = e and e.n or 0
            if n > 0 or not s.hideEmpty then
                items[#items + 1] = { idx = idx, id = it[1], icon = it[2], n = n, v = e and e.v or 0 }
            end
        end
        table.sort(items, function(a, b)
            if (a.n > 0) ~= (b.n > 0) then return a.n > 0 end
            if a.v ~= b.v then return a.v > b.v end
            return a.idx < b.idx
        end)
        -- placeholder groups (no items yet) stay visible unless "Hide empty" is on
        if g.name and (single or #items > 0 or (#g.items == 0 and not s.hideEmpty)) then
            display[#display + 1] = { header = true, name = g.name, empty = (#g.items == 0) }
        end
        for _, d in ipairs(items) do display[#display + 1] = d end
    end

    local missingInfo = false
    local y, itemNo = 0, 0

    -- Zul'Gurub: exchange block on top of the list
    if tab.exchange then
        zg.frame:Show()
        if RefreshZGBlock() then missingInfo = true end
        y = ZG_BLOCK_H
    else
        zg.frame:Hide()
    end

    for i, r in ipairs(rows) do
        local d = display[i]
        r:ClearAllPoints()
        if d then
            r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            r:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
            if d.header then
                r:SetHeight(HEADER_H)
                y = y + HEADER_H
                r.itemID = nil
                r:EnableMouse(false)
                r.bg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.12)
                r.icon:Hide(); r.name:Hide(); r.count:Hide(); r.value:Hide()
                r.plusBtn:Hide(); r.minusBtn:Hide()
                r.hdr:SetTextColor(unpack(C.accent))
                r.hdr:SetText(d.empty and (d.name .. "   " .. Hex(C.dim) .. T("noItemsYet") .. "|r") or d.name)
                r.hdr:Show()
            else
                r:SetHeight(ROW_H)
                y = y + ROW_H
                itemNo = itemNo + 1
                r:EnableMouse(true)
                r.hdr:Hide()
                r.icon:Show(); r.name:Show(); r.count:Show(); r.value:Show()
                if itemNo % 2 == 0 then r.bg:SetColorTexture(1, 1, 1, 0.035) else r.bg:SetColorTexture(0, 0, 0, 0) end

                r.itemID, r.gained, r.gainedValue = d.id, d.n, d.v
                r.icon:SetTexture(d.icon)
                r.icon:SetDesaturated(d.n == 0)

                local name, quality = GetItemNameQuality(d.id)
                if name then
                    r.name:SetText(name)
                    local qc = quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
                    if qc then r.name:SetTextColor(qc.r, qc.g, qc.b) else r.name:SetTextColor(unpack(C.text)) end
                else
                    missingInfo = true
                    r.name:SetText("Item " .. d.id)
                    r.name:SetTextColor(unpack(C.dim))
                    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(d.id) end
                end
                if d.n == 0 then r.name:SetAlpha(0.55) else r.name:SetAlpha(1) end

                local held = GetHeld(d.id)
                r.count:SetText(string.format("%d/%d", held, d.n))
                if d.n == 0 then
                    r.count:SetTextColor(unpack(C.dim))
                elseif held == 0 then
                    r.count:SetTextColor(unpack(C.warm))
                else
                    r.count:SetTextColor(unpack(C.text))
                end

                if d.n == 0 or s.priceSource == "none" then
                    r.value:SetText("-")
                    r.value:SetTextColor(unpack(C.dim))
                elseif d.v <= 0 then
                    r.value:SetText(T("noPrice"))
                    r.value:SetTextColor(unpack(C.bad))
                else
                    r.value:SetText(FormatGold(d.v))
                    r.value:SetTextColor(unpack(C.good))
                end

                local showAdj = (period == "day")
                if r.plusBtn then r.plusBtn:SetShown(showAdj) end
                if r.minusBtn then r.minusBtn:SetShown(showAdj) end
            end
            r:Show()
        else
            r.itemID = nil
            if r.plusBtn then r.plusBtn:Hide() end
            if r.minusBtn then r.minusBtn:Hide() end
            r:Hide()
        end
    end

    emptyText:SetShown(#display == 0 and not tab.exchange)
    content:SetHeight(math.max(1, y))
    UpdateScrollRange()

    UpdateFooter(PeriodLabel(period))

    if missingInfo then
        C_Timer.After(1, function() if main:IsShown() then Refresh() end end)
    end
end

local refreshPending = false
function RequestRefresh()
    if refreshPending or not main or not main:IsShown() then return end
    refreshPending = true
    C_Timer.After(0.15, function()
        refreshPending = false
        Refresh()
    end)
end

-------------------------------------------------------------------------------
-- Minimap button
-------------------------------------------------------------------------------
local function ToggleWindow()
    if not main then return end
    if main:IsShown() then main:Hide() else main:Show() end
end

local function BuildMinimapButton()
    local btn = CreateFrame("Button", "FarmLedgerMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    icon:SetSize(17, 17)
    icon:SetPoint("TOPLEFT", 7, -6)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(53, 53)
    border:SetPoint("TOPLEFT")

    local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
    local function UpdatePosition()
        local a = math.rad(db.settings.minimapAngle)
        local r = (Minimap:GetWidth() / 2) + 5
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
    end
    UpdatePosition()

    btn:RegisterForClicks("LeftButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        self.dragging = true
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            db.settings.minimapAngle = math.deg(atan2(cy - my, cx - mx))
            UpdatePosition()
        end)
    end)
    btn:SetScript("OnDragStop", function(self)
        self.dragging = false
        self:SetScript("OnUpdate", nil)
    end)
    btn:SetScript("OnClick", ToggleWindow)
    btn:SetScript("OnEnter", function(self)
        if self.dragging then return end
        local _, tot = ComputeTotals()
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Farm Ledger", C.accent[1], C.accent[2], C.accent[3])
        GameTooltip:AddDoubleLine(T("day"), FormatGold(tot.day.v), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine(T("week"), FormatGold(tot.week.v), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddDoubleLine(T("month"), FormatGold(tot.month.v), 0.8, 0.8, 0.8, 1, 1, 1)
        GameTooltip:AddLine(PriceModeText(), 0.5, 0.5, 0.55)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(T("mmHint"), 0.5, 0.5, 0.55)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-------------------------------------------------------------------------------
-- Events
-------------------------------------------------------------------------------
local function SetupInteractionFilter()
    local PIT = Enum and Enum.PlayerInteractionType
    if not PIT then return end
    for _, name in ipairs({
        "Banker", "GuildBanker", "MailInfo", "Merchant", "TradePartner",
        "Auctioneer", "VoidStorageBanker", "AccountBanker",
    }) do
        if PIT[name] then ignoredTypes[PIT[name]] = name end
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        InitDB()
        ComputeTheme()
        charKey = UnitName("player") .. "-" .. (GetNormalizedRealmName() or GetRealmName())
        UpdateCharData()
        SetupInteractionFilter()
        for _, it in ipairs(ITEMS) do
            if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(it[1]) end
        end
        if C_Item and C_Item.RequestLoadItemDataByID then
            C_Item.RequestLoadItemDataByID(SHARD_ITEM)
            for _, it in ipairs(ICC_ITEMS) do C_Item.RequestLoadItemDataByID(it[1]) end
            for _, e in ipairs(ZG_EXCHANGE) do C_Item.RequestLoadItemDataByID(e[1]) end
            C_Item.RequestLoadItemDataByID(ZG_REWARD[1])
        end
        BuildMainFrame()
        BuildMinimapButton()
        ApplyLanguage()
        ApplyTheme()

        if AuctionatorAvailable() and Auctionator.API.v1.RegisterForDBUpdate then
            pcall(Auctionator.API.v1.RegisterForDBUpdate, AUC_CALLER, function() RequestRefresh() end)
        end

        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("BAG_UPDATE_DELAYED")
        self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
        self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
        self:RegisterEvent("QUEST_LOG_UPDATE")
        self:RegisterEvent("QUEST_TURNED_IN")
        self:RegisterEvent("QUEST_DATA_LOAD_RESULT")
        self:RegisterEvent("UPDATE_INSTANCE_INFO")
        self:RegisterEvent("BOSS_KILL")

        C_Timer.NewTicker(60, function()
            if main and main:IsShown() then Refresh() end
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        suppressUntil = GetTime() + 3
        C_Timer.After(3.2, Scan)
        if RequestRaidInfo then RequestRaidInfo() end       -- Lich King lockout -> UPDATE_INSTANCE_INFO

    elseif event == "BAG_UPDATE_DELAYED" then
        Scan()

    elseif event == "GET_ITEM_INFO_RECEIVED" or event == "QUEST_DATA_LOAD_RESULT" then
        RequestRefresh()

    elseif event == "QUEST_LOG_UPDATE" or event == "QUEST_TURNED_IN" then
        ScheduleCharUpdate()

    elseif event == "UPDATE_INSTANCE_INFO" then
        UpdateLockout()
        RequestRefresh()

    elseif event == "BOSS_KILL" then
        C_Timer.After(2, function() if RequestRaidInfo then RequestRaidInfo() end end)

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        if ignoredTypes[arg1] then openInteractions[arg1] = true end

    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        if ignoredTypes[arg1] then
            suppressUntil = GetTime() + 1.5       
            openInteractions[arg1] = nil
            Scan()                                
        end
    end
end)

-------------------------------------------------------------------------------
-- Slash commands
-------------------------------------------------------------------------------
SLASH_FARMLEDGER1 = "/fl"
SLASH_FARMLEDGER2 = "/farmledger"
SlashCmdList["FARMLEDGER"] = function(msg)
    msg = strtrim(msg or ""):lower()
    if msg == "reset confirm" then
        wipe(db.days)
        print("|cff40b8f5Farm Ledger:|r " .. T("cleared"))
        Refresh()
    elseif msg:match("^price%s+%d+$") then
        local id = tonumber(msg:match("%d+"))
        print("|cff40b8f5Farm Ledger:|r price lookup for item " .. id)
        if not OEAvailable() then print("  Oribos Exchange not loaded.") end
        print("  speciesID: " .. tostring(GetSpeciesID(id)))
        for _, c in ipairs(PriceCandidates(id)) do
            local m, r = QueryOE(c[2])
            print(string.format("  %-18s -> server %s | region %s", c[1], tostring(m), tostring(r)))
        end
        print("  Auctionator: " .. tostring(AuctionatorAvailable() and GetAuctionatorPrice(id) or "n/a"))
    elseif msg == "pets" then
        print("|cff40b8f5Farm Ledger:|r caged pets in bags")
        local found = false
        ForEachCaged(function(link, stack, species)
            found = true
            local info = {}
            local ok = OEAvailable() and pcall(OEMarketInfo, link, info)
            print(string.format("  %s x%d  species %s  tracked item %s", link, stack, tostring(species),
                tostring(species and SPECIES_TO_ITEM[species])))
            print(string.format("    Oribos: server %s | region %s | breed %s | quality %s",
                tostring(info.market), tostring(info.region), tostring(info.breed), tostring(info.quality)))
            print("    Auctionator: " .. tostring(AuctionatorAvailable() and GetAuctionatorPrice(PET_CAGE_ITEM, link) or "n/a"))
        end)
        if not found then print("  none found (item 82800 with a battlepet link)") end
    elseif msg == "reset" then
        print("|cff40b8f5Farm Ledger:|r " .. T("resetHint"))
    else
        ToggleWindow()
    end
end