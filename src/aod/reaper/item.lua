local Common = require("aod.reaper.common")
local Log = require("aod.utils.log")
local Colors = require("aod.reaper.colors")
local EditCursor = require("aod.reaper.edit_cursor")
local TimeSelection = require("aod.reaper.time_selection")
local module = {}

module.TYPE = {
    EMPTY = 0,
    MIDI = 1,
    AUDIO = 2
}

module.PARAM = {
    POSITION = "D_POSITION",
    LENGTH = "D_LENGTH",
    MUTE = "B_MUTE"
}

module.TAKE_ENV = {
    PAN = "Pan"
}

module.TAKE_PARAM = {
    START_OFFSET = "D_STARTOFFS",
    PITCH = "D_PITCH",
    STR_NAME = "P_NAME"
}

function module.chunk(item)
    local _retval, itemChunk = reaper.GetItemStateChunk(item, "")
    return itemChunk
end

-- probably should think of other items in the future.. Project In Project eg?
-- @return the item's type. eg empty,midi,audio
function module.type(item)
    local chunk = module.chunk(item)
    local itemType = string.match(chunk, "<SOURCE%s(%P%P%P).*\n")
    if itemType == nil then
        return module.TYPE.EMPTY
    elseif itemType == "MID" then
        return module.TYPE.MIDI
    else
        return module.TYPE.AUDIO
    end
end

function module.position(item)
    return reaper.GetMediaItemInfo_Value(item, "D_POSITION")
end

function module.activeTake(item)
    return reaper.GetActiveTake(item)
end

function module.toggleReverse()
    -- Item properties: Toggle take reverse
    Common.cmd(41051)
end

-- TODO rename to activeTakeName
function module.activeTakeName(item)
    local take = module.activeTake(item)
    if take == nil then
        return ""
    end
    local _, name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)

    return name
end

function module.insertMidiItem()
    -- Insert new MIDI item...
    Common.cmd(40214)
end

function module.setVolume(item, vol)
    reaper.SetMediaItemInfo_Value(item, "D_VOL", vol)
end
-- https://www.extremraym.com/cloud/reascript-doc/#GetSetMediaItemInfo_String
function module.getVolume(item)
    return reaper.GetMediaItemInfo_Value(item, "D_VOL")
end

function module.countMidiNotes(item)
    local take = reaper.GetActiveTake(item)
    _retval, notecnt, _ccevtcnt, _textsyxevtcnt = reaper.MIDI_CountEvts(take)

    return notecnt
end

function module.iterateMidiNotes(item, cb)
    local take = reaper.GetActiveTake(item)

    for i = 0, module.countMidiNotes(item) - 1 do
        local _retval, _selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
        local tstart = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos)
        local tend = reaper.MIDI_GetProjTimeFromPPQPos(take, endppqpos)
        local noteMap = {
            muted = muted,
            tstart = tstart,
            tend = tend,
            chan = chan,
            pitch = pitch,
            vel = vel
        }
        cb(noteMap)
    end
end

function module.selectInTimeSelectionAcrossSelectedTracks()
    -- Item: Select all items on selected tracks in current time selection
    Common.cmd(40718)
end

function module.validate(item)
    return reaper.ValidatePtr(item, "MediaItem*")
end

function module.selectAllInSelectedTrack()
    -- Item: Select all items in track
    Common.cmd(40421)
end

function module.unselectAll()
    -- Item: Unselect all items
    Common.cmd(40289)
end

function module.setSelected(item, selected)
    reaper.SetMediaItemSelected(item, selected)
end

function module.firstSelected()
    return reaper.GetSelectedMediaItem(0, 0)
end

function module.selectedCount()
    return reaper.CountSelectedMediaItems(0)
end

function module.selected()
    local selCount = reaper.CountSelectedMediaItems(0)
    local items = {}

    for i = 0, selCount - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        table.insert(items, item)
    end

    return items
end

function module.startEnd(item)
    local tstart = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local tend = tstart + length

    return tstart, tend
end

function module.getInfo(item, param)
    return reaper.GetMediaItemInfo_Value(item, param)
end

function module.setInfo(item, param, value)
    reaper.SetMediaItemInfo_Value(item, param, value)
end

