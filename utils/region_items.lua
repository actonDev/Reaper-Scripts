local Common = require('utils.common')
local Log = require('utils.log')
local Store = require('utils.store')
local Track = require('utils.track')
local Item = require('utils.item')
local TimeSelection = require('utils.time_selection')

local module = {}

-- select mode "enum"
local SELECT_MODE = {
    ALL = 0,
    SIBLINGS = 1,
    CHILDREN = 2
}

local function getSelectMode(track)
    local trackName = Track.name(track)
    local firstChar = string.sub(trackName, 1, 1)
    
    if firstChar == "*" then
        return SELECT_MODE.ALL
    elseif firstChar == ">" then
        return SELECT_MODE.SIBLINGS
    else
        return SELECT_MODE.CHILDREN
    end
end

local function selectAll()
    Track.selectAllTopLevel()
    Track.unselectWithRegex("-(.+)")
    Track.selectChildren()
end

local function selectSiblings(track)
    Track.selectSiblings(track)
    Track.unselectWithRegex("-(.+)")
end

local function selectChildren()
    Track.selectChildren()
    Track.unselectWithRegex("-(.+)")
end

local function select(regionItem)
    if regionItem == nil then
        return
    end
    Item.unselectAll()
    Item.setSelected(regionItem, true)
    
    TimeSelection.setToSelectedItems()
    local track = Track.fromItem(regionItem)
    local selMode = getSelectMode(track)
    if selMode == SELECT_MODE.SIBLINGS then
        selectSiblings(track)
    elseif selMode == SELECT_MODE.ALL then
        selectAll()
    elseif selMode == SELECT_MODE.CHILDREN then
        selectChildren()
    end
    Item.selectInTimeSelectionAcrossSelectedTracks()
    
    TimeSelection.remove()
    
    Track.selectOnly(track)
end

function module.select(regionItem)
    Common.undoBeginBlock()
    Common.preventUIRefresh(1)
    
    select(regionItem)
    
    Common.preventUIRefresh(-1)
    Common.undoEndBlock("ActonDev/Region items: select")
end

local function shouldPropagate(source, target)
    if source == target then
        return false
    end
    
    local sourceType = Item.type(source)
    local targetType = Item.type(target)
    
    if sourceType ~= targetType then
        return false
    end
    
    if sourceType == Item.TYPE.EMPTY then
        return Item.notes(source) == Item.notes(target)
    end
    local sourceName = Item.name(source)
    local targetName = Item.name(target)
    
    return sourceName == targetName
end


local function propagate(regionItem)
    if regionItem == nil then
        return
    end
    local track = Track.fromItem(regionItem)
    Track.selectOnly(track)
    Item.selectAllInSelectedTrack()
    
    local otherRegionItems = Item.selected()
    module.select(regionItem)
    
    -- unselecting region item: we don't copy it
    -- and selecting first track that has an item
    Item.setSelected(regionItem, false)
    local firstItem = Item.firstSelected()
    -- validating: we have something to copy
    if firstItem == nil then
        return
    end
    local firstTrack = Track.fromItem(firstItem)
    
    -- copying region contents
    Item.copySelected()
    for _, otherRegionItem in pairs(otherRegionItems) do
        if shouldPropagate(regionItem, otherRegionItem) then
            clear(otherRegionItem)
            Track.selectOnly(firstTrack)
            Item.paste()

            local otherRegionOffset = Item.getActiveTakeInfo(otherRegionItem, Item.TAKE_PARAM.START_OFFSET)
            Item.adjustStartSelected(-otherRegionOffset)
            -- trimming pasted items to this region time range
            local tstart,tend = Item.startEnd(otherRegionItem)
            Item.splitSelected(tstart)
            Item.splitSelected(tend)
            Item.deleteSelectedOutsideOfRange(tstart, tend)
        end
    end
    Track.selectOnly(track)
    Item.unselectAll()
    Item.setSelected(regionItem, true)
end
-- propagates/copies this region (item) to other matching ones in the same track
--[[
TODOs
- maybe instead of copying all.. iterate all the selected tracks and copy/paste?
this could solve the
- not having to copy the region item itself
- working with "* SONG" tracks that are after a normal track
- get first selected item -> and its track. so then select that track when pasting
]]
function module.propagate(regionItem)
    Common.undoBeginBlock()
    Store.storeArrangeView()
    Store.storeCursorPosition()
    Common.preventUIRefresh(1)
    
    propagate(regionItem)
    Common.updateArrange()
    
    Store.restoreArrangeView()
    Store.restoreCursorPosition()
    Common.preventUIRefresh(-1)
    Common.undoEndBlock("ActonDev/Region items: propagate")
end

function clear(regionItem)
    if regionItem == nil then
        return
    end
    select(regionItem)
    Item.setSelected(regionItem, false)
    Item.deleteSelected()
end

function module.clear(regionItem)
    Common.undoBeginBlock()
    Common.preventUIRefresh(1)
    
    clear(regionItem)
    
    Common.preventUIRefresh(-1)
    Common.undoEndBlock("ActonDev/Region items: clear")
end

return module
