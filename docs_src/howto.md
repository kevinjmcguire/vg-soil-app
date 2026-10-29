### Using the app for the soil water homework

1. **Texture:** set *Sand (%)* and *Clay (%)* from your soil description. Silt and the USDA texture class are filled in automatically.
2. **Bulk density:** leave *Use bulk density* checked and type the bulk density you calculated from the soil core (g cm⁻³). Rosetta then uses your soil's actual packing, not just its texture.
3. **Water content:** type the field volumetric water content, θ, you calculated from the core. Type it exactly; there is no slider to round to.
4. **Read the results** in the boxes at the top, or in the *Properties table* tab:
   * **Field capacity** and **wilting point:** water contents at −33 kPa and −1500 kPa.
   * **Hydraulic conductivity at your θ.** Compare it with *Ks*: unsaturated K is often orders of magnitude smaller.
   * **Suction (matric potential) at your θ,** reported in mm, cm, and kPa.
   * **Approximate air-entry suction, 1/α.** On the retention graph it is the orange dotted line, where the curve starts to bend away from saturation.
5. **Units matter.** Check what units the question asks for. The table gives suction in mm, cm, and kPa, and K in mm/hr, cm/day, and mm/s.

### Things to try

* Move the clay slider and watch how the retention curve and K change. Which soil holds more water at field capacity? Which drains faster?
* Untick *Use bulk density* to see how much the estimate depends on packing.
* Look at the shaded uncertainty band. How confident should you be in a hydraulic property estimated only from texture?
* Switch the K model to *Rosetta K₀ and L* and compare K at your θ.
* Open *Custom van Genuchten parameters* and change *n* or *α* to see what each parameter controls.
