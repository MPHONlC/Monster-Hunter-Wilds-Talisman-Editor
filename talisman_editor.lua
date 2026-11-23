local re = re
local sdk = sdk
local imgui = imgui
local log = log
local string = string
local tostring = tostring
local tonumber = tonumber
local pairs = pairs
local ipairs = ipairs
local pcall = pcall
local table = table
local math = math
local os = os

local Core = require("_CatLib")
local Browser = require("_CatLib.equipbox_browser")

local mod = Core.NewMod("Talisman Editor")
mod.EnableCJKFont(18)

local TALISMAN_CATEGORY = 2
local SKILL_COUNT = 3
local SKILL_ID_SCAN_MAX = 999
local MAX_SKILL_LEVEL = 5
local MAX_SLOT_DIGIT = 3
local REFRESH_SECONDS = 2
local ORANGE = Core.ReverseRGB(0xffff8000)

local SlotFlagNames = {
    [0] = "Armor slots only",
    [1] = "Weapon slot + armor slots",
    [3] = "Weapon slot only",
}

local SlotDigitNames = {
    [0] = "None",
    [1] = "Level 1",
    [2] = "Level 2",
    [3] = "Level 3",
}

local BrowserState = Browser.NewState()

local function SafeBrowser(fn, ...)
    if not fn then
        return
    end
    local ok, err = pcall(fn, ...)
    if not ok then
        log.warn("[Talisman Editor] Browser helper failed: " .. tostring(err))
    end
end

local Get_SkillNameGuid = Core.TypeMethod("app.MessageUtil", "getHunterSkillName(app.HunterDef.Skill)")

local SkillNames = { [0] = "(None)" }
local SkillDataInited = false

local function ResolveSkillName(id)
    local ok, name = pcall(function()
        if Get_SkillNameGuid then
            return Core.GetLocalizedText(Get_SkillNameGuid:call(nil, id))
        end
        return nil
    end)
    if ok and name and Core.IsValidName(name) then
        return name
    end

    ok, name = pcall(Core.GetSkillName, id)
    if ok and name and Core.IsValidName(name) then
        return name
    end
    return nil
end

local function InitSkillNames()
    if SkillDataInited then
        return
    end
    SkillDataInited = true

    local seen = {}
    for id = 1, SKILL_ID_SCAN_MAX do
        local name = ResolveSkillName(id)

        if name and not seen[name] then
            seen[name] = true
            SkillNames[id] = name
        end
    end
end

local SkillFilter = ""
local FilteredSkillNames = SkillNames
local FilteredFor = nil

local function GetFilteredSkillNames()
    if FilteredFor == SkillFilter then
        return FilteredSkillNames
    end
    FilteredFor = SkillFilter

    if SkillFilter == "" then
        FilteredSkillNames = SkillNames
        return FilteredSkillNames
    end

    local needle = SkillFilter:lower()
    local result = { [0] = SkillNames[0] }
    for id, name in pairs(SkillNames) do
        if id ~= 0 and name:lower():find(needle, 1, true) then
            result[id] = name
        end
    end
    FilteredSkillNames = result
    return result
end

local function SkillNamesWithCurrent(currentId)
    local names = GetFilteredSkillNames()
    if names[currentId] then
        return names
    end

    local copy = {}
    for k, v in pairs(names) do
        copy[k] = v
    end
    copy[currentId] = SkillNames[currentId] or string.format("Unknown skill (%d)", currentId)
    return copy
end

local function SkillLabel(id)
    return SkillNames[id] or string.format("Unknown skill (%d)", id)
end

local function DecodeSkill(raw)
    raw = raw or 0
    return math.floor(raw / 1000), raw % 1000
end

local function EncodeSkill(level, id)
    if id == 0 then
        return 0
    end
    return level * 1000 + id
end

local function DecodeSlots(value)
    value = value or 0
    return {
        math.floor(value / 1000) % 10,
        math.floor(value / 100) % 10,
        math.floor(value / 10) % 10,
    }, value % 10
end

local function EncodeSlots(digits, flag)
    return digits[1] * 1000 + digits[2] * 100 + digits[3] * 10 + flag
end

local function SlotText(value)
    local digits, flag = DecodeSlots(value)
    if flag == 1 then
        return string.format("Weapon %d + Armor %d-%d", digits[1], digits[2], digits[3])
    elseif flag == 3 then
        return string.format("Weapon %d", digits[1])
    end
    return string.format("Armor %d-%d-%d", digits[1], digits[2], digits[3])
end

