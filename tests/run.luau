--[[
tests/run.luau — domain test entrypoint (ADR-015).

Run through the shell entrypoint (preferred):

    scripts/run-domain-tests.sh

or directly with any supported interpreter:

    luau tests/run.luau
    lua5.4 tests/run.luau

No Noctalia Runtime, no network, no CLI: the domain layer is exercised with
plain-data fixtures only.
]]

package.path = "./?.luau;./?/init.luau;" .. package.path

local Harness
if _VERSION == "Luau" then
    -- Luau resolves relative imports natively.
    Harness = require("./harness")
else
    -- The harness installs the relative-require resolver for plain Lua. Using
    -- the canonical module name here keeps exactly one harness instance shared
    -- with the test files.
    Harness = require("tests/harness")
end

local test_files = {
    "./test_schema",
    "./test_aggregator",
}

for _, file in ipairs(test_files) do
    require(file)
end

local failed = Harness.run()
os.exit(failed == 0 and 0 or 1)
