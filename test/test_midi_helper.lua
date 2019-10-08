package.path = './test/?.lua;' .. package.path

lu = require('luaunit')
midi = require('deps.midi_helper')

midiStructure01 = {
    item = {tstart = 2.0, tend = 5.0},
    frequencies = {
        -- note: it couldbe that a note/f tstart is even less than the item tstart
        -- that happens when the midi item has a start offset
        {f = 120, tstart = 2.0, tend = 3.0},
        {f = 130, tstart = 3.0, tend = 4.0},
        {f = 135, tstart = 3.5, tend = 4.0},
        {f = 199, tstart = 0.0, tend = 10.0} -- for example tstart should be converted to 2 and end to 5
    }
}

function testRelativeTimings()
    local actual = midi.midiStructureToRelativeTimings(midiStructure01,3.5)
    local expected = {
        frequencies={
            {f=120, tend=-0.5, tstart=-1.5},
            {f=130, tend=0.5, tstart=-0.5},
            {f=135, tend=0.5, tstart=0},
            {f=199, tend=1.5, tstart=-1.5} -- note: it got "cropped" in the midi borders
        },
        item={tend=1.5, tstart=-1.5}
    }
    lu.assertEquals(actual, expected)
end

os.exit(lu.LuaUnit.run())
