# PlySolver — Theory reference

Compact summary of the formulation implemented in `src/+clpt`. Notation and
sign conventions follow R.M. Jones, *Mechanics of Composite Materials*,
2nd ed. (1999). Units: MPa, mm, N, °C.

## 1. Conventions

- Ply 1 is the **top** ply; the stack is listed top → bottom.
- Through-thickness coordinate: $z(1) = +h/2$ at the top surface, decreasing
  downwards; $z_k$ is the top of ply $k$ and $z_{k+1}$ its bottom.
- $\theta$ is the fibre angle measured CCW from the laminate $x$ axis.
- Compressive strengths $X_c, Y_c$ are handled as **positive magnitudes**.

## 2. Lamina stiffness

Plane-stress reduced stiffness in the material frame (1 = fibres):

$$Q_{11}=\frac{E_1}{1-\nu_{12}\nu_{21}},\quad Q_{22}=\frac{E_2}{1-\nu_{12}\nu_{21}},\quad Q_{12}=\frac{\nu_{12}E_2}{1-\nu_{12}\nu_{21}},\quad Q_{66}=G_{12},\quad \nu_{21}=\nu_{12}\frac{E_2}{E_1}$$

Off-axis (global-frame) stiffness $\bar{Q}(\theta)$ with $m=\cos\theta$, $n=\sin\theta$ (Jones Eq. 2.85):

$$\bar{Q}_{11}=Q_{11}m^4+2(Q_{12}+2Q_{66})m^2n^2+Q_{22}n^4 \quad\text{etc.}$$

Stress and engineering-strain transformations (global → material):

$$T_\sigma=\begin{bmatrix}m^2&n^2&2mn\\n^2&m^2&-2mn\\-mn&mn&m^2-n^2\end{bmatrix},\qquad T_\varepsilon=\begin{bmatrix}m^2&n^2&mn\\n^2&m^2&-mn\\-2mn&2mn&m^2-n^2\end{bmatrix}$$