local function SetCustomValue(list, index, value)
    local ok = pcall(function()
        list:set_Item(index, value)
    end)
    if not ok then
        local ok2, err = pcall(function()
            list[index] = value
        end)
        if not ok2 then
            log.warn("[Talisman Editor] Could not write value: " .. tostring(err))
            return false
        end
    end
    return true
end

local IncludeIncomplete = false
local TextFilter = ""

local Entries = {}
local EntriesDirty = true
local EntriesBuiltAt = -math.huge
local EntriesBuiltCount = -1

local EquipBox = nil
local SaveDataAddress = nil
local EquipBoxAddress = nil

local function AddressOf(obj)
    if obj == nil then
        return nil
    end
    local ok, address = pcall(function()
        return obj:get_address()
    end)
    if ok then
        return address
    end
    return nil
end

local function GetSaveDataManager()
    if Core.GetSaveDataManager then
        local ok, mgr = pcall(Core.GetSaveDataManager)
        if ok and mgr then
            return mgr
        end
    end
    return sdk.get_managed_singleton("app.SaveDataManager")
end

local function SyncSaveData()
    local save = nil
    local box = nil
    local mgr = GetSaveDataManager()
    if mgr then
        local ok, current = pcall(function()
            return mgr:getCurrentUserSaveData()
        end)
        if ok then
            save = current
        end
    end
    if save then
        local ok, current = pcall(function()
            return save._Equip._EquipBox
        end)
        if ok then
            box = current
        end
    end

    local saveAddress = AddressOf(save)
    local boxAddress = AddressOf(box)
    if saveAddress ~= SaveDataAddress or boxAddress ~= EquipBoxAddress then
        SaveDataAddress = saveAddress
        EquipBoxAddress = boxAddress
        EquipBox = box
        Entries = {}
        EntriesDirty = true
        EntriesBuiltCount = -1
        BrowserState = Browser.NewState()
    end
end

local function Now()
    if os and os.clock then
        return os.clock()
    end
    return math.huge
end

