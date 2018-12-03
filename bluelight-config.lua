-- bluelight-config.lua
--
-- Configuration of WiFi parameters and credentials

local _M = {}

-- SSID and WPA2 password for WiFi network

_M.SSID = ""
_M.PASS = ""

-- Shared secret passed to Cloudflare Worker and the
-- API endpoint

_M.API = "http://example.com/bluelight?token="
_M.SECRET = ""

return _M

