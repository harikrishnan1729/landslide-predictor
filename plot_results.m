%% Run and Plot Simulation Results for Landslide Early Warning System
main;
% Execute Simulink model if running in interactive desktop mode
if usejava('desktop')
    try
        load_system('lews_model');
        sim('lews_model', 'StopTime', '7200');
    catch ME
        fprintf('Note: Simulink execution note (%s).\n', ME.message);
    end
end

% Extract logged signals from Dashboard Scope / simulation outputs
fprintf('Plotting simulation results...\n');
figure('Name', 'Landslide Early Warning System Dashboard', 'NumberTitle', 'off', 'Position', [100, 100, 950, 750]);

% Retrieve time
t_sim = t; 

% Subplot 1: Sensor Inputs
subplot(4,1,1);
yyaxis left;
plot(t/60, rain_rate, 'b-', 'LineWidth', 1.5);
ylabel('Rainfall (mm/h)');
ylim([0 100]);
yyaxis right;
plot(t/60, soil_moisture*100, 'm:', 'LineWidth', 1.5);
ylabel('Soil Moisture (%)');
ylim([0 70]);
title('1. Meteorological & Hydrological Monitoring');
grid on; legend({'Rain Rate', 'Soil Moisture'}, 'Location', 'northwest');

% Subplot 2: Geotechnical Factor of Safety (FoS)
subplot(4,1,2);
% Recompute or extract FoS
p_mod = lews_physics('params');
u_arr = zeros(size(soil_moisture));
fos_calc = zeros(size(soil_moisture));
for k_idx = 1:length(t)
    u_arr(k_idx) = lews_physics('pore_pressure', soil_moisture(k_idx), p_mod.theta_crit, p_mod.gamma_w, p_mod.z, p_mod.beta_deg);
    fos_calc(k_idx) = lews_physics('fos', p_mod.beta_deg, p_mod.c_prime, p_mod.phi_deg, p_mod.gamma_s, p_mod.z, u_arr(k_idx), 0);
end

plot(t/60, fos_calc, 'Color', [0.85 0.32 0.09], 'LineWidth', 1.8);
hold on;
yline(1.0, 'r:', 'Critical Limit (FoS = 1.0)', 'LineWidth', 1.5);
ylabel('FoS');
title('2. Physics Engine: Slope Stability (Factor of Safety)');
ylim([0.5 2.5]);
grid on;

% Subplot 3: Ground Kinematics (Tilt Rate)
subplot(4,1,3);
dt = 1;
tilt_diff = [0; diff(tilt_angle)] / dt * 3600; % deg/hr
plot(t/60, tilt_diff, 'k-', 'LineWidth', 1.5);
ylabel('Tilt Rate (deg/h)');
title('3. Kinematic Sensor: Ground Movement Velocity');
grid on;

% Subplot 4: Warning Level & AI Risk Index
subplot(4,1,4);
fos_risk = max(0, min(100, (1.8 - fos_calc) * 100));
kinematic_risk = min(100, tilt_diff * 20);
moist_risk = max(0, (soil_moisture - 0.25) * 250);
risk_pct = max(0, min(100, 0.4*fos_risk + 0.35*kinematic_risk + 0.25*moist_risk));

% Alert levels with hysteresis: 0=Safe, 1=Advisory, 2=Evacuate
alerts = zeros(length(t), 1);
c_state = 0;
for i = 1:length(t)
    if c_state == 0
        if risk_pct(i) >= 50 || fos_calc(i) < 1.15 || tilt_diff(i) > 3.0
            c_state = 1;
        end
    elseif c_state == 1
        if risk_pct(i) >= 80 || fos_calc(i) < 1.0 || (fos_calc(i) < 1.1 && tilt_diff(i) > 2.0)
            c_state = 2;
        elseif risk_pct(i) < 35 && fos_calc(i) > 1.3 && tilt_diff(i) < 1.0
            c_state = 0;
        end
    elseif c_state == 2
        if risk_pct(i) < 60 && fos_calc(i) > 1.25
            c_state = 1;
        end
    end
    alerts(i) = c_state;
end

stairs(t/60, alerts, 'r-', 'LineWidth', 2);
hold on;
plot(t/60, risk_pct/50, 'Color', [0.49 0.18 0.56], 'LineStyle', ':');
yticks([0 1 2]);
yticklabels({'SAFE (Green)', 'ADVISORY (Yellow)', 'EVACUATE (Red)'});
ylabel('Alert Level');
xlabel('Simulation Time (Minutes)');
title('4. Intelligent Decision Engine: Multi-tier Warning State');
grid on;

saveas(gcf, 'simulation_results.png');
fprintf('Dashboard plot saved as simulation_results.png!\n');
