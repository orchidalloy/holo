--       Hologram Viewer v0.7.1
-- 2017 (c) Totoro (aka MoonlightOwl)
--         computercraft.ru

local fs = require('filesystem')
local shell = require('shell')
local com = require('component')
local bit32 = require('bit32')
local args = { ... }

local loc = {
  ERROR_NO_FILENAME = "[ОШИБКА] Необходимо указать имя файла с моделью.",
  ERROR_WRONG_FILE_FORMAT = "[ОШИБКА] Неверный формат файла. Hologram Viewer может работать с файлами формата *.3dx или *.3d.",
  ERROR_INVALID_FORMAT_STRUCTURE = "[ОШИБКА] Структура файла не соответствует формату.",
  ERROR_UNABLE_TO_OPEN = "[ОШИБКА] Невозможно открыть файл: ",
  ERROR_FILE_NOT_FOUND = "[ОШИБКА] Файл не найден: ",
  ERROR_WRONG_SCALE = "[ОШИБКА] Масштаб голограммы должен быть числом от 0.33 до 4.00",
  ERROR_NO_PROJECTOR = "[ОШИБКА] Не найден проектор.",
  DONE = "Готово. Голограмма выведена на проектор."
}

-- ================================ H O L O G R A M S   S T U F F ================================ --
-- loading add. components
function trytofind(name)
  if com.isAvailable(name) then
    return com.getPrimary(name)
  else
    return nil
  end
end

-- constants
local HOLOH = 32
local HOLOW = 48
local LAYERSIZE = 48 * 48

-- hologram vars
local holo = {}

local function getIndex(x, y, z)
  return LAYERSIZE * (y - 1) + (x + (z - 1) * HOLOW)
end
local function set(x, y, z, value)
  local index = getIndex(x, y, z)
  if holo[index] ~= nil or (value ~= nil and value ~= 0) then
    holo[index] = value
  end
end
local function get(x, y, z)
  local index = getIndex(x, y, z)
  return holo[index] or 0
end

local function rgb2hex(r,g,b)
  return r*65536+g*256+b
end


local reader = {}
function reader:init(file)
  self.buffer = {}
  self.file = file
end
function reader:read()
  if #self.buffer == 0 then 
    if not self:fetch() then return nil end
  end
  local sym = self.buffer[#self.buffer]
  self.buffer[#self.buffer] = nil
  return sym
end
function reader:fetch()
  self.buffer = {}
  local char = file:read(1)
  if char == nil then return false
  else
    local byte = string.byte(char)
    for i=0, 3 do
      local a = byte % 4
      byte = math.floor(byte / 4)
      self.buffer[4-i] = a
    end
    return true
  end
end

local function loadHologram(filename)
  if filename == nil then
    error(loc.ERROR_NO_FILENAME)
  end

  local path = shell.resolve(filename, "3dx")
  if path == nil then path = shell.resolve(filename, "3d") end

  if path ~= nil then
    local compressed
    if string.sub(path, -4) == '.3dx' then
      compressed = true
    elseif string.sub(path, -3) == '.3d' then
      compressed = false
    else
      error(loc.ERROR_WRONG_FILE_FORMAT)
    end
    file = io.open(path, 'rb')
    if file ~= nil then
      for i=1, 3 do
        for c=1, 3 do
          colortable[i][c] = string.byte(file:read(1))
        end
        hexcolortable[i] = rgb2hex(colortable[i][1], colortable[i][2], colortable[i][3])
      end
      holo = {}
      reader:init(file)
      if compressed then
        local x, y, z = 1, 1, 1
        while true do
          local a = reader:read()
          if a == nil then file:close(); return true end
          local len = 1
          while true do
            local b = reader:read()
            if b == nil then 
              file:close()
              if a == 0 then return true
              else error(loc.ERROR_INVALID_FORMAT_STRUCTURE) end
            end
            local fin = (b > 1)
            if fin then b = b - 2 end
            len = bit32.lshift(len, 1)
            len = len + b
            if fin then break end
          end
          len = len - 1
          for i = 1, len do
            if a ~= 0 then set(x,y,z, a) end
            z = z + 1
            if z > HOLOW then
              y = y + 1
              if y > HOLOH then
                x = x + 1
                if x > HOLOW then file:close(); return true end
                y = 1
              end
              z = 1
            end  
          end
        end
      else
        for x = 1, HOLOW do
          for y = 1, HOLOH do
            for z = 1, HOLOW do
              local a = reader:read()
              if a ~= 0 and a ~= nil then 
                set(x, y, z, a)
              end
            end
          end
        end
      end
      file:close()
      return true
    else
      error(loc.ERROR_UNABLE_TO_OPEN .. filename)
    end
  else
    error(loc.ERROR_FILE_NOT_FOUND .. filename)
  end
end

function scaleHologram(scale)
  if scale == nil or scale < 0.33 or scale > 4 then
    error(loc.ERROR_WRONG_SCALE)
  end
  proj_scale = scale
end

function drawHologram()
  -- check hologram projector availability
  h = trytofind('hologram')
  if h ~= nil then
    local depth = h.maxDepth()
    -- clear projector
    h.clear()
    -- set projector scale
    h.setScale(proj_scale)
    -- send palette
    if depth == 2 then
      for i = 1, 3 do
        h.setPaletteColor(i, hexcolortable[i])
      end
    else
      h.setPaletteColor(1, hexcolortable[1])
    end
    -- send voxel array
    for x = 1, HOLOW do
      for y = 1, HOLOH do
        for z = 1, HOLOW do
          n = get(x,y,z)
          if n ~= 0 then
            if depth == 2 then
              h.set(x, y, z, n)
            else
              h.set(x, y, z, 1)
            end
          end
        end
      end      
    end
    print(loc.DONE)
  else
    error(loc.ERROR_NO_PROJECTOR)
  end
end
-- =============================================================================================== --

-- Main part
loadHologram(args[1])

if args[2] ~= nil then
  scaleHologram(tonumber(args[2]))
end

drawHologram()
