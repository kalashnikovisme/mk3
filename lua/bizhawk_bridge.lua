--[[
  FightingAI BizHawk Lua Bridge
  ================================
  Runs inside BizHawk. On every frame it:
    1. Reads game memory.
    2. Sends a JSON frame snapshot to the Ruby bridge server via TCP.
    3. Receives a JSON response (input command or noop).
    4. Applies controller inputs.
    5. Advances one frame.

  Configuration:
    BRIDGE_HOST  — Ruby server host (default: 127.0.0.1)
    BRIDGE_PORT  — Ruby server port (default: 7878)
    GAME_ID      — game identifier string sent in every frame
]]

local BRIDGE_HOST = "127.0.0.1"
local BRIDGE_PORT = 7878
local GAME_ID     = "mortal_kombat_3"

-- ---------------------------------------------------------------------------
-- Memory addresses (SNES WRAM — MK3)
-- ---------------------------------------------------------------------------
local ADDR = {
  game_state   = 0x0101,
  round_number = 0x018A,
  round_timer  = 0x01A0,

  p1_health    = 0x011A,
  p1_max_hp    = 0x011C,
  p1_x         = 0x0120,
  p1_y         = 0x0122,
  p1_facing    = 0x0126,
  p1_anim      = 0x012A,
  p1_anim_frm  = 0x012C,
  p1_state     = 0x0130,

  p2_health    = 0x014A,
  p2_max_hp    = 0x014C,
  p2_x         = 0x0150,
  p2_y         = 0x0152,
  p2_facing    = 0x0156,
  p2_anim      = 0x015A,
  p2_anim_frm  = 0x015C,
  p2_state     = 0x0160,
}

-- ---------------------------------------------------------------------------
-- Controller button map (BizHawk SNES button names)
-- P1/P2 prefix added when building the joypad table.
-- ---------------------------------------------------------------------------
local BUTTON_NAMES = {
  "Up", "Down", "Left", "Right",
  "Y", "X", "B", "A", "L", "R",
  "Start", "Select"
}

