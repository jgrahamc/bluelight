-- bluelight.lua
--
-- Controller for Flying Tiger rotating blue "police" light that
-- has independent control of the motor and LED. The LED has three
-- modes: on, flashing and off. The motor has two modes: on and off.
-- The program connects to WiFi and then hits an API using a shared
-- secret for authorization and receives a JSON API response in the
-- form:
-- {
--    "motor": "<MOTOR_STATE>",
--    "led:    "<LED_STATE>"
-- }
--
-- where MOTOR_STATE is on or off and LED_STATE is off, flashing or
-- steady. 
--
-- Copyright (c) 2018 John Graham-Cumming

local config = require("bluelight-config")

-- This is only used when running 'make check' and these lines are
-- removed by 'make upload'

local dummy = require("dummy") -- TEST_ONLY
local wifi = dummy -- TEST_ONLY
local http = dummy -- TEST_ONLY
local tmr = dummy -- TEST_ONLY
local sjson = dummy -- TEST_ONLY
local gpio = dummy -- TEST_ONLY
local node = dummy -- TEST_ONLY

-- Count of number of getState failures and reboot if too many failures

local failures = 0

-- PIN numbers to GPIO mapping

local pin_D7 = 7
local pin_D8 = 8

local led_pin   = pin_D7
local motor_pin = pin_D8

-- setupGPIO initializes the GPIO ports that control the motor and 
-- the LED
local function setupGPIO()
   gpio.mode(led_pin,   gpio.OUTPUT)
   gpio.mode(motor_pin, gpio.OUTPUT)
end

-- States used for the LED and motor

local on = 1
local off = 0

-- setLED turns the central LED on or off but only actually updates
-- the GPIO state if the value has changed
local led_state = -1
local function setLED(s)
   if s == led_state then return end
   led_state = s

   if s == on then gpio.write(led_pin, gpio.HIGH)
   else            gpio.write(led_pin, gpio.LOW)
   end
end

-- setMotor turns the motor on or off but only actually updates the
-- GPIO state if the value has changed
local motor_state = -1
local function setMotor(s) 
   if s == motor_state then return end
   motor_state = s

   if s == on then gpio.write(motor_pin, gpio.HIGH)
   else            gpio.write(motor_pin, gpio.LOW)
   end
end

-- state_a and state_b are the two LED states that the LED alternates
-- between when update is called.

local state_a = off
local state_b = off
local current = 0

-- update sets the LED to the current value and swaps the value for the
-- next update. It's called every 500ms and is used to implement a 
-- flashing LED.
local function update() 
   if current == 0 then setLED(state_a)
   else                 setLED(state_b)
   end

   current = 1 - current
end

-- setLEDStates sets the two states of the LED. update switches between 
-- these every 500ms
local function setLEDStates(a, b) 
   state_a = a
   state_b = b
end

local led_off = 0
local led_flashing = 1
local led_steady = 2

-- setLEDMode sets the LED to off, flashing or on
local function setLEDMode(s)
    if     s == led_off      then setLEDStates(off, off)
    elseif s == led_flashing then setLEDStates(on, off)
    elseif s == led_steady   then setLEDStates(on, on)
    end
end

-- connectWiFi connects to the WiFi network defined above as a station
-- This will try to connect for 30 seconds and then give up. Returns
-- true is successfully connected.
local function connectWiFi()
   wifi.setmode(wifi.STATION)

   local cfg = {}
   cfg.ssid = config.SSID
   cfg.pwd  = config.PASS
   wifi.sta.config(cfg)

   wifi.sta.connect()

   local i = 30

   tmr.alarm(1, 1000, tmr.ALARM_AUTO, function()
      if wifi.sta.getip() ~= nil then
         tmr.stop(1)
      else
         i = i - 1
         if i == 0 then tmr.stop(1) end
      end
   end)

   dummy.run(1) -- TEST_ONLY

   return i ~= 0
end

-- parseState is a callback from http.get in getState that sees if the API call
-- was successful and if so decodes the JSON to find the current state of
-- the motor and LED and then set that state
local function parseState(code, data, headers)
   if code == 200 and headers ~= nil then
      local ok, p = pcall(sjson.decode, data)
      if ok and p ~= nil then
          if p.motor == nil then return end
          if p.led   == nil then return end

          if     p.motor == "on"  then setMotor(on)
          elseif p.motor == "off" then setMotor(off)
          end

          if     p.led == "off"      then setLEDMode(led_off)
          elseif p.led == "flashing" then setLEDMode(led_flashing)   
          elseif p.led == "steady"   then setLEDMode(led_steady)
          end

          failures = 0
          return
      end
   end

   -- If anything goes wrong with the API call then count as a failure
   -- that may eventually lead to a watchdog reboot

   failures = failures + 1
end

-- getState makes an API call to find out what state the motor should be in
-- and calls setMotor to read the API response (or error)
local api = config.API
local function getState()
   http.get(api .. config.SECRET, nil, parseState)
end

-- How fast to call update, watchdog and getState in ms.

local update_interval   = 1000 / 2
local watchdog_interval = 60 * 1000
local getState_interval = 10 * 1000

-- watchdog resets Bluelight if there hasn't been a successful getState for
-- 5 minutes
local function watchdog()
   if failures == (5 * 60 * 1000)/getState_interval then node.restart() end
end

setupGPIO()
setLEDMode(led_off)
setMotor(off)

-- Call the update function (which handles the LED state) once every 500ms

tmr.alarm(0, update_interval, tmr.ALARM_AUTO, update)

setLEDMode(led_flashing)
if connectWiFi() then setLEDMode(led_off) end

-- Call the watchdog once a minute to see if we have some failure (like WiFi
-- going bad) and getState (to retrieve the API response) once every 10 
-- seconds

tmr.alarm(2, watchdog_interval, tmr.ALARM_AUTO, watchdog)
tmr.alarm(3, getState_interval, tmr.ALARM_AUTO, getState)

dummy.run(0) -- TEST_ONLY
