-- Factory Cart runtime: battery charging, driver overlay and rainbow paint.

local CARTS = { ["wp-factory-cart"] = true, ["wp-factory-cart-rainbow"] = true }
local CHARGER = "wp-factory-cart-charger"
local CHARGE_ITEM = "wp-factory-cart-charge"
local BATTERY_J = prototypes.item[CHARGE_ITEM].fuel_value   -- set by the battery startup setting
local CHARGE_EVERY = 10           -- ticks; data.lua's buffer is sized for this
local DRIVER_ANIM = "wp-factory-cart-driver"
local DRIVER_MASK_ANIM = "wp-factory-cart-driver-mask"
local PAINT_ANIM = "wp-factory-cart-paint"
-- Overlays sit on the same "object" layer as the cart, so other carts, trees and
-- buildings in front still cover them. The tiny nudge south (about 1 pixel) makes
-- the game sort each overlay just after its own cart, so it draws on top of it.
local OVERLAY_LAYER = "object"
local OVERLAY_NUDGE = { 0, 0.02 }

-- Pastel rainbow
local RAINBOW_EVERY = 2           -- ticks between colour updates
local RAINBOW_SECONDS = 6         -- one full trip around the colour wheel
local RAINBOW_SAT = 0.55         -- higher = stronger colour, lower = more pastel
local RAINBOW_VAL = 1.0

local FILTERS = {
  { filter = "name", name = "wp-factory-cart" },
  { filter = "name", name = "wp-factory-cart-rainbow" },
}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function hsv(h, s, v, a)
  local i = math.floor(h * 6)
  local f = h * 6 - i
  local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
  local r, g, b
  i = i % 6
  if i == 0 then r, g, b = v, t, p
  elseif i == 1 then r, g, b = q, v, p
  elseif i == 2 then r, g, b = p, v, t
  elseif i == 3 then r, g, b = p, q, v
  elseif i == 4 then r, g, b = t, p, v
  else r, g, b = v, p, q end
  return { r = r, g = g, b = b, a = a }
end

