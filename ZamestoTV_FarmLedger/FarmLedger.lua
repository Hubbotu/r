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
-- Tracked items: { itemID, iconFileID }
-------------------------------------------------------------------------------
local ITEMS = {
    { 67151, 433440 },   { 52496, 134941 },   { 52494, 134941 },   { 52495, 134941 },
    { 67541, 134941 },   { 71965, 134941 },   { 69843, 376833 },   { 92426, 666474 },
    { 181267, 3386335 }, { 181265, 3860399 }, { 181266, 3860398 }, { 181172, 2027855 },
    { 108631, 879998 },  { 108633, 1035038 }, { 108634, 1035047 }, { 180869, 656319 },
    { 205463, 1032477 }, { 205419, 133841 },  { 119431, 136221 },  { 128315, 237560 },
    { 128314, 236313 },  { 128671, 1245298 }, { 207702, 4622301 }, { 22682, 134422 },
    { 206604, 133124 },  { 206605, 135042 },  { 206606, 132627 },  { 206607, 132614 },
    { 206608, 132965 },  { 206609, 132524 },  { 206610, 134693 },  { 206611, 132548 },
    { 1604, 135323 },
}

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
local TOP_OFFSET_SCROLL = 164
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
    db.settings = db.settings or {}
    local s = db.settings
    if s.allChars == nil then s.allChars = true end
    if s.hideEmpty == nil then s.hideEmpty = false end
    s.period = s.period or "day"
    s.priceMode = s.priceMode or "server"      
    s.priceSource = s.priceSource or "oe"      
    s.lang = s.lang or "en"
    s.theme = s.theme or "midnight"
    s.minimapAngle = s.minimapAngle or 215
    s.width = s.width or 460
    s.height = s.height or 540

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
local content, scroll, scrollBar, emptyText, footerText, scopeBtn, hideBtn, priceBtn

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
    if not main then return end
    local w = main:GetWidth() - 2 * PAD
    local cw = (w - 2 * GAP) / 3
    for _, card in ipairs(cards) do card:SetWidth(cw) end
    content:SetWidth(math.max(1, w - 8))
    UpdateScrollRange()
end

local function CreateRow(i)
    local r = CreateFrame("Button", nil, content)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * ROW_H)
    r:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -(i - 1) * ROW_H)

    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    if i % 2 == 0 then r.bg:SetColorTexture(1, 1, 1, 0.035) else r.bg:SetColorTexture(0, 0, 0, 0) end

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

    r:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(self.itemID)
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(PeriodLabel(db.settings.period) .. " " .. T("gained"), tostring(self.gained or 0), 0.6, 0.6, 0.7, 1, 1, 1)
        GameTooltip:AddDoubleLine(T("value"), FormatGold(self.gainedValue or 0), 0.6, 0.6, 0.7, 1, 1, 1)
        local m, rg, au = GetLivePrices(self.itemID)
        GameTooltip:AddDoubleLine(T("serverLine"), m and FormatGold(m) or T("noData"), 0.6, 0.6, 0.7, 1, 1, 1)
        GameTooltip:AddDoubleLine(T("regionLine"), rg and FormatGold(rg) or T("noData"), 0.6, 0.6, 0.7, 1, 1, 1)
        GameTooltip:AddDoubleLine(T("aucLine"), au and FormatGold(au) or T("noData"), 0.6, 0.6, 0.7, 1, 1, 1)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
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
    main:SetResizeBounds(400, 360, 1000, 1000)
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

    scopeBtn = MakeButton(main, "", 130, 24)
    scopeBtn:SetPoint("TOPLEFT", PAD, -(34 + 8))
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
            card:SetPoint("TOPLEFT", main, "TOPLEFT", PAD, -74)
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
    colHeader:SetPoint("TOPLEFT", main, "TOPLEFT", PAD, -144)
    colHeader:SetPoint("TOPRIGHT", main, "TOPRIGHT", -PAD - 8, -144)
    colHeader:SetHeight(18)
    UI.hVal = MakeText(colHeader, 9, C.dim, "RIGHT")
    UI.hVal:SetPoint("RIGHT", -8, 0); UI.hVal:SetWidth(100)
    UI.hCnt = MakeText(colHeader, 9, C.dim, "RIGHT")
    UI.hCnt:SetPoint("RIGHT", UI.hVal, "LEFT", -8, 0); UI.hCnt:SetWidth(120)
    UI.hName = MakeText(colHeader, 9, C.dim, "LEFT")
    UI.hName:SetPoint("LEFT", 36, 0)

    scroll = CreateFrame("ScrollFrame", nil, main)
    scroll:SetPoint("TOPLEFT", main, "TOPLEFT", PAD, -TOP_OFFSET_SCROLL)
    scroll:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -PAD - 8, BOTTOM_OFFSET_SCROLL)
    scroll:EnableMouseWheel(true)

    content = CreateFrame("Frame", nil, scroll)
    content:SetSize(400, 1)
    scroll:SetScrollChild(content)

    scrollBar = CreateFrame("Slider", nil, main)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetPoint("TOPRIGHT", main, "TOPRIGHT", -PAD, -TOP_OFFSET_SCROLL)
    scrollBar:SetPoint("BOTTOMRIGHT", main, "BOTTOMRIGHT", -PAD, BOTTOM_OFFSET_SCROLL)
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

    for i = 1, #ITEMS do rows[i] = CreateRow(i) end

    footerText = MakeText(main, 10, C.dim, "LEFT")
    footerText:SetPoint("BOTTOMLEFT", PAD, 8)
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
    for _, b in ipairs(UI.buttons) do
        b:SetBackdropColor(unpack(C.panel))
        b:SetBackdropBorderColor(unpack(b.active and C.accent or C.border))
    end
    for _, card in ipairs(cards) do
        card:SetBackdropColor(unpack(C.panel))
        card.bar:SetColorTexture(unpack(C.accent))
    end
    for _, r in ipairs(rows) do r.hl:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.10) end
    RefreshSettings()   
    Refresh()           
