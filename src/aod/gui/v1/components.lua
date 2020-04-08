--[[
    Gui Components
    - Made out of extending and composing the core elements
]]
local Gui = require("aod.gui.v1.core")
local Class = require("aod.utils.class")
local Search = require("aod.utils.search")
local Log = require("aod.utils.log")
local Table = require("aod.utils.table")
local module = {}

local exampleAutoComplete = {
    -- search = {}, -- the map to be passed to the search module
    search = {
        entries = {
            {name = "blah blah", id = 1},
            {name = "boobla", id = 2}
        }, -- an array of the searchable entries
        query = "query", -- the query to search over the entries
        limit = "limit", -- the limit for the results to return
        key = "name", -- the key of the entries to perform the search to
        showAll = "showAll" -- show all the results when query is empty
    },
    layout = {}, -- options to be passed to the layout
    input = {} -- options to be passed to the input
}

local layoutBtnOpts = {
    id = "repeated btn",
    w = "100%",
    borderColor = {
        r = 1,
        g = 1,
        b = 1
    },
    borderWidth = 2,
    bg = {
        r = 0.5,
        g = 0.5,
        b = 0.5
    },
    fg = {
        r = 1,
        g = 1,
        b = 1
    },
    text = "button"
}

local function makeResultButton(opts)
    layoutBtnOpts.text = opts.name
    local btn = Gui.Button(layoutBtnOpts)
    btn:watch_mod(
        "selected",
        function(el, old, new)
            if new then
                return {
                    [{"borderColor"}] = {r = 1, b = 0, g = 0}
                }
            end
        end
    )

    return btn
end

local exampleData = {
    search = {
        entries = {
            {name = "split items"},
            {name = "start recording"},
            {name = "do this"},
            {name = "do that"}
        }, -- an array of the searchable entries
        query = "query", -- the query to search over the entries
        limit = 10,
        key = "name", -- the key of the entries to perform the search to
        showAll = true
    },
    layout = {
        w = "100%",
        -- h = 100,
        spacing = 5,
        padding = 5,
        borderColor = {r = 0, g = 0, b = 1, a = 1},
        borderWidth = 2,
        elements = {}
    }, -- options to be passed to the layout
    input = {
        w = "100%",
        placeholder = "start typing to search"
    }
}

local exapmleResults = {
    {name = "result 1", id = 1},
    {name = "result 2", id = 2}
}

module.AutoComplete = Class.extend(Gui.VLayout)

function module.AutoComplete:__construct(data)
    data = data or exampleData

    local input = Gui.Input(data.input)
    data.input = nil

    local resultList =
        Gui.List(
        {
            focus = true,
            w = "100%",
            elements = {}
        }
    )

    input:watch(
        "text",
        function(el, oldV, newV)
            data.search.query = newV
            local results = Search.search(data.search)
            local buttons = Table.map(results, makeResultButton)
            resultList:set("elements", buttons)
        end
    )

    input:set("text", "", true)

    data.layout.elements = {
        input,
        resultList
    }

    -- local layout = Gui.VLayout(data.layout)
    -- data.layout = nil

    Gui.VLayout.__construct(self, data.layout)

    -- self.input = input
    -- self.layout = layout
end

function module.AutoComplete:draw()
    -- Log.debug("drawing autocompleteee")
    Gui.VLayout.draw(self)
end

return module