local function BuildTalismanName(list)
    local parts = {}
    for s = 0, SKILL_COUNT - 1 do
        local level, id = DecodeSkill(list:get_Item(s))
        if id ~= 0 then
            parts[#parts + 1] = string.format("%s Lv%d", SkillLabel(id), level)
        end
    end
    local skills = #parts > 0 and table.concat(parts, ", ") or "(no skills)"
    return string.format("%s | %s", skills, SlotText(list:get_Item(3)))
end

local function CollectEntries(count)
    local result = {}
    for j = 0, count - 1 do
        local work = EquipBox:get_Item(j)
        if work and work:get_Category() == TALISMAN_CATEGORY then
            local list = work.BowgunCustomizeId
            if list then
                local skillCount = 0
                for s = 0, SKILL_COUNT - 1 do
                    if list:get_Item(s) ~= 0 then
                        skillCount = skillCount + 1
                    end
                end

                if IncludeIncomplete or skillCount >= 2 then
                    result[#result + 1] = {
                        idx = j,
                        work = work,
                        list = list,
                        name = BuildTalismanName(list),
                    }
                end
            end
        end
    end
    return result
end

local function RefreshEntries(count)
    local now = Now()
    if EntriesDirty or count ~= EntriesBuiltCount or now - EntriesBuiltAt >= REFRESH_SECONDS then
        Entries = CollectEntries(count)
        EntriesDirty = false
        EntriesBuiltAt = now
        EntriesBuiltCount = count

        if BrowserState.LastEditedIdx then
            for _, e in ipairs(Entries) do
                if e.idx == BrowserState.LastEditedIdx then
                    BrowserState.LastEditedName = e.name
                end
            end
        end
    end
end

local function FilterEntries()
    if TextFilter == "" then
        return Entries
    end
    local needle = TextFilter:lower()
    local result = {}
    for _, e in ipairs(Entries) do
        if e.name:lower():find(needle, 1, true) then
            result[#result + 1] = e
        end
    end
    return result
end

local function MarkEdited(entry)
    EntriesDirty = true
    SafeBrowser(Browser.MarkEdited, BrowserState, entry.idx, entry.name)
end

local function TalismanEditor(entry)
    local list = entry.list
    local i = entry.idx

    imgui.push_id(string.format("TalismanIdx%d", i))
    local open = imgui.tree_node(string.format("%s##TalismanIdx%d", entry.name, i))
    if open then
        if mod.Config.Debug then
            imgui.text(string.format("EquipBox index %d", i))
            imgui.text(string.format("raw: %d, %d, %d | slots %d",
                list:get_Item(0), list:get_Item(1), list:get_Item(2), list:get_Item(3)))
        end

        local usedIds = {}
        for s = 0, SKILL_COUNT - 1 do
            local level, id = DecodeSkill(list:get_Item(s))

            local changed, newId = imgui.combo(
                string.format("Skill %d##TalismanSkill%d", s + 1, s), id, SkillNamesWithCurrent(id))
            if changed and newId ~= id then
                if newId ~= 0 and level < 1 then
                    level = 1
                end
                if SetCustomValue(list, s, EncodeSkill(level, newId)) then
                    MarkEdited(entry)
                end
                id = newId
            end

            if id ~= 0 then
                local lvChanged, newLevel = imgui.slider_int(
                    string.format("Level##TalismanLevel%d", s), level, 1, MAX_SKILL_LEVEL)
                if lvChanged and newLevel ~= level then
                    if SetCustomValue(list, s, EncodeSkill(newLevel, id)) then
                        MarkEdited(entry)
                    end
                end

                if usedIds[id] then
                    imgui.text_colored(
                        string.format("Warning: `%s` is on this talisman more than once", SkillLabel(id)), ORANGE)
                end
                usedIds[id] = true

                if SkillNames[id] == nil then
                    imgui.text_colored("Warning: unknown skill id, the game may not display it", ORANGE)
                end
            end
        end

        local digits, flag = DecodeSlots(list:get_Item(3))
        local slotsChanged = false

        local flagChanged, newFlag = imgui.combo("Slot Layout##TalismanSlotFlag", flag, SlotFlagNames)
        if flagChanged then
            flag = newFlag
            slotsChanged = true
        end
        if SlotFlagNames[flag] == nil then
            imgui.text_colored(string.format("Warning: unusual slot flag %d", flag), ORANGE)
        end

        local labels
        if flag == 1 then
            labels = { "Weapon Slot", "Armor Slot 1", "Armor Slot 2" }
        elseif flag == 3 then
            labels = { "Weapon Slot" }
        else
            labels = { "Armor Slot 1", "Armor Slot 2", "Armor Slot 3" }
        end

        for d = 1, #labels do
            local dChanged, newDigit = imgui.combo(
                string.format("%s##TalismanSlot%d", labels[d], d), digits[d], SlotDigitNames)
            if dChanged then
                digits[d] = newDigit
                slotsChanged = true
            end
        end

        for d = #labels + 1, 3 do
            if digits[d] ~= 0 then
                digits[d] = 0
                slotsChanged = true
            end
        end

        if slotsChanged then
            if SetCustomValue(list, 3, EncodeSlots(digits, flag)) then
                MarkEdited(entry)
            end
        end

        imgui.tree_pop()
    end
    imgui.pop_id()
end

local function TalismanBoxEditor()
    SyncSaveData()
    if not EquipBox then
        imgui.text("Equipment box not loaded yet. Load into the game first.")
        return
    end

    InitSkillNames()

    imgui.text_colored("Back up your save before editing. Changes are written straight into the loaded save data.", ORANGE)

    local changed
    changed, TextFilter = imgui.input_text("Search talismans", TextFilter)
    changed, SkillFilter = imgui.input_text("Skill list filter", SkillFilter)
    changed, IncludeIncomplete = imgui.checkbox("Include talismans with fewer than 2 skills", IncludeIncomplete)
    if changed then
        EntriesDirty = true
    end
    if imgui.button("Refresh list") then
        EntriesDirty = true
    end

    local count = EquipBox:get_Count()
    RefreshEntries(count)

    local filtered = FilterEntries()

    SafeBrowser(Browser.EditedBar, BrowserState, filtered)

    if #filtered == 0 then
        imgui.text("No matching talismans")
        return
    end

    imgui.text(string.format("Showing %d / %d talismans", #filtered, #Entries))
    if #filtered > 500 then
        imgui.text_colored("Too many results. Use search to narrow down.", ORANGE)
    end

    local listOpen = imgui.tree_node(string.format("EquipBox (%d)", count))
    imgui.same_line()
    imgui.text(string.format("talismans: %d, shown: %d", #Entries, #filtered))
    if listOpen then
        for _, e in ipairs(filtered) do
            SafeBrowser(Browser.BeginScroll, BrowserState, e.idx)
            TalismanEditor(e)
        end
        imgui.tree_pop()
    end
end

mod.Menu(function()
    TalismanBoxEditor()
end)
