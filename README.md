# 🛺⚡ WePlay: Factory Cart

![Factory Cart](thumbnail.png)

**Zip, zap, zoom!** A nimble little electric runabout for getting around your Factorio factory floor. No fuel, no guns, just quick handling and a battery that charges from your power network.

🔗 **Mod portal:** [mods.factorio.com/mod/WePlayFactoryCart](https://mods.factorio.com/mod/WePlayFactoryCart)

## ✨ Features

- 🔌 **Fully electric:** charges from any power pole it's parked or driving near. No coal, no rocket fuel, no refuelling trips.
- 🏎️ **Quick and nimble:** half the weight of the car with about the same driving force, so it gets up to speed fast and turns tight around assemblers and belt lines.
- 🕊️ **Unarmed:** a utility vehicle for getting around, not for fighting biters.
- 🎨 **Your colours:** a cart you place starts in your player colour.
- 🌈 **Rainbow cart:** a variant that cycles through pastel colours, even while you're driving it.
- 👨‍🚀 **Driver overlay:** an engineer sits behind the wheel while you drive, and the cart sits empty when parked.
- 🔊 **Electric motor sounds:** a soft servo whine at idle, an electric hum that rises with speed, and a latch click when you hop in and out.
- 🌪️ **Tyre dust** kicked up behind the wheels.

## 📊 Stats

| | Factory cart |
|---|---|
| Motor power | 350 kW |
| Battery | 10 MJ ⚙️ |
| Charge rate | up to 1 MW ⚙️ |
| Weight | half of the car |
| Cargo | 0 slots ⚙️ |
| Weapons | none |

⚙️ = adjustable in the mod settings

## ⚙️ Mod settings

Startup settings, under **Settings → Mod settings → Startup**:

| Setting | Default | Range |
|---|---|---|
| Battery capacity | 10 MJ | 10 to 50 MJ |
| Charge rate | 1 MW | 1 to 5 MW |
| Cargo slots | 0 | 0 to 50 |

## 🔬 Unlocking

Research **Factory cart** (requires Automobilism, Electric engine and Battery).

- **Factory cart:** 4 electric engine units, 10 batteries, 10 steel plates, 10 iron gear wheels
- **Rainbow factory cart:** 1 factory cart + 4 small lamps

## 📦 Installation

Install it from the in-game mod manager (search for **WePlay: Factory Cart**) or download it from the [mod portal](https://mods.factorio.com/mod/WePlayFactoryCart).

Requires **Factorio 2.1**.

## 🛠️ How it works

- **Charging:** each cart has a hidden electric energy interface that follows it and pulls up to 5 MW from the power network. The script moves that energy into the cart's burner as a hidden "battery charge" fuel, so the battery level shows as the fuel bar.
- **Charger icons:** the hidden charger has its "no power" and "no network" icons turned off, so nothing flashes when the cart drives away from your poles.
- **Rainbow paint and driver:** these are drawn by `control.lua` with `rendering.draw_animation`, because the game swaps a car's tint to the driver's colour while it's being driven. The script picks the sprite frame with the same 45° projection the game uses for rotated sprites, so the overlays stay lined up with the cart.

## 🎨 Art credits

The cart's mesh and texture were generated with AI (Tripo), then cleaned up, lit and rendered in Blender into 64-direction sprite sheets with shadow and colour-mask passes.

## 📝 License

The code is released under the [Unlicense](LICENSE), so it's in the public domain. Use it however you like.

## 🔊 Sounds

The motor sounds swap the vanilla car's idle and driving loops for electric ones, keeping the vanilla blending between them by speed. Collision sounds are vanilla.

## 💬 Feedback

Bug reports and ideas are welcome in the [Discussion tab](https://mods.factorio.com/mod/WePlayFactoryCart/discussion) on the mod portal.

## 🚙 Also by WePlay

- 🔭 **[WePlay: Observation Buggy](https://mods.factorio.com/mod/WePlayObservationBuggy):** a round scout buggy that maps the world around it as you drive, with a built-in 1 MW alternator and a 4×4 equipment grid.
- 🏭 More WePlay mods on the [mod portal](https://mods.factorio.com/user/afewvowels).
