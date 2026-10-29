### Water retention: van Genuchten (1980)

Suction $h$ is positive (cm of water); matric potential $\psi = -h$. Effective saturation and water content are

$$S_e = \frac{\theta - \theta_r}{\theta_s - \theta_r} = \left[1 + (\alpha h)^n\right]^{-m}, \qquad m = 1 - \frac{1}{n}$$

$$\theta(h) = \theta_r + (\theta_s - \theta_r)\left[1 + (\alpha h)^n\right]^{-m}$$

Inverting gives the suction at a known water content:

$$h(\theta) = \frac{1}{\alpha}\left(S_e^{-1/m} - 1\right)^{1/n}$$

| Parameter | Meaning |
|---|---|
| $\theta_r$ | residual water content: water held so tightly it does not drain |
| $\theta_s$ | saturated water content: close to, but usually a little less than, total porosity |
| $\alpha$ (1/cm) | related to the inverse of the air-entry suction; larger in coarse soils |
| $n$ | pore-size distribution: larger $n$ means a narrow range of pore sizes and a sharper drop in $\theta$ |

**Air-entry suction.** The van Genuchten curve has no sharp air-entry point (unlike Brooks–Corey or Clapp–Hornberger). The value $1/\alpha$ is used as an approximate air-entry suction: it marks where the curve begins to bend and drain noticeably.

### Unsaturated hydraulic conductivity: Mualem (1976) with van Genuchten

$$K(S_e) = K_0 S_e^{L}\left[1 - \left(1 - S_e^{1/m}\right)^m\right]^2$$

* **Classic Mualem–van Genuchten (default):** $K_0 = K_s$ and $L = 0.5$.
* **Rosetta $K_0$ and $L$:** Schaap & Leij (2000) fitted $K_0$ and $L$ to measured unsaturated conductivity data. These usually describe unsaturated $K$ better than extrapolating from $K_s$, but $K$ at saturation then differs from $K_s$.

### Pedotransfer functions: Rosetta3

The parameters $\theta_r, \theta_s, \alpha, n,$ and $K_s$ come from **Rosetta3** (Schaap et al., 2001; Zhang & Schaap, 2017). Rosetta is an ensemble of 1,000 bootstrap-trained neural networks.

* **Model 2** uses sand, silt, and clay.
* **Model 3** adds bulk density.

The value reported is the mean of the ensemble. The shaded band on the curves spans the 5th–95th percentiles of the 1,000 predictions. It shows how uncertain an estimate from texture alone really is.

This app's R code reproduces the USDA-ARS `rosetta-soil` package (v0.3.2) to machine precision (see `tests/`).

### Water-holding points

* **Field capacity:** $\theta$ at $-33$ kPa (330 cm suction) by default. The $-10$ kPa option is often used for sandy soils.
* **Permanent wilting point:** $\theta$ at $-1500$ kPa (15,300 cm suction).
* **Plant-available water** = field capacity − wilting point.

### Units

$1\ \text{kPa} = 10.197$ cm of water = 101.97 mm of water; 1 cm/day = 0.4167 mm/hr.

### References

* Mualem, Y. (1976). A new model for predicting the hydraulic conductivity of unsaturated porous media. *Water Resources Research* 12:513–522.
* Schaap, M.G., Leij, F.J. (2000). Improved prediction of unsaturated hydraulic conductivity with the Mualem–van Genuchten model. *Soil Sci. Soc. Am. J.* 64:843–851.
* Schaap, M.G., Leij, F.J., van Genuchten, M.Th. (2001). ROSETTA: a computer program for estimating soil hydraulic parameters with hierarchical pedotransfer functions. *J. Hydrology* 251:163–176.
* van Genuchten, M.Th. (1980). A closed-form equation for predicting the hydraulic conductivity of unsaturated soils. *Soil Sci. Soc. Am. J.* 44:892–898.
* Zhang, Y., Schaap, M.G. (2017). Weighted recalibration of the Rosetta pedotransfer model with improved estimates of hydraulic parameter distributions and summary statistics (Rosetta3). *J. Hydrology* 547:39–53.
