-- init.lua
--
-- Run the Bluelight program after a short delay (see 
-- https://nodemcu.readthedocs.io/en/master/en/lua-developer-faq/#how-do-i-avoid-a-panic-loop-in-initlua for why)
--
-- Copyright (c) 2018 John Graham-Cumming

local tmr = require("dummy") -- TEST_ONLY

tmr.alarm(3, 5000, tmr.ALARM_SINGLE, function()
   local bluelight = require("bluelight")
end)

tmr.run(3) -- TEST_ONLY
