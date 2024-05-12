local encode = require('possession.utils').percent_encode
local decode = require('possession.utils').percent_decode

describe('percent_encode', function()
    local pairs = {
        { [[foo/bar]], 'foo%2Fbar' },
        { [[unc:\\bar]], 'unc%3A%5C%5Cbar' },
        { [[c:\foo\bar]], 'c%3A%5Cfoo%5Cbar' },
        { [[foo+bar]], 'foo%2Bbar' },
        { [[foo%bar]], 'foo%25bar' },
        { [[foo bar]], 'foo%20bar' },
        { [[foo  bar]], 'foo%20%20bar' },
        { [[foo++bar]], 'foo%2B%2Bbar' },
        { [[foo+%bar]], 'foo%2B%25bar' },
        { [[foo%%bar]], 'foo%25%25bar' },
        { [=[foo[[]]bar]=], 'foo%5B%5B%5D%5Dbar' },
        { [[foo🙃bar]], 'foo%F0%9F%99%83bar' },
    }

    for _, pair in ipairs(pairs) do
        local raw, encoded = unpack(pair)
        it(raw, function()
            assert.equals(encode(raw), encoded)
            assert.equals(decode(encoded), raw)
        end)
    end
end)
