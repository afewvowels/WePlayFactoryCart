local util = require("util")
local sprites = require("graphics.sprites")

-- ---------------------------------------------------------------------------
-- Tuning
-- ---------------------------------------------------------------------------
local setting = settings.startup
local BATTERY_MJ  = setting["wp-factory-cart-battery-mj"].value
local CHARGE_MW   = setting["wp-factory-cart-charge-mw"].value
local CARGO_SLOTS = setting["wp-factory-cart-cargo-slots"].value

local BATTERY_CAPACITY = BATTERY_MJ .. "MJ"   -- control.lua reads it back from the charge item
local MOTOR_POWER      = "350kW"

-- Sound volumes (0 to 1)
local MOTOR_DRIVING_VOLUME = 0.7
local MOTOR_IDLE_VOLUME    = 0.42
local MOTOR_CLICK_VOLUME   = 0.5
local CHARGE_RATE      = math.floor(CHARGE_MW * 1000 + 0.5) .. "kW"
-- control.lua charges every 10 ticks, so the buffer holds 10 ticks' worth (plus a little slack)
local CHARGE_BUFFER    = math.ceil(CHARGE_MW * 1e6 * 10 / 60 * 1.01) .. "J"

local function shift(entry)
  return { entry.shift_px[1] * sprites.scale / 32, entry.shift_px[2] * sprites.scale / 32 }
end

local function cart_layer(entry, extra)
  local layer = {
    filename = entry.file,
    width = entry.width,
    height = entry.height,
    shift = shift(entry),
    scale = sprites.scale,
    direction_count = 64,
    line_length = 8,
    frame_count = 1,
    priority = "low",
  }
  for k, v in pairs(extra or {}) do layer[k] = v end
  return layer
end

-- ---------------------------------------------------------------------------
-- Sounds
-- ---------------------------------------------------------------------------
data:extend({
  {
    type = "sound",
    name = "wp-factory-cart-latch",
    filename = "__WePlayFactoryCart__/sound/latch.ogg",
    volume = 0.7,
  },
})

-- ---------------------------------------------------------------------------
-- Battery "fuel": a hidden item the script keeps topped up from the grid
-- ---------------------------------------------------------------------------
data:extend({
  { type = "fuel-category", name = "wp-factory-cart-battery" },
  {
    type = "item",
    name = "wp-factory-cart-charge",
    icon = "__base__/graphics/icons/battery.png",
    fuel_categories = { "wp-factory-cart-battery" },   -- 2.1: was fuel_category
    fuel_value = BATTERY_CAPACITY,
    stack_size = 1,
    hidden = true,
  },
})

-- ---------------------------------------------------------------------------
-- Hidden charger that follows each cart and pulls power from nearby poles
-- ---------------------------------------------------------------------------
data:extend({
  {
    type = "electric-energy-interface",
    name = "wp-factory-cart-charger",
    icon = "__base__/graphics/icons/car.png",
    flags = { "not-on-map", "not-blueprintable", "not-deconstructable", "placeable-off-grid",
              "hide-alt-info", "no-copy-paste", "not-in-kill-statistics", "not-selectable-in-game" },
    hidden = true,
    max_health = 1,
    collision_box = { { -0.4, -0.4 }, { 0.4, 0.4 } },
    collision_mask = { layers = {} },
    selectable_in_game = false,
    energy_source = {
      type = "electric",
      usage_priority = "secondary-input",
      buffer_capacity = CHARGE_BUFFER,
      input_flow_limit = CHARGE_RATE,
      output_flow_limit = "0W",
      render_no_network_icon = false,   -- no flashing icons when the cart is away from poles
      render_no_power_icon = false,
    },
    energy_production = "0W",
    energy_usage = "0W",
  },
})

-- ---------------------------------------------------------------------------
-- The cart
-- ---------------------------------------------------------------------------
local vanilla = data.raw["car"]["car"]

local DUST_WIDTH = 0.8   -- tyre dust spread, as a fraction of the vanilla car's

