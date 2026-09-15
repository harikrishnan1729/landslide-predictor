# GeoGuard: Predictive Landslide Early Warning System (LEWS) v2.0



An authoritative, geotechnically-coupled Landslide Early Warning System (LEWS) combining limit equilibrium mechanics, physical infiltration hydrology, real-time kinematic telemetry, machine learning inference, and an interactive command dashboard in MATLAB.



---



## 1. System Architecture & Core Modules



- lews_physics.m: Authoritative single source of truth for all geotechnical and hydrological physics equations.

- predictive_dashboard.m: Interactive graphical command console with dynamic mountain cross-section, real-time 4-panel telemetry, live ML prediction, and time-accelerated storm playback.

- train_model.m: Synthesizes 12,000 physically-coupled storm trajectories across the full parameter space and trains landslide_model.mat.

- landslide_model.mat: Calibrated multi-class decision tree classifier predicting Safe (0), Advisory (1), or Evacuate (2) with 99.96% holdout accuracy.

- run_tests.m: Automated test suite covering FoS exactness, mass conservation, storm duration scaling, hysteresis, and ML inference.

- main.m: Synthesizes 2-hour sensor timeseries with harmonized baseline parameters (35 deg slope, 12 kPa cohesion).

- plot_results.m: Generates publication-grade telemetry report (simulation_results.png).

- build_simulink_model.m / lews_model.slx: Simulink block diagram implementation for continuous-time signal routing.



---



## 2. Mathematical Formulation



1. Hydrology & Mass Conservation:

   Delta_theta_infil = (Irain * dt_phys * 0.85) / (z * 1000)

   Delta_theta_drain = (kdrain * max(0, theta - theta_field) * dt_phys) / z

   theta_{t1 } = min(theta_sat, max(0.12, theta_t0 + Delta_theta_infil - Delta_theta_drain))



2. Pore-Water Pressure (u):

   u = gamma_w * z * cos(beta)[2] * ((theta - theta_crit) / (theta_sat - theta_crit)) * 1.8   (if theta > theta_crit)



3. Limit Equilibrium Factor of Safety (FoS):

   Normal Stress sigma = gamma_s * z * (cos(beta) - kh * sin(beta)) * cos(beta)

   Effective Stress sigma' = max(sigma - u, 0.05)

   Resisting Shear tau_f = c_prime + sigma' * tan(phi)

   Driving Shear tau_d = gamma_s * z * (sin(beta) + kh * cos(beta)) * cos(beta)

   FoS = tau_f / tau_d



   Baseline Nominal: beta = 35 deg, _cprime = 12 kPa, phi = 30 deg, gamma_s = 18 kN/m^3, z = 1.5 m --> FoS = 1.7705



4. Kinematics & Plastic Deformation:

   Tertiary creep acceleration with pseudostatic seismic tremor fork (kh = 0.015 * tremor).

   Plastic slip offset only accumulates during failure (FoS < 1.05) and does not reverse during dry weather.



---



## 3. Key Issues Resolved in v2.0



1. **Hydrological Time Decoupling**: Animation step (0.2s) is decoupled from physical storm clock (dt_phys = (Dur_hr * 3600) / 75). A 12-min vs 12-hr storm now produces significantly differentiated saturation and FoS (1.770 vs 0.982).

2. **Exact Cumulative Rainfall**: A 75 mm/h storm over 3 hours accumulates exactly 225.0 mm (previously recorded only 0.31 mm).

3. **Off-by-One Termination Fixed**: Storm rainfall remains active through step 75 and is shut off only after the final step is processed.

4. **Step-0 Initial FoS Consistency**: Dashboard state initializes to exact physical FoS (1.7705), preventing initial dFoS derivative spikes that previously caused a false collapse to 0.10.

5. **Harmonized Forecast Horizon & TTF**: Forecasting horizon is aligned with mathematical 10-minute projection (600 seconds). Stable states report NaN (no failure predicted) instead of magic 999 minutes.

6. **Schmitt Trigger Hysteresis**: Evacuate (2) requires recovery past FoS > 1.15 and tilt < 1.8 to de-escalate. Advisory (1) requires recovery past FoS > 1.48, rain < 20 mm/h, and moisture < 23% to return to Safe (0).

7. **Machine Learning Model Integration**: Decision tree classifier retrained on 12,000 causally-coupled scenarios achieving 99.96% holdout accuracy. Live feature vector [FoS, moisture%, RainRate, TiltRate] evaluated in real-time.



---



## 4. How to Run



1. Interactive Dashboard:

   `ppredictive_dashboard``



2. Automated Test Suite:

   ``run_tests``

   Output: 6 / 6 TESTS PASSED SUCCESSFULLY!



3. Retrain Machine Learning Model:

   ``train_model``



4. Generate Simulation Plot:

   ``plot_results``