function module.setActiveTakeInfoString(item, param, value)
    local take = module.activeTake(item)
    if take == nil then
        return
    end
    --  retval, stringNeedBig = reaper.GetSetMediaItemTakeInfo_String( tk, parmname, stringNeedBig, setNewValue )
    _retval, _stringNeedBig = reaper.GetSetMediaItemTakeInfo_String(take, param, value, true)
end

function module.setActiveTakeInfo(item, param, value)
    local take = module.activeTake(item)
    if take == nil then
        return
    end
    reaper.SetMediaItemTakeInfo_Value(take, param, value)
end

function module.getActiveTakeInfo(item, param)
    if not item then
        return nil
    end
    local take = module.activeTake(item)
    if take == nil then
        return
    end
    return reaper.GetMediaItemTakeInfo_Value(take, param)
end

function module.adjustActiveTakeInfo(item, param, adjust)
    local take = module.activeTake(item)
    -- could be that the item passed is an empty item
    if take == nil then
        return
    end
    local value = reaper.GetMediaItemTakeInfo_Value(take, param)
    reaper.SetMediaItemTakeInfo_Value(take, param, value + adjust)
end

function module.adjustInfo(item, param, adjust)
    local value = module.getInfo(item, param)
    module.setInfo(item, param, value + adjust)
end

function module.adjustInfoSelected(param, adjust)
    local items = module.selected()
    for _, item in pairs(items) do
        module.adjustInfo(item, param, adjust)
    end
end

function module.adjustActiveTakeInfoSelected(param, adjust)
    local items = module.selected()
    for _, item in pairs(items) do
        module.adjustActiveTakeInfo(item, param, adjust)
    end
end

function module.notes(item)
    return reaper.ULT_GetMediaItemNote(item)
end

function module.copySelected()
    -- Edit: Copy items
    Common.cmd(40698)
end

-- copies the selected items respecting the time selection
function module.copySelectedArea()
    -- Item: Copy selected area of items
    Common.cmd(40060)
end

function module.deleteSelected()
    -- Item: Remove items
    Common.cmd(40006)
end

function module.splitSelectedTimeSelection()
    -- I noticed buggy splits when no items were selected
    if module.selectedCount() == 0 then
        return
    end

    -- gotta check if there is any time selection. cause if not, reaper throws an alert box
    -- if it's not, both start and end are 0.. not nil
    local tstart, tend = TimeSelection.get()
    if tstart == tend then
        return
    end
    -- Item: Split items at time selection
    Common.cmd(40061)
end

-- note: should call updateArrange afterwards
function module.delete(item)
    reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track(item), item)
end

-- note: should call updateArrange afterwards
function module.deleteSelectedOutsideOfRange(tstart, tend)
    local tolerance = 0.000001
    local selected = module.selected()
    for _, item in pairs(selected) do
        local itemStart, itemEnd = module.startEnd(item)
        local shouldDelete = false
        if itemEnd - tolerance < tstart then
            shouldDelete = true
        elseif itemStart + tolerance > tend then
            shouldDelete = true
        end
        if shouldDelete then
            module.delete(item)
        end
    end
    Common.updateArrange()
end

function module.splitSelected(t)
    -- I noticed buggy splits when no items were selected
    if module.selectedCount() == 0 then
        return
    end
    EditCursor.setPosition(t)
    -- Item: Split items at edit cursor (no change selection)
    Common.cmd(40757)
end

function module.paste()
    -- Item: Paste items/tracks
    Common.cmd(40058)
end

local function paintValue(item, value)
    local nTakes = reaper.GetMediaItemNumTakes(item)
    if nTakes > 0 then
        local take = reaper.GetActiveTake(item)
        reaper.SetMediaItemTakeInfo_Value(take, "I_CUSTOMCOLOR", value)
    else
        reaper.SetMediaItemInfo_Value(item, "I_CUSTOMCOLOR", value)
    end
end

function module.paint(item, r, g, b)
    local value = Colors.reaperValue(r, g, b)
    paintValue(item, value)
end

function module.unpaint(item)
    paintValue(item, 0)
end

function module.hasActiveTakeEnvelope(item, envType)
    return reaper.GetTakeEnvelopeByName(module.activeTake(item), envType) ~= nil
end

return module