-- Scale the x of every wheel position ("offset"/"offsets" vectors) in a trigger list
local function narrow_offsets(t, factor)
  local count = 0
  local function vec(v)
    if type(v) ~= "table" then return end
    if type(v.x) == "number" then v.x = v.x * factor; count = count + 1
    elseif type(v[1]) == "number" and type(v[2]) == "number" then v[1] = v[1] * factor; count = count + 1 end
  end
  local function walk(node)
    if type(node) ~= "table" then return end
    for k, v in pairs(node) do
      if k == "offset" then vec(v)
      elseif k == "offsets" and type(v) == "table" then for _, o in pairs(v) do vec(o) end
      else walk(v) end
    end
  end
  walk(t)
  return t
end

local function make_cart(name, order, script_paint)
  local cart = util.table.deepcopy(vanilla)
  cart.name = name
  cart.icon = "__WePlayFactoryCart__/graphics/icons/" .. name:gsub("^wp%-", "") .. ".png"
  cart.icon_size = 64
  cart.order = order
  cart.minable = { mining_time = 0.4, result = name }
  cart.placeable_by = nil

  -- Electric drive: vanilla is 600 kW at 0.6 effectivity (360 kW at the wheels).
  -- 350 kW at 1.0 effectivity keeps the driving force about the same,
  -- and half the weight roughly doubles the acceleration.
  cart.consumption = MOTOR_POWER
  cart.effectivity = 1
  cart.weight = vanilla.weight / 2
  cart.energy_source = {
    type = "burner",
    fuel_categories = { "wp-factory-cart-battery" },
    effectivity = 1,
    fuel_inventory_size = 1,
    burnt_inventory_size = 0,
  }

  -- Nimble and unarmed
  cart.guns = nil
  cart.turret_animation = nil
  cart.turret_rotation_speed = nil
  cart.rotation_speed = 0.022          -- vanilla 0.015
  cart.inventory_size = CARGO_SLOTS    -- startup setting, 0 to 50 (vanilla car has 80)
  cart.collision_box = { { -0.5, -0.8 }, { 0.5, 0.8 } }
  cart.selection_box = { { -0.8, -1.1 }, { 0.8, 1.1 } }
  cart.sticker_box = { { -0.4, -0.6 }, { 0.4, 0.6 } }
  cart.equipment_grid = nil

  -- The vanilla dust/smoke spots are placed for the vanilla car's wheels
  -- Tyre dust: vanilla's car triggers, pulled in to 80% width to sit on the cart's wheels
  cart.track_particle_triggers = narrow_offsets(util.table.deepcopy(vanilla.track_particle_triggers), DUST_WIDTH)
  cart.water_reflection = nil
  cart.light_animation = nil           -- vanilla headlight glow sprites don't fit the cart

  -- Electric motor sounds. Vanilla's car blends a driving loop and an idle loop
  -- by speed; we keep its blending and swap in our own loops. The latch click on
  -- getting in and out is played by control.lua.
  local ws = cart.working_sound
  if ws then
    local function our_sound(driving)
      return {
        filename = "__WePlayFactoryCart__/sound/" .. (driving and "motor-driving.ogg" or "motor-idle.ogg"),
        volume = driving and MOTOR_DRIVING_VOLUME or MOTOR_IDLE_VOLUME,
      }
    end
    local function first_file(snd)
      if type(snd) ~= "table" then return "?" end
      if snd.filename then return snd.filename end
      local v = snd.variations or snd[1]
      return (v and (v.filename or (v[1] and v[1].filename))) or "?"
    end
    if ws.main_sounds then
      for i, ms in pairs(ws.main_sounds) do
        local file = first_file(ms.sound)
        local driving = file:find("driving") ~= nil
        ms.sound = our_sound(driving)
      end
    elseif ws.sound then
      ws.sound = our_sound(true)
    else
      log("Factory cart: vanilla car working_sound has no main_sounds or sound; motor loops not applied")
    end
    ws.activate_sound = { filename = "__WePlayFactoryCart__/sound/motor-start.ogg", volume = MOTOR_CLICK_VOLUME }
    ws.deactivate_sound = { filename = "__WePlayFactoryCart__/sound/motor-stop.ogg", volume = MOTOR_CLICK_VOLUME }
  end

  -- The rainbow cart's paint is drawn by control.lua instead, because the game
  -- swaps a car's tint to the driver's colour whenever someone is driving.
  local layers = { cart_layer(sprites.body) }
  if not script_paint then
    layers[#layers + 1] = cart_layer(sprites.mask, { apply_runtime_tint = true })
  end
  layers[#layers + 1] = cart_layer(sprites.shadow, { draw_as_shadow = true })
  cart.animation = { layers = layers }
  return cart
end

local cart = make_cart("wp-factory-cart", "b[personal-transport]-a[car]-b[wp-factory-cart]")
local rainbow = make_cart("wp-factory-cart-rainbow", "b[personal-transport]-a[car]-c[wp-factory-cart-rainbow]", true)
data:extend({ cart, rainbow })

-- ---------------------------------------------------------------------------
-- Script-drawn overlays: rainbow paint, and the driver (once its sheets are packed)
-- ---------------------------------------------------------------------------
local function driver_anim(name, entry)
  return {
    type = "animation",
    name = name,
    filename = entry.file,
    width = entry.width,
    height = entry.height,
    shift = shift(entry),
    scale = sprites.scale,
    frame_count = 64,          -- one frame per direction; the script picks it
    line_length = 8,
    priority = "low",
  }
end

data:extend({ driver_anim("wp-factory-cart-paint", sprites.mask) })   -- rainbow paint

if sprites.driver and sprites.driver_mask then
  data:extend({
    driver_anim("wp-factory-cart-driver", sprites.driver),
    driver_anim("wp-factory-cart-driver-mask", sprites.driver_mask),
  })
end

-- ---------------------------------------------------------------------------
-- Items, recipes, technology
-- ---------------------------------------------------------------------------
local function make_item(name, order)
  return {
    type = "item-with-entity-data",
    name = name,
    icon = "__WePlayFactoryCart__/graphics/icons/" .. name:gsub("^wp%-", "") .. ".png",
    icon_size = 64,
    subgroup = "transport",
    order = order,
    place_result = name,
    stack_size = 1,
  }
end

data:extend({
  make_item("wp-factory-cart", "b[personal-transport]-a[car]-b[wp-factory-cart]"),
  make_item("wp-factory-cart-rainbow", "b[personal-transport]-a[car]-c[wp-factory-cart-rainbow]"),
  {
    type = "recipe",
    name = "wp-factory-cart",
    enabled = false,
    energy_required = 10,
    ingredients = {
      { type = "item", name = "electric-engine-unit", amount = 4 },
      { type = "item", name = "battery", amount = 10 },
      { type = "item", name = "steel-plate", amount = 10 },
      { type = "item", name = "iron-gear-wheel", amount = 10 },
    },
    results = { { type = "item", name = "wp-factory-cart", amount = 1 } },
  },
  {
    type = "recipe",
    name = "wp-factory-cart-rainbow",
    enabled = false,
    energy_required = 2,
    ingredients = {
      { type = "item", name = "wp-factory-cart", amount = 1 },
      { type = "item", name = "small-lamp", amount = 4 },
    },
    results = { { type = "item", name = "wp-factory-cart-rainbow", amount = 1 } },
  },
  {
    type = "technology",
    name = "wp-factory-cart",
    icon = "__WePlayFactoryCart__/graphics/icons/factory-cart-tech.png",
    icon_size = 256,
    prerequisites = { "automobilism", "electric-engine", "battery" },
    effects = {
      { type = "unlock-recipe", recipe = "wp-factory-cart" },
      { type = "unlock-recipe", recipe = "wp-factory-cart-rainbow" },
    },
    unit = {
      count = 150,
      ingredients = { { "automation-science-pack", 1 }, { "logistic-science-pack", 1 },
                      { "chemical-science-pack", 1 } },
      time = 30,
    },
  },
})