end

-------------------------------------------------------------------------------
-- Refresh
-------------------------------------------------------------------------------
function Refresh()
    if not main or not db then return end
    local s = db.settings
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

    local period = s.period
    local list = {}
    for idx, it in ipairs(ITEMS) do
        local e = agg[period][it[1]]
        local n = e and e.n or 0
        if n > 0 or not s.hideEmpty then
            list[#list + 1] = { idx = idx, id = it[1], icon = it[2], n = n, v = e and e.v or 0 }
        end
    end
    table.sort(list, function(a, b)
        if (a.n > 0) ~= (b.n > 0) then return a.n > 0 end
        if a.v ~= b.v then return a.v > b.v end
        return a.idx < b.idx
    end)

    local missingInfo = false
    for i, r in ipairs(rows) do
        local d = list[i]
        if d then
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

            r:Show()
        else
            r.itemID = nil
            if r.plusBtn then r.plusBtn:Hide() end
            if r.minusBtn then r.minusBtn:Hide() end
            r:Hide()
        end
    end

    emptyText:SetShown(#list == 0)
    content:SetHeight(math.max(1, #list * ROW_H))
    UpdateScrollRange()

    local green, red = "|cff73d97f", "|cfff26666"
    if s.priceSource == "oe" then
        footerText:SetText(string.format("%s  |  %s: %s", PeriodLabel(period), PriceModeText(),
            OEAvailable() and (green .. "Oribos Exchange|r") or (red .. T("noOE") .. "|r")))
    elseif s.priceSource == "auctionator" then
        footerText:SetText(string.format("%s  |  %s: %s", PeriodLabel(period), T("srcLabel"),
            AuctionatorAvailable() and (green .. "Auctionator|r") or (red .. T("noAuc") .. "|r")))
    else
        footerText:SetText(string.format("%s  |  %s", PeriodLabel(period), T("priceOff")))
    end

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
        SetupInteractionFilter()
        for _, it in ipairs(ITEMS) do
            if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(it[1]) end
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

        C_Timer.NewTicker(60, function()
            if main and main:IsShown() then Refresh() end
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        suppressUntil = GetTime() + 3
        C_Timer.After(3.2, Scan)

    elseif event == "BAG_UPDATE_DELAYED" then
        Scan()

    elseif event == "GET_ITEM_INFO_RECEIVED" then
        RequestRefresh()

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