-- ---------------------------------------------------------------------------
-- JSON encoder (minimal, sufficient for our payload shapes)
-- ---------------------------------------------------------------------------
local function json_encode(t)
  local typ = type(t)
  if typ == "nil"     then return "null"
  elseif typ == "boolean" then return tostring(t)
  elseif typ == "number"  then return tostring(t)
  elseif typ == "string"  then
    return '"' .. t:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
  elseif typ == "table" then
    -- detect array heuristic: all keys are consecutive integers from 1
    local is_array = true
    local max_n = 0
    for k, _ in pairs(t) do
      if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
        is_array = false; break
      end
      if k > max_n then max_n = k end
    end
    if is_array then
      local parts = {}
      for i = 1, max_n do parts[i] = json_encode(t[i]) end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      local parts = {}
      for k, v in pairs(t) do
        parts[#parts + 1] = json_encode(tostring(k)) .. ":" .. json_encode(v)
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  end
  return "null"
end

-- ---------------------------------------------------------------------------
-- JSON decoder (minimal — parses the simple shapes we receive)
-- ---------------------------------------------------------------------------
local function json_decode(s)
  local pos = 1

  local function skip_ws()
    while pos <= #s and s:sub(pos, pos):match("%s") do pos = pos + 1 end
  end

  local parse_value

  local function parse_string()
    pos = pos + 1  -- skip opening "
    local result = {}
    while pos <= #s do
      local c = s:sub(pos, pos)
      if c == '"' then pos = pos + 1; break end
      if c == '\\' then
        pos = pos + 1
        c = s:sub(pos, pos)
        if c == 'n' then c = '\n' elseif c == 't' then c = '\t' end
      end
      result[#result + 1] = c
      pos = pos + 1
    end
    return table.concat(result)
  end

  local function parse_number()
    local start = pos
    if s:sub(pos, pos) == '-' then pos = pos + 1 end
    while pos <= #s and s:sub(pos, pos):match("[0-9%.eE%+%-]") do pos = pos + 1 end
    return tonumber(s:sub(start, pos - 1))
  end

  local function parse_object()
    pos = pos + 1  -- skip {
    local t = {}
    skip_ws()
    if s:sub(pos, pos) == '}' then pos = pos + 1; return t end
    while true do
      skip_ws()
      local key = parse_string()
      skip_ws()
      pos = pos + 1  -- skip :
      skip_ws()
      t[key] = parse_value()
      skip_ws()
      local c = s:sub(pos, pos)
      if c == '}' then pos = pos + 1; break end
      if c == ',' then pos = pos + 1 end
    end
    return t
  end

  local function parse_array()
    pos = pos + 1  -- skip [
    local t = {}
    skip_ws()
    if s:sub(pos, pos) == ']' then pos = pos + 1; return t end
    while true do
      skip_ws()
      t[#t + 1] = parse_value()
      skip_ws()
      local c = s:sub(pos, pos)
      if c == ']' then pos = pos + 1; break end
      if c == ',' then pos = pos + 1 end
    end
    return t
  end

  parse_value = function()
    skip_ws()
    local c = s:sub(pos, pos)
    if c == '"'  then return parse_string()
    elseif c == '{' then return parse_object()
    elseif c == '[' then return parse_array()
    elseif c == 't' then pos = pos + 4; return true
    elseif c == 'f' then pos = pos + 5; return false
    elseif c == 'n' then pos = pos + 4; return nil
    else return parse_number()
    end
  end

  skip_ws()
  return parse_value()
end

-- ---------------------------------------------------------------------------
-- Memory helpers
-- ---------------------------------------------------------------------------
local function read_u8(addr)
  return mainmemory.read_u8(addr)
end

local function read_u16_be(addr)
  local hi = mainmemory.read_u8(addr)
  local lo = mainmemory.read_u8(addr + 1)
  return hi * 256 + lo
end

-- ---------------------------------------------------------------------------
-- Frame snapshot builder
-- ---------------------------------------------------------------------------
local function build_snapshot(frame_num)
  local gs   = read_u8(ADDR.game_state)
  local rnd  = read_u8(ADDR.round_number)
  local tmr  = read_u8(ADDR.round_timer)

  local function player_data(prefix)
    return {
      health     = read_u8(ADDR[prefix .. "health"]),
      max_health = read_u8(ADDR[prefix .. "max_hp"]),
      x          = read_u16_be(ADDR[prefix .. "x"]),
      y          = read_u16_be(ADDR[prefix .. "y"]),
      facing     = read_u8(ADDR[prefix .. "facing"]),
      anim       = read_u8(ADDR[prefix .. "anim"]),
      anim_frame = read_u8(ADDR[prefix .. "anim_frm"]),
      state      = read_u8(ADDR[prefix .. "state"])
    }
  end

  return {
    type       = "frame",
    frame      = frame_num,
    game       = GAME_ID,
    game_state = gs,
    round      = rnd,
    timer      = tmr,
    match_over = false,
    players    = {
      ["1"] = player_data("p1_"),
      ["2"] = player_data("p2_")
    }
  }
end

-- ---------------------------------------------------------------------------
-- Controller input application
-- ---------------------------------------------------------------------------
local function apply_input(response)
  if response.type ~= "input" then return end

  local player = tostring(response.player)
  local prefix = "P" .. player .. " "
  local buttons = response.buttons or {}

  local joypad_table = {}
  for _, btn in ipairs(BUTTON_NAMES) do
    local key = prefix .. btn
    joypad_table[key] = buttons[btn] == true
  end

  joypad.set(joypad_table)
end

-- ---------------------------------------------------------------------------
-- TCP connection
-- ---------------------------------------------------------------------------
local socket = require("socket")
local client

local function connect()
  client = socket.tcp()
  client:settimeout(10)
  local ok, err = client:connect(BRIDGE_HOST, BRIDGE_PORT)
  if not ok then
    error("FightingAI: cannot connect to bridge server at " ..
          BRIDGE_HOST .. ":" .. BRIDGE_PORT .. " — " .. tostring(err))
  end
  client:settimeout(0.1)
  print("FightingAI: connected to bridge server")
end

local function send_line(data)
  client:send(data .. "\n")
end

local function recv_line()
  local line, err = client:receive("*l")
  if err == "timeout" then return nil end
  return line
end

-- ---------------------------------------------------------------------------
-- Main loop
-- ---------------------------------------------------------------------------
connect()

local frame_num = 0

while true do
  frame_num = frame_num + 1

  local snapshot = build_snapshot(frame_num)
  send_line(json_encode(snapshot))

  local line = recv_line()
  if line and #line > 0 then
    local ok, response = pcall(json_decode, line)
    if ok and response then
      apply_input(response)
    end
  end

  emu.frameadvance()
end