-- Match the frame the game picks for the cart itself. Cars use apply_projection:
-- Factorio's camera is tilted 45 degrees, so the heading is stretched north-south
-- before picking a sprite (inverse of posila's projected_orientation).
local INV_COS45 = 1 / math.cos(math.pi / 4)
local function frame_of(car)
  local turn = car.orientation * 2 * math.pi
  local x, y = math.sin(turn), -math.cos(turn) * INV_COS45
  local projected = (math.atan2(x, -y) / (2 * math.pi)) % 1
  return math.floor(projected * 64 + 0.5) % 64
end

local function has_driver_sprites()
  return helpers.is_valid_animation_path(DRIVER_ANIM)
     and helpers.is_valid_animation_path(DRIVER_MASK_ANIM)
end

local function driver_player(car)
  local d = car.get_driver()
  if not d then return nil end
  if d.object_name == "LuaPlayer" then return d end
  return d.player
end

-- ---------------------------------------------------------------------------
-- Charger (hidden electric-energy-interface that follows the cart)
-- ---------------------------------------------------------------------------
local function make_charger(car)
  local eei = car.surface.create_entity({
    name = CHARGER, position = car.position, force = car.force,
  })
  if eei then eei.destructible = false end
  return eei
end

local function follow(rec)
  local car, eei = rec.entity, rec.charger
  if not (eei and eei.valid) or eei.surface ~= car.surface then
    if eei and eei.valid then eei.destroy() end
    rec.charger = make_charger(car)
    return
  end
  local a, b = car.position, eei.position
  if (a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 > 0.04 then eei.teleport(a) end
end

local function charge(rec)
  local burner, eei = rec.entity.burner, rec.charger
  if not (burner and eei and eei.valid) then return end

  local stored = burner.currently_burning and burner.remaining_burning_fuel or 0
  local take = math.min(BATTERY_J - stored, eei.energy)
  if take <= 0 then return end

  if not burner.currently_burning then
    burner.currently_burning = { name = CHARGE_ITEM, quality = "normal" }
  end
  burner.remaining_burning_fuel = stored + take   -- set right after, so a fresh "fuel" isn't free
  eei.energy = eei.energy - take
end

-- ---------------------------------------------------------------------------
-- Driver overlay
-- ---------------------------------------------------------------------------
local function clear_driver(rec)
  for _, key in pairs({ "driver", "driver_mask" }) do
    if rec[key] and rec[key].valid then rec[key].destroy() end
    rec[key] = nil
  end
end

local function refresh_driver(rec)
  clear_driver(rec)
  local car = rec.entity
  local player = driver_player(car)
  if not (player and has_driver_sprites()) then return end

  local frame = frame_of(car)
  local common = {
    target = { entity = car, offset = OVERLAY_NUDGE }, surface = car.surface, render_layer = OVERLAY_LAYER,
    animation_speed = 0, animation_offset = frame,
  }
  local body = { animation = DRIVER_ANIM }
  local mask = { animation = DRIVER_MASK_ANIM, tint = player.color }
  for k, v in pairs(common) do body[k] = v; mask[k] = v end

  rec.driver = rendering.draw_animation(body)
  rec.driver_mask = rendering.draw_animation(mask)
  rec.frame = frame
end

-- ---------------------------------------------------------------------------
-- Rainbow paint (drawn by script so the driver's colour can't replace it)
-- ---------------------------------------------------------------------------
local function rainbow_color(id, tick)
  local hue = (tick / (RAINBOW_SECONDS * 60) + (id % 7) / 7) % 1
  return hsv(hue, RAINBOW_SAT, RAINBOW_VAL, 1)
end

local function refresh_paint(rec)
  if rec.paint and rec.paint.valid then rec.paint.destroy() end
  rec.paint = nil
  if not rec.rainbow then return end
  local car = rec.entity
  rec.paint = rendering.draw_animation({
    animation = PAINT_ANIM, target = { entity = car, offset = OVERLAY_NUDGE },
    surface = car.surface, render_layer = OVERLAY_LAYER,
    animation_speed = 0, animation_offset = frame_of(car),
    tint = rainbow_color(car.unit_number, game.tick),
  })
end

-- Keep every overlay on the frame that matches the cart's heading
local function update_frame(rec)
  if rec.rainbow and not (rec.paint and rec.paint.valid) then refresh_paint(rec) end
  if rec.driver and not rec.driver.valid then refresh_driver(rec) end
  local frame = frame_of(rec.entity)
  if frame == rec.frame then return end
  rec.frame = frame
  for _, key in pairs({ "paint", "driver", "driver_mask" }) do
    local obj = rec[key]
    if obj and obj.valid then obj.animation_offset = frame end
  end
end

-- ---------------------------------------------------------------------------
-- Tracking
-- ---------------------------------------------------------------------------
local function track(car)
  if not (car and car.valid and CARTS[car.name]) then return end
  local id = car.unit_number
  local rec = storage.carts[id]
  if not rec then
    rec = { entity = car, rainbow = car.name == "wp-factory-cart-rainbow", phase = id % CHARGE_EVERY }
    storage.carts[id] = rec
    script.register_on_object_destroyed(car)
  end
  follow(rec)
  refresh_paint(rec)
  refresh_driver(rec)
end

local function untrack(id)
  local rec = storage.carts[id]
  if not rec then return end
  if rec.charger and rec.charger.valid then rec.charger.destroy() end
  if rec.paint and rec.paint.valid then rec.paint.destroy() end
  clear_driver(rec)
  storage.carts[id] = nil
end

local function rescan()
  storage.carts = storage.carts or {}
  for id, rec in pairs(storage.carts) do
    if not (rec.entity and rec.entity.valid) then untrack(id) end
  end
  -- remove orphaned chargers, then re-attach every cart
  for _, surface in pairs(game.surfaces) do
    for _, eei in pairs(surface.find_entities_filtered({ name = CHARGER })) do
      local owned = false
      for _, rec in pairs(storage.carts) do
        if rec.charger == eei then owned = true break end
      end
      if not owned then eei.destroy() end
    end
    for _, car in pairs(surface.find_entities_filtered({ name = { "wp-factory-cart", "wp-factory-cart-rainbow" } })) do
      track(car)
    end
  end
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
script.on_init(rescan)
script.on_configuration_changed(rescan)

local function on_built(event)
  local car = event.entity or event.destination
  track(car)
  -- A cart placed by hand starts out in that player's colour
  if event.player_index and car and car.valid and car.name == "wp-factory-cart" then
    local player = game.get_player(event.player_index)
    if player then car.color = player.color end
  end
end

script.on_event(defines.events.on_built_entity, on_built, FILTERS)
script.on_event(defines.events.on_robot_built_entity, on_built, FILTERS)
script.on_event(defines.events.on_space_platform_built_entity, on_built, FILTERS)
script.on_event(defines.events.script_raised_built, on_built, FILTERS)
script.on_event(defines.events.script_raised_revive, on_built, FILTERS)
script.on_event(defines.events.on_entity_cloned, on_built, FILTERS)

script.on_event(defines.events.on_object_destroyed, function(event)
  if event.useful_id then untrack(event.useful_id) end
end)

script.on_event(defines.events.on_player_driving_changed_state, function(event)
  local car = event.entity
  if car and car.valid and CARTS[car.name] then
    car.surface.play_sound({ path = "wp-factory-cart-latch", position = car.position })
    local rec = storage.carts[car.unit_number]
    if rec then refresh_driver(rec) else track(car) end
  end
end)

script.on_event(defines.events.on_tick, function(event)
  local tick = event.tick
  local rainbow_tick = tick % RAINBOW_EVERY == 0

  for id, rec in pairs(storage.carts) do
    local car = rec.entity
    if not (car and car.valid) then
      untrack(id)
    else
      update_frame(rec)
      if tick % CHARGE_EVERY == rec.phase then
        follow(rec)
        charge(rec)
      end
      if rainbow_tick and rec.paint and rec.paint.valid then
        rec.paint.color = rainbow_color(id, tick)
      end
    end
  end
end)