with the identities $T^{-1}(\theta)=T(-\theta)$ and $T_\varepsilon=(T_\sigma^{-1})^{\mathsf T}$
(verified in the tests). A generally anisotropic stiffness (e.g. the laminate
[A] with $A_{16}\neq0$) is rotated exactly as
$M'=T_\sigma(\theta)\,M\,T_\varepsilon(-\theta)$ — used for the polar plot
$E_x(\theta)=1/(a'_{11}h)$.

## 3. Laminate stiffness (CLPT)

$$A_{ij}=\sum_{k=1}^{n}\bar{Q}_{ij}^{(k)}\,(z_k-z_{k+1}),\qquad
B_{ij}=\frac12\sum_{k=1}^{n}\bar{Q}_{ij}^{(k)}\,(z_k^2-z_{k+1}^2),\qquad
D_{ij}=\frac13\sum_{k=1}^{n}\bar{Q}_{ij}^{(k)}\,(z_k^3-z_{k+1}^3)$$

$$\begin{Bmatrix}N\\M\end{Bmatrix}=\begin{bmatrix}A&B\\B&D\end{bmatrix}\begin{Bmatrix}\varepsilon^0\\\kappa\end{Bmatrix}$$

Apparent engineering constants, with $a=A^{-1}$ and $d=D^{-1}$:

$$E_x=\frac{1}{a_{11}h},\quad E_y=\frac{1}{a_{22}h},\quad G_{xy}=\frac{1}{a_{66}h},\quad \nu_{xy}=-\frac{a_{12}}{a_{11}},\qquad E_{x,b}=\frac{12}{d_{11}h^3},\ \dots$$

Layup diagnostics: symmetric ⇔ $B=0$; balanced ⇔ $A_{16}=A_{26}=0$;
no bend–twist coupling ⇔ $D_{16}=D_{26}=0$.

## 4. Thermo-mechanical response

Ply CTEs in the global frame (engineering shear):

$$\alpha_x=\alpha_1 m^2+\alpha_2 n^2,\qquad \alpha_y=\alpha_1 n^2+\alpha_2 m^2,\qquad \alpha_{xy}=2(\alpha_1-\alpha_2)mn$$

Fictitious thermal loads for a uniform $\Delta T$:

$$N^T=\Delta T\sum_k\bar{Q}^{(k)}\alpha^{(k)}(z_k-z_{k+1}),\qquad
M^T=\frac{\Delta T}{2}\sum_k\bar{Q}^{(k)}\alpha^{(k)}(z_k^2-z_{k+1}^2)$$

Solution and ply stress recovery at $z\in\{z_k, z_{k+1}\}$:

$$\begin{Bmatrix}\varepsilon^0\\\kappa\end{Bmatrix}=\mathrm{ABBD}^{-1}\begin{Bmatrix}N+N^T\\M+M^T\end{Bmatrix},\qquad
\varepsilon^{tot}(z)=\varepsilon^0+z\kappa,\qquad
\varepsilon^{mech}=\varepsilon^{tot}-\Delta T\,\alpha,\qquad
\sigma=\bar{Q}\,\varepsilon^{mech}$$

Physical checks used in the tests: free expansion of a UD laminate gives
$\sigma\equiv0$; symmetric laminates give $M^T=0,\ \kappa=0$; and
$\int_h \sigma\,dz = N$ (equilibrium).

## 5. First-ply failure

All criteria act on the material-frame stresses $(\sigma_1,\sigma_2,\tau_{12})$.

**Tsai-Wu** (plane stress, $F_{12}^*=-\tfrac12$):

$$FI=F_1\sigma_1+F_2\sigma_2+F_{11}\sigma_1^2+F_{22}\sigma_2^2+F_{66}\tau_{12}^2+2F_{12}\sigma_1\sigma_2$$

$$F_1=\frac{1}{X_t}-\frac{1}{X_c},\quad F_{11}=\frac{1}{X_tX_c},\quad F_2=\frac{1}{Y_t}-\frac{1}{Y_c},\quad F_{22}=\frac{1}{Y_tY_c},\quad F_{66}=\frac{1}{S^2},\quad F_{12}=-\frac12\sqrt{F_{11}F_{22}}$$

The strength ratio (FOS) $R$ solves $aR^2+bR=1$ where $a$ collects the
quadratic and $b$ the linear terms: $R=\dfrac{-b+\sqrt{b^2+4a}}{2a}$.

**Tsai-Hill** (with $X,Y$ switched to the compressive values when the
corresponding stress is negative): $FI=(\sigma_1/X)^2-\sigma_1\sigma_2/X^2+(\sigma_2/Y)^2+(\tau_{12}/S)^2$, $R=1/\sqrt{FI}$.

**Max Stress**: $FI=\max(|\sigma_1|/X,\ |\sigma_2|/Y,\ |\tau_{12}|/S)$, $R=1/FI$.

## 6. Sizing of symmetric balanced laminates

For membrane loads $N=[N_x,N_y,N_{xy}]$ and the 0/±45/90 family:

1. **Proportions** $p=[p_0,p_{90},p_{45},p_{-45}]$: quasi-isotropic (25% each)
   or from Mohr's circle of the loads — $p_0\propto|N_1|$, $p_{90}\propto|N_2|$,
   $p_{\pm45}\propto R$ each (shear ⇔ $2R$ total), clipped to a 10% minimum and
   renormalised.
2. **Smeared stiffness** at unit thickness $A^*=\sum_k p_k\bar{Q}(\theta_k)$;
   mid-plane strains at the reference thickness $h=1$ mm:
   $\varepsilon^0=A^{*-1}N$. Since ply stresses scale as $1/h$:
   - Tsai-Hill ($FI\propto1/h^2$): $h_{min}=\sqrt{FI_{ref}}\cdot SF$
   - Max Stress ($FI\propto1/h$): $h_{min}=FI_{ref}\cdot SF$
3. **Discretisation**: ply counts for half the laminate from the proportions
   (+45/−45 kept equal → balanced; half mirrored → symmetric).
4. **Verification loop**: the actual discretised laminate is solved with the
   full CLPT machinery; if $\min(FOS)<SF$, plies are added and the check is
   repeated. The delivered layup therefore always satisfies the requested
   safety factor.
