%% Landslide Early Warning System (LEWS) Initialization
clear; clc; close all;
fprintf('Initializing Landslide EWS parameters...\n');
%% 1. Geotechnical & Slope Parameters (Physics Model)
p = lews_physics('params');
beta_deg = p.beta_deg;   % Slope inclination angle in degrees (35)
c_prime  = p.c_prime;    % Effective soil cohesion in kPa (12)
phi_deg  = p.phi_deg;    % Internal friction angle in degrees (30)
gamma_s  = p.gamma_s;    % Soil unit weight in kN/m^3 (18)
gamma_w  = p.gamma_w;    % Water unit weight in kN/m^3 (9.81)
z        = p.z;          % Depth of potential slip surface in meters (1.5)
%% 2. Synthetic Time Series Sensor Data (2-Hour Scenario)
% Time vector: 0 to 7200 seconds (sample every 1 second)
t = (0:1:7200)';
% Sensor A: Rainfall Rate (mm/h) - Dry at first, then a cloudburst
rain_rate = [zeros(601,1); linspace(0, 70, 1800)'; 70*ones(2400,1); linspace(70, 0, 2400)'];
% Sensor B: Volumetric Soil Moisture Content (ratio 0.10 to 0.55)
soil_moisture = min(0.18 + (cumsum(rain_rate) * 1.5e-5), 0.55);
% Sensor C: Slope Tilt Angle (degrees) - Starts stable, accelerates as soil saturates
tilt_angle = [zeros(2400,1); (0.000002 * (1:4801)'.^2)];
% Package into [time, data] arrays so Simulink can read them
rain_input  = [t, rain_rate];
moist_input = [t, soil_moisture];
tilt_input  = [t, tilt_angle];
fprintf('Done! Parameters and sensor data are ready in Workspace.\n');