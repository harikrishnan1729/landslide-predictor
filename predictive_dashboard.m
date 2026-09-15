function varargout = predictive_dashboard()
%% GEOGUARD v2.0: Predictive Landslide Early Warning & Graphical Command Center
% Featuring:
% 1. Dynamic Physical Mountain Cross-Section (slope angle changes visually with slider)
% 2. 4 Detailed Telemetry & Forecasting Graphs (Rain, Moisture, FoS Prediction, Alerts)
% 3. Automated 15-to-30 Minute Advance Disaster Prediction
% 4. One-Click Reset Button & Quick Cloudburst Simulation Button
close all;

fprintf('Launching Enhanced GeoGuard Predictive Command Center v2.0...\n');

% -------------------------------------------------------------
% SIMULATION STATE (Scoped across all nested functions)
% -------------------------------------------------------------
state = struct();
init_state();

function init_state()
    p = lews_physics('params');
    state.p = p;
    state.rain = 0;               % mm/h
    state.cum_rain = 0;           % mm
    state.beta = p.beta_deg;      % degrees (35)
    state.c_prime = p.c_prime;    % kPa (12)
    state.moist = p.theta_field;  % 18% volumetric water content
    state.pore_pressure = lews_physics('pore_pressure', state.moist); % 0 kPa
    state.manual_tilt = 0;        % deg/h
    init_fos = lews_physics('fos', state.beta, state.c_prime, p.phi_deg, p.gamma_s, p.z, state.pore_pressure, 0);
    state.tilt_rate = lews_physics('kinematics', init_fos, 0);
    state.fos = init_fos;         % exact physics-derived initial factor of safety (~1.77)
    state.prev_fos = init_fos;    % previous factor of safety
    state.dfos_dt = 0;            % filtered rate of change of FoS
    state.fos_pred = init_fos;    % 10-min predicted factor of safety
    state.time_to_collapse = NaN; % NaN when slope is stable (eliminating fake 999)
    state.alert_level = 0;        % 0=Safe, 1=Advisory, 2=Evacuate
    state.sim_time = 0;           % seconds
    state.slip_offset = 0;        % physical slide displacement for graphics

    % Load trained machine-learning model if available
    state.ml_model = [];
    state.ml_prob_alert = 0;
    if exist('landslide_model.mat', 'file')
        try
            ml_data = load('landslide_model.mat');
            if isfield(ml_data, 'model')
                state.ml_model = ml_data.model;
            elseif isfield(ml_data, 'mdl')
                state.ml_model = ml_data.mdl;
            end
        catch
        end
    end

    % Accelerated Storm Simulation & Prediction State
    state.storm_active = false;
    state.storm_rain = 0;
    state.storm_dur_hr = 0;
    state.storm_step_count = 0;
    state.storm_total_steps = 75;
    state.storm_min_fos = init_fos;
    state.storm_collapse_hr = -1;

    % History buffers for high-detail plotting (150 time steps)
    BUF_LEN = 150;
    state.history_t = zeros(1, BUF_LEN);
    state.history_rain = zeros(1, BUF_LEN);
    state.history_cum_rain = zeros(1, BUF_LEN);
    state.history_moist = (state.moist * 100) * ones(1, BUF_LEN);
    state.history_u = zeros(1, BUF_LEN);
    state.history_fos = init_fos * ones(1, BUF_LEN);
    state.history_fos_pred = init_fos * ones(1, BUF_LEN);
    state.history_tilt = state.tilt_rate * ones(1, BUF_LEN);
    state.history_alert = zeros(1, BUF_LEN);
end

% -------------------------------------------------------------
% CREATE WIDESCREEN COMMAND CENTER WINDOW
% -------------------------------------------------------------
f = figure('Name', 'GeoGuard v2.0 - Predictive Landslide Command Console', ...
    'Color', [0.98 0.97 0.94], 'Position', [40, 20, 1260, 790], ...
    'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', ...
    'CloseRequestFcn', @onClose);

% Top Header Bar
p_top = uipanel('Parent', f, 'Units', 'normalized', 'Position', [0.015, 0.925, 0.97, 0.065], ...
    'BackgroundColor', [0.96 0.87 0.70], 'BorderType', 'none');

uicontrol('Style', 'text', 'Parent', p_top, 'Units', 'normalized', ...
    'Position', [0.02, 0.15, 0.55, 0.70], 'HorizontalAlignment', 'left', ...
    'String', 'GEOGUARD-PREDICTIVE LANDSLIDE EARLY WARNING & TELEMETRY CONSOLE', ...
    'FontSize', 13, 'FontWeight', 'bold', 'ForegroundColor', [0.10 0.20 0.50], ...
    'BackgroundColor', [0.96 0.87 0.70]);

% Top Action Buttons: Reset & Cloudburst Test
uicontrol('Style', 'pushbutton', 'Parent', p_top, 'Units', 'normalized', ...
    'Position', [0.68, 0.12, 0.14, 0.76], 'String', 'SIMULATE STORM', ...
    'FontSize', 10, 'FontWeight', 'bold', 'ForegroundColor', [1 1 1], ...
    'BackgroundColor', [0.18 0.45 0.75], 'Callback', @(~,~) triggerCloudburst());

uicontrol('Style', 'pushbutton', 'Parent', p_top, 'Units', 'normalized', ...
    'Position', [0.83, 0.12, 0.15, 0.76], 'String', 'RESET SYSTEM', ...
    'FontSize', 10, 'FontWeight', 'bold', 'ForegroundColor', [1 1 1], ...
    'BackgroundColor', [0.15 0.60 0.35], 'Callback', @(~,~) resetSystem());

% Main Emergency Status Banner
p_banner = annotation(f, 'textbox', ...
    [0.015, 0.850, 0.97, 0.065], ...
    'String', sprintf('STATUS: NOMINAL  |  SLOPE STABLE (FoS = %.2f)  |  NO FAILURE PREDICTED', state.fos), ...
    'FontSize', 13, ...
    'FontWeight', 'bold', ...
    'Color', [1 1 1], ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'EdgeColor', 'none', ...
    'BackgroundColor', [0.12 0.50 0.22]);

% -------------------------------------------------------------
% LEFT SECTION: REALISTIC PHYSICAL HILLSIDE & STRATIGRAPHY
% -------------------------------------------------------------
p_geo = uipanel('Parent', f, 'Units', 'normalized', 'Position', [0.015, 0.23, 0.38, 0.61], ...
    'BackgroundColor', [0.96 0.90 0.78], 'ForegroundColor', [0.15 0.15 0.20], ...
    'Title', 'REAL-TIME PHYSICAL HILLSIDE DEFORMATION & STRATIGRAPHY', 'FontWeight', 'bold');

ax_geo = axes('Parent', p_geo, 'Units', 'normalized', 'Position', [0.03, 0.05, 0.94, 0.91], ...
    'Color', [0.86 0.92 0.98]);
hold(ax_geo, 'on');

% 1. Dynamic Atmospheric Sky Backdrop
h_sky = patch(ax_geo, [0 10 10 0], [0 0 7.5 7.5], [0.86 0.92 0.98], 'EdgeColor', 'none');

% Dynamic Rain Animation Streaks (24 raindrops falling across sky when rain > 0)
N_rain = 24;
rain_x = linspace(0.5, 9.5, N_rain) + rand(1, N_rain)*0.3;
rain_y = 3.5 + 3.5 * rand(1, N_rain);
h_rain_streaks = gobjects(1, N_rain);
for r_i = 1:N_rain
    h_rain_streaks(r_i) = plot(ax_geo, [rain_x(r_i), rain_x(r_i)-0.15], [rain_y(r_i), rain_y(r_i)-0.45], ...
        'Color', [0.30 0.50 0.80 0.55], 'LineWidth', 1.2, 'Visible', 'off');
end

% 2. Stratified Bedrock Stratum (Deep Impermeable Geological Foundation)
h_bedrock = patch(ax_geo, [0 10 10 0], [0 0 2 0.5], [0.38 0.40 0.43], 'EdgeColor', [0.28 0.30 0.33], 'LineWidth', 1.5);
h_bedrock_joints = plot(ax_geo, [0 10], [0.3 1.2], 'Color', [0.30 0.32 0.35], 'LineWidth', 1.0, 'LineStyle', '--');

% 3. Bishop Circular Geotechnical Shear Slip Surface
h_slip_line = plot(ax_geo, [0 10], [1 3], 'r--', 'LineWidth', 2.5);

% 4. Colluvium Soil Mantle (Changes color: Lush Green -> Saturated Amber -> Failure Red)
h_soil = patch(ax_geo, [0 10 10 0], [1 3 6 2], [0.30 0.58 0.28], 'EdgeColor', [0.20 0.42 0.20], 'LineWidth', 1.5);

% 5. Lush Alpine Grass Surface Contour Line
h_grass_line = plot(ax_geo, [0 10], [2 6], 'Color', [0.15 0.45 0.15], 'LineWidth', 3.0);

% 6. Dynamic Groundwater Phreatic Seepage Line (Cyan line with toe seep)
h_water_table = plot(ax_geo, [0 10], [0.8 2.0], 'Color', [0.00 0.75 1.00], 'LineStyle', '-.', 'LineWidth', 2.5);
h_toe_seep = plot(ax_geo, 0.4, 1.2, 'o', 'MarkerFaceColor', [0.0 0.65 0.95], 'MarkerEdgeColor', [0.0 0.3 0.7], 'MarkerSize', 7, 'Visible', 'off');

% 7. Alpine Mountain Settlement (House with pitched roof on terrace)
h_house_base = patch(ax_geo, [2.0 2.8 2.8 2.0], [2.2 2.2 2.0 2.0], [0.55 0.55 0.58], 'EdgeColor', [0.3 0.3 0.3]);
h_house_body = patch(ax_geo, [2.05 2.75 2.75 2.05], [2.8 2.8 2.2 2.2], [0.72 0.48 0.28], 'EdgeColor', [0.45 0.28 0.15]);
h_house_roof = patch(ax_geo, [1.95 2.40 2.85], [2.8 3.25 2.8], [0.78 0.22 0.18], 'EdgeColor', [0.5 0.1 0.1]);
h_house_win = plot(ax_geo, 2.40, 2.55, 's', 'MarkerFaceColor', [0.98 0.92 0.55], 'MarkerEdgeColor', [0.4 0.3 0.1], 'MarkerSize', 6);

% 8. Realistic Evergreen Pine Trees (Trunks and triangular foliage)
tree_x = [3.2, 5.0, 6.8, 8.4];
N_trees = length(tree_x);
h_tree_trunks = gobjects(1, N_trees);
h_tree_canopies = gobjects(1, N_trees);
for t_idx = 1:N_trees
    h_tree_trunks(t_idx) = plot(ax_geo, [tree_x(t_idx), tree_x(t_idx)], [4, 4.5], 'Color', [0.42 0.26 0.14], 'LineWidth', 3.5);
    h_tree_canopies(t_idx) = patch(ax_geo, [tree_x(t_idx)-0.35, tree_x(t_idx), tree_x(t_idx)+0.35], ...
        [4.4, 5.2, 4.4], [0.12 0.40 0.18], 'EdgeColor', [0.08 0.28 0.12], 'LineWidth', 1.0);
end

% 9. Telemetry Monitoring Station (Lattice mast + solar panel + flashing beacon)
h_sensor_mast = plot(ax_geo, [5.4 5.4], [4.4 5.2], 'Color', [0.25 0.30 0.35], 'LineWidth', 2.5);
h_sensor_solar = patch(ax_geo, [5.15 5.65 5.65 5.15], [4.85 4.95 4.8 4.7], [0.10 0.25 0.55], 'EdgeColor', [0.8 0.8 0.9]);
h_sensor_beacon = plot(ax_geo, 5.4, 5.25, 'o', 'MarkerFaceColor', [0.0 0.8 0.2], 'MarkerEdgeColor', [0.0 0.5 0.1], 'MarkerSize', 6);

% 10. Tension Crown Crack at Slope Crest
h_crown_crack = plot(ax_geo, [8.8 8.9 8.7 8.9], [5.5 5.2 4.9 4.6], 'Color', [0.85 0.10 0.10], ...
    'LineWidth', 2.8, 'Visible', 'off');

% 11. Catastrophic Slide Vector Arrow
h_slide_arrow = annotation('arrow', [0.24 0.18], [0.42 0.34], 'Color', [1 0.2 0.2], 'LineWidth', 3.5, 'Visible', 'off');

% 12. Geological Annotations & Callouts
txt_lbl_crown = text(ax_geo, 8.1, 7.1, '[ CROWN / SCARP ]', 'Color', [0.45 0.15 0.15], 'FontSize', 8, 'FontWeight', 'bold');
txt_lbl_slip = text(ax_geo, 5.4, 1.8, 'Shear Slip Arc (Bishop)', 'Color', [0.75 0.10 0.10], 'FontSize', 8, 'FontWeight', 'bold');
txt_lbl_water = text(ax_geo, 1.0, 1.5, 'Phreatic Water Table', 'Color', [0.00 0.45 0.80], 'FontSize', 8, 'FontWeight', 'bold');
txt_lbl_chalet = text(ax_geo, 1.8, 3.45, 'Mountain Settlement', 'Color', [0.35 0.20 0.10], 'FontSize', 8, 'FontWeight', 'bold');

% 13. High-Clarity Heads-Up Display (HUD) Box on Top-Left
h_hud_bg = patch(ax_geo, [0.2 4.6 4.6 0.2], [5.5 5.5 7.35 7.35], [1.0 1.0 1.0], ...
    'FaceAlpha', 0.90, 'EdgeColor', [0.75 0.70 0.60], 'LineWidth', 1.2);
txt_hud_title = text(ax_geo, 0.4, 7.05, 'GEOTECHNICAL TELEMETRY HUD', ...
    'Color', [0.10 0.20 0.45], 'FontSize', 8.5, 'FontWeight', 'bold');
txt_hud_slope = text(ax_geo, 0.4, 6.65, sprintf('Terrain Slope: %.0f°', state.beta), ...
    'Color', [0.20 0.20 0.25], 'FontSize', 8.0, 'FontWeight', 'bold');
txt_hud_moist = text(ax_geo, 0.4, 6.30, sprintf('Moisture: %.1f%%  |  Pore Press: %.1f kPa', state.moist*100, state.pore_pressure), ...
    'Color', [0.05 0.40 0.70], 'FontSize', 8.0);
txt_hud_fos = text(ax_geo, 0.4, 5.95, sprintf('Stability FoS: %.2f  [SAFE]', state.fos), ...
    'Color', [0.10 0.50 0.20], 'FontSize', 8.5, 'FontWeight', 'bold');
txt_hud_ml = text(ax_geo, 0.4, 5.65, 'AI Prediction: 0.1% Risk [Safe]', ...
    'Color', [0.45 0.20 0.60], 'FontSize', 8.0);

xlim(ax_geo, [0 10]); ylim(ax_geo, [0 7.5]);
ax_geo.XTick = []; ax_geo.YTick = [];

% -------------------------------------------------------------
% RIGHT SECTION: 4 DETAILED TELEMETRY & FORECASTING GRAPHS (2x2)
% -------------------------------------------------------------
p_graphs = uipanel('Parent', f, 'Units', 'normalized', 'Position', [0.405, 0.23, 0.58, 0.61], ...
    'BackgroundColor', [0.96 0.90 0.78], 'ForegroundColor', [0.15 0.15 0.20], ...
    'Title', 'DETAILED EARLY WARNING SENSOR & FORECASTING TELEMETRY', 'FontWeight', 'bold');

% GRAPH 1 (Top-Left): Rain Rate & Cumulative Rain
ax1 = axes('Parent', p_graphs, 'Units', 'normalized', 'Position', [0.075, 0.545, 0.415, 0.395], ...
    'Color', [1.0 1.0 1.0], 'XColor', [0.20 0.20 0.20], 'YColor', [0.20 0.20 0.20]);
yyaxis(ax1, 'left');
h_g1_rain = plot(ax1, state.history_t, state.history_rain, 'Color', [0.05 0.45 0.85], 'LineWidth', 1.8);
ylabel(ax1, 'Rain (mm/h)'); ylim(ax1, [0 100]);
ax1.YColor = [0.05 0.45 0.85];
yyaxis(ax1, 'right');
h_g1_cum = plot(ax1, state.history_t, state.history_cum_rain, 'Color', [0.80 0.55 0.05], 'LineWidth', 1.5, 'LineStyle', ':');
ylabel(ax1, 'Total (mm)');
ax1.YColor = [0.80 0.55 0.05];
title(ax1, '1. Meteorological Trigger (Rate & Total)', 'Color', [0.15 0.15 0.20], 'FontSize', 9);
legend(ax1, [h_g1_rain, h_g1_cum], {'Rain Rate (mm/h)', 'Cumulative (mm)'}, ...
    'TextColor', [0.15 0.15 0.20], 'FontSize', 7.5, 'FontWeight', 'bold', ...
    'Location', 'northwest', 'Box', 'off', 'Color', 'none');
grid(ax1, 'on'); ax1.GridColor = [0.80 0.80 0.80];

% GRAPH 2 (Top-Right): Soil Moisture & Pore Water Pressure
ax2 = axes('Parent', p_graphs, 'Units', 'normalized', 'Position', [0.555, 0.545, 0.415, 0.395], ...
    'Color', [1.0 1.0 1.0], 'XColor', [0.20 0.20 0.20], 'YColor', [0.20 0.20 0.20]);
yyaxis(ax2, 'left');
h_g2_moist = plot(ax2, state.history_t, state.history_moist, 'Color', [0.10 0.60 0.20], 'LineWidth', 1.8);
ylabel(ax2, 'Moisture (%)'); ylim(ax2, [10 65]);
ax2.YColor = [0.10 0.60 0.20];
yyaxis(ax2, 'right');
h_g2_u = plot(ax2, state.history_t, state.history_u, 'Color', [0.05 0.55 0.85], 'LineWidth', 1.5, 'LineStyle', ':');
ylabel(ax2, 'Pore Press. (kPa)'); ylim(ax2, [0 15]);
ax2.YColor = [0.05 0.55 0.85];
title(ax2, '2. Subsurface Hydrology & Pore Pressure', 'Color', [0.15 0.15 0.20], 'FontSize', 9);
yline(ax2, 34, 'Color', [0.85 0.45 0.05], 'LineStyle', '--', 'Label', 'Pore Press. Trigger (34%)', ...
    'LineWidth', 1.2, 'FontSize', 7.5, 'FontWeight', 'bold');
legend(ax2, [h_g2_moist, h_g2_u], {'Moisture (%)', 'Pore Press. (kPa)'}, ...
    'TextColor', [0.15 0.15 0.20], 'FontSize', 7.5, 'FontWeight', 'bold', ...
    'Location', 'northwest', 'Box', 'off', 'Color', 'none');
grid(ax2, 'on'); ax2.GridColor = [0.80 0.80 0.80];

% GRAPH 3 (Bottom-Left): PREDICTIVE COLLAPSE FORECASTER
ax3 = axes('Parent', p_graphs, 'Units', 'normalized', 'Position', [0.075, 0.080, 0.415, 0.385], ...
    'Color', [1.0 1.0 1.0], 'XColor', [0.20 0.20 0.20], 'YColor', [0.20 0.20 0.20]);
hold(ax3, 'on');

% High-Clarity Background Safety Zones (Red = Critical, Amber = Advisory, Green = Safe)
patch(ax3, [-100 1000 1000 -100], [0 1.05 1.05 0], [1.0 0.88 0.88], 'EdgeColor', 'none', 'FaceAlpha', 0.45);
patch(ax3, [-100 1000 1000 -100], [1.05 1.30 1.30 1.05], [1.0 0.96 0.82], 'EdgeColor', 'none', 'FaceAlpha', 0.45);
patch(ax3, [-100 1000 1000 -100], [1.30 3.0 3.0 1.30], [0.88 0.97 0.88], 'EdgeColor', 'none', 'FaceAlpha', 0.40);

h_g3_fos = plot(ax3, state.history_t, state.history_fos, 'Color', [0.80 0.35 0.00], 'LineWidth', 2.2);
h_g3_pred = plot(ax3, state.history_t, state.history_fos_pred, 'Color', [0.75 0.10 0.65], 'LineWidth', 2.0, 'LineStyle', ':');
yline(ax3, 1.05, 'Color', [0.85 0.15 0.15], 'LineStyle', ':', 'Label', 'Failure (1.05)', 'LineWidth', 1.5, 'FontWeight', 'bold');
yline(ax3, 1.30, 'Color', [0.80 0.55 0.00], 'LineStyle', ':', 'Label', 'Advisory (1.30)', 'LineWidth', 1.2, 'FontWeight', 'bold');
ylabel(ax3, 'Factor of Safety'); ylim(ax3, [0.3 2.4]);
xlabel(ax3, 'Timeline (Sec)');
title(ax3, '3. Predictive Forecaster (Current vs 10-Min Ahead)', 'Color', [0.15 0.15 0.20], 'FontSize', 9);
legend(ax3, [h_g3_fos, h_g3_pred], {'Current FoS', '10-Min Forecast'}, ...
    'TextColor', [0.15 0.15 0.20], 'FontSize', 7.5, 'FontWeight', 'bold', ...
    'Location', 'northwest', 'Box', 'off', 'Color', 'none');
grid(ax3, 'on'); ax3.GridColor = [0.80 0.80 0.80];

% GRAPH 4 (Bottom-Right): Kinematic Ground Velocity & Warning Tier
ax4 = axes('Parent', p_graphs, 'Units', 'normalized', 'Position', [0.555, 0.080, 0.415, 0.385], ...
    'Color', [1.0 1.0 1.0], 'XColor', [0.20 0.20 0.20], 'YColor', [0.20 0.20 0.20]);
yyaxis(ax4, 'left');
h_g4_tilt = plot(ax4, state.history_t, state.history_tilt, 'Color', [0.55 0.15 0.80], 'LineWidth', 1.8);
ylabel(ax4, 'Tilt (deg/h)'); ylim(ax4, [0 10]);
yline(ax4, 2.2, 'Color', [0.85 0.15 0.15], 'LineStyle', ':', 'Label', 'Rapid Shear (2.2 deg/h)', 'LineWidth', 1.2, 'FontSize', 7.5);
yline(ax4, 0.6, 'Color', [0.80 0.55 0.00], 'LineStyle', ':', 'Label', 'Creep Motion (0.6 deg/h)', 'LineWidth', 1.0, 'FontSize', 7.5);
ax4.YColor = [0.55 0.15 0.80];
yyaxis(ax4, 'right');
h_g4_alert = stairs(ax4, state.history_t, state.history_alert, 'Color', [0.85 0.10 0.10], 'LineWidth', 2.2);
yticks(ax4, [0 1 2]); yticklabels(ax4, {'Safe', 'Advise', 'Evac'});
ylabel(ax4, 'Alert Level'); ylim(ax4, [-0.2 2.3]);
ax4.YColor = [0.75 0.10 0.10];
xlabel(ax4, 'Timeline (Sec)');
title(ax4, '4. Kinematic Motion & Action Tier', 'Color', [0.15 0.15 0.20], 'FontSize', 9);
legend(ax4, [h_g4_tilt, h_g4_alert], {'Tilt (deg/h)', 'Alert Tier'}, ...
    'TextColor', [0.15 0.15 0.20], 'FontSize', 7.5, 'FontWeight', 'bold', ...
    'Location', 'northwest', 'Box', 'off', 'Color', 'none');
grid(ax4, 'on'); ax4.GridColor = [0.80 0.80 0.80];

% -------------------------------------------------------------
% BOTTOM CONTROL DECK: SLIDERS & LIVE DIGITAL METRICS
% -------------------------------------------------------------
p_ctrl = uipanel('Parent', f, 'Units', 'normalized', 'Position', [0.015, 0.015, 0.97, 0.20], ...
    'BackgroundColor', [0.96 0.90 0.78], 'ForegroundColor', [0.15 0.15 0.20], ...
    'Title', 'INTERACTIVE CONTROLS & LIVE DIGITAL TELEMETRY', 'FontWeight', 'bold');

% Card 1: Rainfall (0 to 100 mm/h)
card1 = uipanel('Parent', p_ctrl, 'Units', 'normalized', 'Position', [0.020, 0.08, 0.306, 0.84], ...
    'BackgroundColor', [1 1 1], 'HighlightColor', [0.88 0.82 0.70], 'BorderType', 'line');
uicontrol('Style', 'text', 'Parent', card1, 'Units', 'normalized', 'Position', [0.05, 0.65, 0.58, 0.28], ...
    'String', 'Rainfall Intensity', 'ForegroundColor', [0.05 0.35 0.75], ...
    'BackgroundColor', [1 1 1], 'FontWeight', 'bold', 'FontSize', 9.5, 'HorizontalAlignment', 'left');
lbl_rain_val = uicontrol('Style', 'text', 'Parent', card1, 'Units', 'normalized', 'Position', [0.65, 0.65, 0.30, 0.28], ...
    'String', '0 mm/h', 'ForegroundColor', [0.05 0.35 0.75], 'BackgroundColor', [0.93 0.95 0.99], ...
    'FontWeight', 'bold', 'FontSize', 9.5);
sld_rain = uicontrol('Style', 'slider', 'Parent', card1, 'Units', 'normalized', 'Position', [0.05, 0.26, 0.90, 0.32], ...
    'Min', 0, 'Max', 100, 'Value', 0, 'Callback', @(s,~) updateRain(s.Value));
uicontrol('Style', 'text', 'Parent', card1, 'Units', 'normalized', 'Position', [0.05, 0.04, 0.40, 0.20], ...
    'String', '0 mm/h (Dry)', 'ForegroundColor', [0.5 0.5 0.5], 'BackgroundColor', [1 1 1], 'FontSize', 7.5, 'HorizontalAlignment', 'left');
uicontrol('Style', 'text', 'Parent', card1, 'Units', 'normalized', 'Position', [0.55, 0.04, 0.40, 0.20], ...
    'String', '100 mm/h (Storm)', 'ForegroundColor', [0.5 0.5 0.5], 'BackgroundColor', [1 1 1], 'FontSize', 7.5, 'HorizontalAlignment', 'right');

% Card 2: Hillside Slope Angle (20 to 50 deg)
card2 = uipanel('Parent', p_ctrl, 'Units', 'normalized', 'Position', [0.346, 0.08, 0.306, 0.84], ...
    'BackgroundColor', [1 1 1], 'HighlightColor', [0.88 0.82 0.70], 'BorderType', 'line');
uicontrol('Style', 'text', 'Parent', card2, 'Units', 'normalized', 'Position', [0.05, 0.65, 0.60, 0.28], ...
    'String', 'Hillside Slope Angle', 'ForegroundColor', [0.70 0.35 0.00], ...
    'BackgroundColor', [1 1 1], 'FontWeight', 'bold', 'FontSize', 9.5, 'HorizontalAlignment', 'left');
lbl_slope_val = uicontrol('Style', 'text', 'Parent', card2, 'Units', 'normalized', 'Position', [0.65, 0.65, 0.30, 0.28], ...
    'String', '35°', 'ForegroundColor', [0.70 0.35 0.00], 'BackgroundColor', [0.99 0.96 0.91], ...
    'FontWeight', 'bold', 'FontSize', 9.5);
sld_slope = uicontrol('Style', 'slider', 'Parent', card2, 'Units', 'normalized', 'Position', [0.05, 0.26, 0.90, 0.32], ...
    'Min', 20, 'Max', 50, 'Value', 35, 'Callback', @(s,~) updateSlope(s.Value));
uicontrol('Style', 'text', 'Parent', card2, 'Units', 'normalized', 'Position', [0.05, 0.04, 0.40, 0.20], ...
    'String', '20° (Gentle)', 'ForegroundColor', [0.5 0.5 0.5], 'BackgroundColor', [1 1 1], 'FontSize', 7.5, 'HorizontalAlignment', 'left');
uicontrol('Style', 'text', 'Parent', card2, 'Units', 'normalized', 'Position', [0.55, 0.04, 0.40, 0.20], ...
    'String', '50° (Precipitous)', 'ForegroundColor', [0.5 0.5 0.5], 'BackgroundColor', [1 1 1], 'FontSize', 7.5, 'HorizontalAlignment', 'right');

% Card 3: Seismic / Ground Tremor (0 to 10 deg/h)
card3 = uipanel('Parent', p_ctrl, 'Units', 'normalized', 'Position', [0.672, 0.08, 0.306, 0.84], ...
    'BackgroundColor', [1 1 1], 'HighlightColor', [0.88 0.82 0.70], 'BorderType', 'line');
uicontrol('Style', 'text', 'Parent', card3, 'Units', 'normalized', 'Position', [0.05, 0.65, 0.60, 0.28], ...
    'String', 'Seismic / Tremor Rate', 'ForegroundColor', [0.45 0.10 0.70], ...
    'BackgroundColor', [1 1 1], 'FontWeight', 'bold', 'FontSize', 9.5, 'HorizontalAlignment', 'left');
lbl_tremor_val = uicontrol('Style', 'text', 'Parent', card3, 'Units', 'normalized', 'Position', [0.65, 0.65, 0.30, 0.28], ...
    'String', '0.0 deg/h', 'ForegroundColor', [0.45 0.10 0.70], 'BackgroundColor', [0.97 0.93 0.99], ...
    'FontWeight', 'bold', 'FontSize', 9.5);
sld_tremor = uicontrol('Style', 'slider', 'Parent', card3, 'Units', 'normalized', 'Position', [0.05, 0.26, 0.90, 0.32], ...
    'Min', 0, 'Max', 10, 'Value', 0, 'Callback', @(s,~) updateTremor(s.Value));
uicontrol('Style', 'text', 'Parent', card3, 'Units', 'normalized', 'Position', [0.05, 0.04, 0.40, 0.20], ...
    'String', '0.0 (Quiescent)', 'ForegroundColor', [0.5 0.5 0.5], 'BackgroundColor', [1 1 1], 'FontSize', 7.5, 'HorizontalAlignment', 'left');
uicontrol('Style', 'text', 'Parent', card3, 'Units', 'normalized', 'Position', [0.55, 0.04, 0.40, 0.20], ...
    'String', '10.0 (Severe Tremor)', 'ForegroundColor', [0.5 0.5 0.5], 'BackgroundColor', [1 1 1], 'FontSize', 7.5, 'HorizontalAlignment', 'right');

% -------------------------------------------------------------
% REAL-TIME SIMULATION ENGINE (TIMER)
% -------------------------------------------------------------
tmr = timer('ExecutionMode', 'fixedRate', 'Period', 0.2, 'TimerFcn', @(~,~) stepSim());
start(tmr);

if nargout > 0
    varargout{1} = f;
end

    % User slider callbacks
    function updateRain(val)
        state.rain = val;
        set(lbl_rain_val, 'String', sprintf('%.0f mm/h', val));
    end

    function updateSlope(val)
        state.beta = val;
        set(lbl_slope_val, 'String', sprintf('%.0f°', val));
        updateMountainGeometry();
    end

    function updateTremor(val)
        state.manual_tilt = val;
        set(lbl_tremor_val, 'String', sprintf('%.1f deg/h', val));
    end

    % Button 1: Reset System to baseline
    function resetSystem()
        init_state();
        set(sld_rain, 'Value', 0); set(lbl_rain_val, 'String', '0 mm/h');
        set(sld_slope, 'Value', state.beta); set(lbl_slope_val, 'String', sprintf('%.0f°', state.beta));
        set(sld_tremor, 'Value', 0); set(lbl_tremor_val, 'String', '0.0 deg/h');
        updateMountainGeometry();
        set(h_slide_arrow, 'Visible', 'off');
        set(p_banner, 'String', sprintf('STATUS: SYSTEM RESET  |  SLOPE STABLE (FoS = %.2f)  |  ALL NOMINAL', state.fos), ...
            'BackgroundColor', [0.12 0.50 0.22]);
        fprintf('System reset to nominal conditions.\n');
    end

    % Button 2: Simulate Configurable Storm with Disaster Prediction & Accelerated Playback
    function triggerCloudburst()
        prompt = { ...
            'Rainfall Intensity (mm/h) [10 to 120]:', ...
            'Storm Duration (Hours) [e.g. 1.0 to 8.0]:', ...
            'Hillside Slope Angle (degrees) [20 to 50]:', ...
            'Antecedent Soil Moisture (%) [15 to 55]:', ...
            'Seismic / Ground Tremor (deg/h) [0.0 to 10.0]:'};
        dlgtitle = 'Rainfall & Seismic Disaster Prediction Setup';
        dims = [1 55];
        definput = {'75', '3.0', num2str(state.beta), sprintf('%.1f', state.moist * 100), sprintf('%.1f', state.manual_tilt)};
        answer = inputdlg(prompt, dlgtitle, dims, definput);
        
        if isempty(answer)
            return; % User pressed Cancel
        end
        
        rain_in = str2double(answer{1});
        dur_hr_in = str2double(answer{2});
        beta_in = str2double(answer{3});
        moist_in = str2double(answer{4});
        tremor_in = str2double(answer{5});
        
        if isnan(rain_in) || isnan(dur_hr_in) || isnan(beta_in) || isnan(moist_in) || isnan(tremor_in)
            errordlg('Please enter valid numerical values.', 'Input Error');
            return;
        end
        
        % Validate & clamp within safe physical limits
        rain_val = max(10, min(120, rain_in));
        dur_hr = max(0.2, min(12.0, dur_hr_in));
        beta_val = max(20, min(50, beta_in));
        moist_val = max(15, min(55, moist_in)) / 100;
        tremor_val = max(0, min(10.0, tremor_in));
        
        % Apply slope, moisture & tremor setup
        updateSlope(beta_val);
        set(sld_slope, 'Value', beta_val);
        state.moist = moist_val;
        updateTremor(tremor_val);
        set(sld_tremor, 'Value', tremor_val);
        
        % ---------------------------------------------------------
        % INSTANT NUMERICAL PREDICTIVE FORECAST ENGINE (0-second wait)
        % ---------------------------------------------------------
        N_storm_steps = 75; % 15 seconds real playback
        N_post_steps = 25;  % 5 seconds post-storm drainage
        sim_moist = moist_val;
        time_to_advisory_hr = -1;
        time_to_collapse_hr = -1;
        min_proj_fos = 999;
        max_proj_moist = moist_val;
        max_proj_u = 0;
        
        p = state.p;
        dt_storm_phys = (dur_hr * 3600) / N_storm_steps;
        dt_post_phys = dt_storm_phys;
        
        for k = 1:(N_storm_steps + N_post_steps)
            if k <= N_storm_steps
                curr_t_hr = (k / N_storm_steps) * dur_hr;
                r_step = rain_val;
                dt_k = dt_storm_phys;
            else
                curr_t_hr = dur_hr + ((k - N_storm_steps) / N_post_steps) * (dur_hr * (N_post_steps / N_storm_steps));
                r_step = 0;
                dt_k = dt_post_phys;
            end
            
            hyd = lews_physics('hydrology_step', sim_moist, r_step, dt_k);
            sim_moist = hyd.moist;
            if sim_moist > max_proj_moist
                max_proj_moist = sim_moist;
            end
            u_step = lews_physics('pore_pressure', sim_moist, p.theta_crit, p.gamma_w, p.z, beta_val);
            if u_step > max_proj_u
                max_proj_u = u_step;
            end
            
            k_fos = lews_physics('fos', beta_val, state.c_prime, p.phi_deg, p.gamma_s, p.z, u_step, tremor_val);
            if k_fos < min_proj_fos
                min_proj_fos = k_fos;
            end
            
            proj_tilt = lews_physics('kinematics', k_fos, tremor_val);
            
            % Multi-tier trigger checks
            if time_to_advisory_hr < 0 && (k_fos <= 1.45 || sim_moist >= 0.24 || r_step >= 25 || proj_tilt >= 0.6)
                time_to_advisory_hr = curr_t_hr;
            end
            if time_to_collapse_hr < 0 && (k_fos <= 1.05 || (proj_tilt >= 2.2 && k_fos <= 1.20) || (sim_moist >= 0.45 && k_fos <= 1.25))
                time_to_collapse_hr = curr_t_hr;
            end
        end
        
        % Build Instant Executive Predictive Consequence Report
        if time_to_collapse_hr > 0
            lead_time_min = max(0, (time_to_collapse_hr - time_to_advisory_hr) * 60);
            report_msg = sprintf([ ...
                '===============================================\n' ...
                '     DISASTER EARLY WARNING: SLOPE FAILURE PREDICTED!\n' ...
                '===============================================\n\n' ...
                'EVENT FORCING PARAMETERS:\n' ...
                '  - Rainfall Rate: %.0f mm/h for %.1f Hours (Total: %.0f mm)\n' ...
                '  - Terrain Slope: %.0f deg | Antecedent Moisture: %.1f%%\n' ...
                '  - Seismic / Ground Tremor: %.1f deg/h (Inertial Stress Active)\n\n' ...
                'PREDICTIVE IMPACT CONSEQUENCES:\n' ...
                '  - Catastrophic Failure: Forecast at T + %.1f hr (%.0f mins into event)\n' ...
                '  - Advisory Stage (Yellow): Triggered at T + %.1f hr\n' ...
                '  - Advance Evacuation Lead Time: %.0f minutes ahead of collapse\n' ...
                '  - Critical Factor of Safety: FoS drops to %.2f (FAIL)\n' ...
                '  - Peak Soil Saturation: %.1f%% (Pore Pressure: %.1f kPa)\n\n' ...
                'ACTION MANDATE: EVACUATION ORDER RECOMMENDED.\n\n' ...
                'Press OK to begin time-accelerated playback (~15 seconds on graphs).'], ...
                rain_val, dur_hr, rain_val * dur_hr, beta_val, moist_val*100, tremor_val, ...
                time_to_collapse_hr, time_to_collapse_hr*60, time_to_advisory_hr, ...
                lead_time_min, min_proj_fos, max_proj_moist*100, max_proj_u);
            helpdlg(report_msg, 'DISASTER PREDICTION REPORT');
        else
            report_msg = sprintf([ ...
                '===============================================\n' ...
                '       PREDICTIVE FORECAST: SLOPE REMAINS STABLE\n' ...
                '===============================================\n\n' ...
                'EVENT FORCING PARAMETERS:\n' ...
                '  - Rainfall Rate: %.0f mm/h for %.1f Hours\n' ...
                '  - Terrain Slope: %.0f deg | Antecedent Moisture: %.1f%%\n' ...
                '  - Seismic / Ground Tremor: %.1f deg/h\n\n' ...
                'PREDICTIVE IMPACT CONSEQUENCES:\n' ...
                '  - Slope Stability: Stable throughout event horizon\n' ...
                '  - Minimum Factor of Safety: FoS = %.2f (Above critical 1.0)\n' ...
                '  - Peak Soil Saturation: %.1f%% (Pore Pressure: %.1f kPa)\n\n' ...
                'ACTION MANDATE: CONTINUED ROUTINE MONITORING.\n\n' ...
                'Press OK to begin time-accelerated playback (~15 seconds on graphs).'], ...
                rain_val, dur_hr, beta_val, moist_val*100, tremor_val, min_proj_fos, max_proj_moist*100, max_proj_u);
            helpdlg(report_msg, 'DISASTER PREDICTION REPORT');
        end
        
        % Arm Time-Accelerated Simulation Playback
        state.storm_active = true;
        state.storm_rain = rain_val;
        state.storm_dur_hr = dur_hr;
        state.storm_step_count = 0;
        state.storm_total_steps = N_storm_steps;
        state.storm_min_fos = min_proj_fos;
        state.storm_collapse_hr = time_to_collapse_hr;
        
        state.rain = rain_val;
        set(sld_rain, 'Value', rain_val);
        set(lbl_rain_val, 'String', sprintf('%.0f mm/h', rain_val));
        fprintf('Accelerated storm simulation started: %.0f mm/h for %.1f hours.\n', rain_val, dur_hr);
    end

    % Dynamically updates the physical mountain visual based on slope angle beta
    % Dynamically updates the physical mountain visual based on slope angle beta and state
    function updateMountainGeometry()
        x_m = linspace(0, 10, 60);
        H_crest = 2.2 + 4.8 * tan(deg2rad(state.beta)) / tan(deg2rad(50));
        
        % 1. Bedrock stratum (impermeable geological foundation)
        y_bed = 0.5 + 0.12 * sin(x_m * 0.7) + (H_crest * 0.38) * (x_m / 10).^1.25;
        set(h_bedrock, 'XData', [x_m, 10, 0], 'YData', [y_bed, 0, 0]);
        set(h_bedrock_joints, 'XData', x_m(4:56), 'YData', y_bed(4:56) * 0.55);
        
        % 2. Circular Bishop shear slip surface
        arc_dip = 0.65 * sin(pi * x_m / 10);
        y_slip = y_bed + 0.35 + arc_dip;
        set(h_slip_line, 'XData', x_m, 'YData', y_slip);
        
        % 3. Smooth sigmoidal mountain surface profile
        s_curve = 0.5 * (1 + tanh((x_m - 4.2) / 2.2));
        y_surf = 1.0 + (H_crest - 1.0) * s_curve + 0.06 * sin(x_m * 1.5);
        
        % Dynamic physical slide offset on failure
        off_x = -state.slip_offset * 0.8;
        off_y = -state.slip_offset * 0.4;
        
        x_soil_top = x_m + off_x;
        y_soil_top = y_surf + off_y;
        x_soil_bot = fliplr(x_m + off_x);
        y_soil_bot = fliplr(y_slip + off_y);
        
        set(h_soil, 'XData', [x_soil_top, x_soil_bot], 'YData', [y_soil_top, y_soil_bot]);
        set(h_grass_line, 'XData', x_soil_top, 'YData', y_soil_top);
        
        % 4. Groundwater phreatic surface and toe seepage
        water_h = max(0, (state.moist - 0.18) * 3.8);
        y_water = y_slip + water_h * (1 - 0.25 * (x_m / 10));
        set(h_water_table, 'XData', x_m, 'YData', y_water);
        if state.moist >= 0.28
            set(h_toe_seep, 'XData', x_m(4) + off_x, 'YData', y_water(4) + off_y, 'Visible', 'on');
        else
            set(h_toe_seep, 'Visible', 'off');
        end
        
        % 5. Alpine Settlement (Chalet) on slope terrace
        s_chalet = 0.5 * (1 + tanh((2.4 - 4.2) / 2.2));
        y_chalet_surf = 1.0 + (H_crest - 1.0) * s_chalet + 0.06 * sin(2.4 * 1.5);
        h_x0 = 2.4 + off_x;
        h_y0 = y_chalet_surf + off_y;
        tilt_angle = state.slip_offset * 0.20;
        
        set(h_house_base, 'XData', [h_x0-0.4, h_x0+0.4, h_x0+0.4, h_x0-0.4], ...
            'YData', [h_y0+0.15, h_y0+0.15, h_y0, h_y0]);
        set(h_house_body, 'XData', [h_x0-0.35, h_x0+0.35, h_x0+0.35, h_x0-0.35], ...
            'YData', [h_y0+0.75, h_y0+0.75, h_y0+0.15, h_y0+0.15]);
        set(h_house_roof, 'XData', [h_x0-0.45, h_x0 - tilt_angle, h_x0+0.45], ...
            'YData', [h_y0+0.75, h_y0+1.20, h_y0+0.75]);
        set(h_house_win, 'XData', h_x0, 'YData', h_y0+0.45);
        set(txt_lbl_chalet, 'Position', [h_x0-0.7, h_y0+1.45, 0]);
        
        % 6. Realistic Evergreen Pine Trees with Trunks and Canopies
        for t_i = 1:length(tree_x)
            t_x0 = tree_x(t_i);
            s_val = 0.5 * (1 + tanh((t_x0 - 4.2) / 2.2));
            t_y0 = 1.0 + (H_crest - 1.0) * s_val + 0.06 * sin(t_x0 * 1.5) + off_y;
            t_xtree = t_x0 + off_x;
            tilt_lean = state.slip_offset * 0.35;
            set(h_tree_trunks(t_i), 'XData', [t_xtree, t_xtree - tilt_lean], 'YData', [t_y0, t_y0 + 0.45]);
            set(h_tree_canopies(t_i), 'XData', [t_xtree-0.35 - tilt_lean, t_xtree - tilt_lean*1.5, t_xtree+0.35 - tilt_lean], ...
                'YData', [t_y0+0.40, t_y0+1.15, t_y0+0.40]);
        end
        
        % 7. Telemetry Monitoring Mast, Solar Panel, Beacon
        mast_x0 = 5.6;
        s_val_mast = 0.5 * (1 + tanh((mast_x0 - 4.2) / 2.2));
        mast_y = 1.0 + (H_crest - 1.0) * s_val_mast + 0.06 * sin(mast_x0 * 1.5) + off_y;
        mast_x = mast_x0 + off_x;
        set(h_sensor_mast, 'XData', [mast_x, mast_x - state.slip_offset*0.25], 'YData', [mast_y, mast_y + 0.85]);
        sp_tilt = 0.08 + state.slip_offset*0.10;
        set(h_sensor_solar, 'XData', [mast_x-0.25, mast_x+0.25, mast_x+0.25, mast_x-0.25], ...
            'YData', [mast_y+0.45+sp_tilt, mast_y+0.55+sp_tilt, mast_y+0.42-sp_tilt, mast_y+0.32-sp_tilt]);
        set(h_sensor_beacon, 'XData', mast_x - state.slip_offset*0.25, 'YData', mast_y + 0.88);
        
        % 8. Dynamic Atmospheric Sky & Rain Streaks Animation
        if state.alert_level == 2 || state.rain > 50
            set(h_sky, 'FaceColor', [0.48 0.52 0.58]); % Stormy dark sky
        elseif state.rain > 0 || state.alert_level == 1
            set(h_sky, 'FaceColor', [0.68 0.74 0.82]); % Overcast sky
        else
            set(h_sky, 'FaceColor', [0.86 0.92 0.98]); % Clear blue sky
        end
        
        if state.rain > 0
            rain_y = rain_y - (0.35 + 0.004 * state.rain);
            reset_idx = rain_y < 0.5;
            if any(reset_idx)
                rain_y(reset_idx) = 7.0 + 0.5 * rand(1, sum(reset_idx));
                rain_x(reset_idx) = linspace(0.5, 9.5, sum(reset_idx)) + rand(1, sum(reset_idx))*0.2;
            end
            for r_i = 1:N_rain
                set(h_rain_streaks(r_i), 'XData', [rain_x(r_i), rain_x(r_i)-0.12], ...
                    'YData', [rain_y(r_i), rain_y(r_i)-0.40], 'Visible', 'on');
            end
        else
            for r_i = 1:N_rain
                set(h_rain_streaks(r_i), 'Visible', 'off');
            end
        end
        
        % 9. Tension Crack Visibility at Crown
        crack_top_y = H_crest + off_y;
        if state.slip_offset > 0.06
            crack_x = 8.6 + off_x + [0, 0.08, -0.06, 0.05];
            crack_y = crack_top_y - [0.05, 0.40, 0.75, 1.10];
            set(h_crown_crack, 'XData', crack_x, 'YData', crack_y, 'Visible', 'on');
            set(txt_lbl_crown, 'Position', [8.0 + off_x, crack_top_y + 0.25, 0], 'Visible', 'on');
        else
            set(h_crown_crack, 'Visible', 'off');
            set(txt_lbl_crown, 'Position', [8.1, H_crest + 0.25, 0], 'Visible', 'on');
        end
        
        % 10. Labels positions
        set(txt_lbl_slip, 'Position', [4.8 + off_x, y_slip(30) - 0.35 + off_y, 0]);
        set(txt_lbl_water, 'Position', [0.8, y_water(6) + 0.35, 0]);
        
        % 11. High-Clarity Heads-Up Display (HUD) Telemetry Updates
        set(txt_hud_slope, 'String', sprintf('Terrain Slope: %.0f°', state.beta));
        set(txt_hud_moist, 'String', sprintf('Moisture: %.1f%%  |  Pore Press: %.1f kPa', state.moist*100, state.pore_pressure));
        if state.alert_level == 2
            set(txt_hud_fos, 'String', sprintf('Stability FoS: %.2f  [CRITICAL DANGER]', state.fos), 'Color', [0.85 0.10 0.10]);
            set(txt_hud_ml, 'String', sprintf('AI Risk: %.1f%%  [EVACUATE NOW]', state.ml_prob_alert*100), 'Color', [0.85 0.10 0.10]);
            set(h_sensor_beacon, 'MarkerFaceColor', [0.95 0.10 0.10], 'MarkerEdgeColor', [0.60 0.00 0.00]);
            set(h_house_body, 'FaceColor', [0.85 0.25 0.25]); % Building endangered
        elseif state.alert_level == 1
            set(txt_hud_fos, 'String', sprintf('Stability FoS: %.2f  [ACTIVE ADVISORY]', state.fos), 'Color', [0.85 0.55 0.05]);
            set(txt_hud_ml, 'String', sprintf('AI Risk: %.1f%%  [WARNING]', state.ml_prob_alert*100), 'Color', [0.85 0.55 0.05]);
            set(h_sensor_beacon, 'MarkerFaceColor', [0.95 0.70 0.10], 'MarkerEdgeColor', [0.60 0.40 0.00]);
            set(h_house_body, 'FaceColor', [0.80 0.60 0.30]); % Building alert
        else
            set(txt_hud_fos, 'String', sprintf('Stability FoS: %.2f  [SAFE / STABLE]', state.fos), 'Color', [0.10 0.55 0.20]);
            set(txt_hud_ml, 'String', sprintf('AI Risk: %.1f%%  [Nominal]', state.ml_prob_alert*100), 'Color', [0.35 0.15 0.50]);
            set(h_sensor_beacon, 'MarkerFaceColor', [0.10 0.80 0.20], 'MarkerEdgeColor', [0.00 0.50 0.10]);
            set(h_house_body, 'FaceColor', [0.72 0.48 0.28]); % Normal alpine timber
        end
    end

    % Main Simulation Step (Every 0.2s)
    function stepSim()
        if ~isvalid(f); return; end
        
        sim_elapsed_hr = 0;
        if state.storm_active
            state.storm_step_count = state.storm_step_count + 1;
            dt_phys = (state.storm_dur_hr * 3600) / state.storm_total_steps;
            sim_elapsed_hr = (state.storm_step_count / state.storm_total_steps) * state.storm_dur_hr;
            % Process full storm: only shut off after the last storm step is simulated
            if state.storm_step_count > state.storm_total_steps
                state.storm_active = false;
                state.rain = 0;
                set(sld_rain, 'Value', 0);
                set(lbl_rain_val, 'String', '0 mm/h');
                dt_phys = 0.2;
                fprintf('Storm duration ended (%.1f hr event finished). Rain shut off.\n', state.storm_dur_hr);
            end
        else
            dt_phys = 0.2;
        end
        state.sim_time = state.sim_time + 0.2;
        
        % 1. Hydrology: Infiltration & Cumulative Rain (Decoupled Physical Integration)
        hyd = lews_physics('hydrology_step', state.moist, state.rain, dt_phys, state.cum_rain);
        state.moist = hyd.moist;
        state.cum_rain = hyd.cum_rain;
        state.pore_pressure = lews_physics('pore_pressure', state.moist, state.p.theta_crit, state.p.gamma_w, state.p.z, state.beta);
        
        % 2. Geotechnical Stability (Factor of Safety via Unified Geomechanics)
        state.prev_fos = state.fos;
        state.fos = lews_physics('fos', state.beta, state.c_prime, state.p.phi_deg, state.p.gamma_s, state.p.z, state.pore_pressure, state.manual_tilt);
        
        % 3. Predictive Disaster Forecaster (Smooth derivative filter)
        raw_dfos = (state.fos - state.prev_fos) / max(0.001, dt_phys);
        alpha = min(0.3, 0.05 + 0.1 * dt_phys);
        state.dfos_dt = alpha * raw_dfos + (1 - alpha) * state.dfos_dt; % Low-pass filter
        lead_sec = 600; % 10 minutes ahead
        state.fos_pred = max(0.1, min(2.5, state.fos + (state.dfos_dt * lead_sec)));
        
        % Estimated Time-to-Failure (TTF in minutes, NaN when stable)
        if state.fos <= 1.05
            state.time_to_collapse = 0; % Slope reached failure
        elseif state.dfos_dt < -0.00002
            ttf_sec = (state.fos - 1.05) / (-state.dfos_dt);
            state.time_to_collapse = max(1, min(180, ttf_sec / 60));
        else
            state.time_to_collapse = NaN; % Stable / No failure imminent
        end
        
        % 4. Kinematics (Ground Velocity / Tilt Rate)
        state.tilt_rate = lews_physics('kinematics', state.fos, state.manual_tilt);
        
        % Physical slip displacement animation (Plastic irreversible deformation)
        if state.fos < 1.05
            state.slip_offset = min(1.2, state.slip_offset + 0.03);
        end
        
        % Machine Learning Real-Time Inference: features [FoS, Moisture (%), Rain, TiltRate]
        if ~isempty(state.ml_model)
            X_live = [state.fos, state.moist * 100, state.rain, state.tilt_rate];
            try
                [~, ml_scores] = predict(state.ml_model, X_live);
                if size(ml_scores, 2) >= 3
                    state.ml_prob_alert = ml_scores(2) + ml_scores(3);
                end
            catch
            end
        end
        
        % 5. Multi-tier Emergency Decision with Schmitt Trigger Hysteresis
        crit_cond = (state.fos <= 1.05) || ...
                    (state.tilt_rate >= 2.2 && state.fos <= 1.20) || ...
                    (state.moist >= 0.45 && state.fos <= 1.25);
        
        adv_cond = (state.rain >= 25) || ...
                   (state.moist >= 0.24) || ...
                   (state.fos <= 1.45) || ...
                   (state.tilt_rate >= 0.6) || ...
                   (~isnan(state.time_to_collapse) && state.time_to_collapse <= 45);
        
        if crit_cond
            state.alert_level = 2; % EVACUATE NOW
        elseif state.alert_level == 2
            % Hysteresis recovery check to step down to Advisory
            if state.fos > 1.15 && state.tilt_rate < 1.8
                state.alert_level = 1;
            end
        elseif adv_cond
            state.alert_level = 1; % PREDICTIVE ADVISORY
        elseif state.alert_level == 1
            % Hysteresis recovery check to step down to Safe
            if state.fos > 1.48 && state.rain < 20 && state.moist < 0.23 && state.tilt_rate < 0.5
                state.alert_level = 0;
            end
        else
            state.alert_level = 0; % SAFE
        end
        
        % 6. UPDATE GRAPHICAL CANVASES
        % Update Mountain Visuals
        updateMountainGeometry();
        
        if state.alert_level == 2
            set(h_soil, 'FaceColor', [0.85 0.22 0.20], 'EdgeColor', [0.65 0.10 0.10]); % Red failure body
            set(h_grass_line, 'Color', [0.75 0.15 0.15]);
            set(h_slide_arrow, 'Visible', 'on');
            if state.storm_active
                set(p_banner, 'String', sprintf('EMERGENCY [STAGE 2/2]: ACCELERATED STORM (%.1fh event, T+%.1fh) - CRITICAL COLLAPSE IN PROGRESS! EVACUATE!', state.storm_dur_hr, sim_elapsed_hr), ...
                    'BackgroundColor', [0.85 0.15 0.15]);
            else
                if isnan(state.time_to_collapse) || state.time_to_collapse <= 0
                    ttf_str = 'IMMINENT';
                else
                    ttf_str = sprintf('IN %.1f MINS', state.time_to_collapse);
                end
                set(p_banner, 'String', sprintf('EMERGENCY [STAGE 2/2]: PREDICTED COLLAPSE %s! SIREN & EVACUATION BROADCAST ACTIVE!', ttf_str), ...
                    'BackgroundColor', [0.85 0.15 0.15]);
            end
        elseif state.alert_level == 1
            set(h_soil, 'FaceColor', [0.88 0.68 0.18], 'EdgeColor', [0.70 0.50 0.10]); % Amber advisory
            set(h_grass_line, 'Color', [0.70 0.50 0.10]);
            set(h_slide_arrow, 'Visible', 'off');
            if state.storm_active
                set(p_banner, 'String', sprintf('PREDICTIVE ADVISORY [STAGE 1/2]: ACCELERATED STORM (%.1fh event, T+%.1fh) - INFILTRATING (Moist: %.0f%%, FoS: %.2f)', state.storm_dur_hr, sim_elapsed_hr, state.moist*100, state.fos), ...
                    'BackgroundColor', [0.85 0.55 0.05]);
            else
                set(p_banner, 'String', sprintf('PREDICTIVE ADVISORY [STAGE 1/2]: HEAVY RAIN INFILTRATING (Moist: %.0f%%, FoS: %.2f) - EARLY WARNING ACTIVE', state.moist*100, state.fos), ...
                    'BackgroundColor', [0.85 0.55 0.05]);
            end
        else
            set(h_soil, 'FaceColor', [0.22 0.55 0.25], 'EdgeColor', [0.15 0.40 0.18]); % Lush green
            set(h_grass_line, 'Color', [0.12 0.40 0.15]);
            set(h_slide_arrow, 'Visible', 'off');
            if state.storm_active
                set(p_banner, 'String', sprintf('STATUS: ACCELERATED STORM (%.1fh event, T+%.1fh) - SLOPE STABLE (FoS: %.2f)', state.storm_dur_hr, sim_elapsed_hr, state.fos), ...
                    'BackgroundColor', [0.12 0.50 0.22]);
            else
                set(p_banner, 'String', sprintf('STATUS: NOMINAL  |  Slope Stable (FoS = %.2f)  |  No Failure Predicted', state.fos), ...
                    'BackgroundColor', [0.12 0.50 0.22]);
            end
        end
        
        % Update History Buffers
        state.history_t = [state.history_t(2:end), state.sim_time];
        state.history_rain = [state.history_rain(2:end), state.rain];
        state.history_cum_rain = [state.history_cum_rain(2:end), state.cum_rain];
        state.history_moist = [state.history_moist(2:end), state.moist * 100];
        state.history_u = [state.history_u(2:end), state.pore_pressure];
        state.history_fos = [state.history_fos(2:end), state.fos];
        state.history_fos_pred = [state.history_fos_pred(2:end), state.fos_pred];
        state.history_tilt = [state.history_tilt(2:end), state.tilt_rate];
        state.history_alert = [state.history_alert(2:end), state.alert_level];
        
        % Update Graph 1 (Dynamic Auto-Scaling)
        set(h_g1_rain, 'XData', state.history_t, 'YData', state.history_rain);
        set(h_g1_cum, 'XData', state.history_t, 'YData', state.history_cum_rain);
        xlim(ax1, [max(0, state.sim_time - 30), state.sim_time + 1]);
        yyaxis(ax1, 'left');
        max_rain_val = max(state.history_rain);
        ylim(ax1, [0, max(50, max_rain_val * 1.20)]);
        yyaxis(ax1, 'right');
        max_cum_val = max(state.history_cum_rain);
        ylim(ax1, [0, max(15, max_cum_val * 1.20)]);
        
        % Update Graph 2 (Dynamic Auto-Scaling)
        set(h_g2_moist, 'XData', state.history_t, 'YData', state.history_moist);
        set(h_g2_u, 'XData', state.history_t, 'YData', state.history_u);
        xlim(ax2, [max(0, state.sim_time - 30), state.sim_time + 1]);
        yyaxis(ax2, 'left');
        min_moist_val = min(state.history_moist);
        max_moist_val = max(state.history_moist);
        ylim(ax2, [max(0, min_moist_val - 5), min(100, max(60, max_moist_val + 8))]);
        yyaxis(ax2, 'right');
        max_u_val = max(state.history_u);
        ylim(ax2, [0, max(10, max_u_val * 1.25)]);
        
        % Update Graph 3 (Dynamic Auto-Scaling, preserving failure thresholds in view)
        set(h_g3_fos, 'XData', state.history_t, 'YData', state.history_fos);
        set(h_g3_pred, 'XData', state.history_t, 'YData', state.history_fos_pred);
        xlim(ax3, [max(0, state.sim_time - 30), state.sim_time + 1]);
        min_fos_val = min([state.history_fos, state.history_fos_pred]);
        max_fos_val = max([state.history_fos, state.history_fos_pred]);
        ylim(ax3, [max(0.1, min(0.8, min_fos_val - 0.2)), max(2.2, max_fos_val + 0.25)]);
        
        % Update Graph 4 (Dynamic Auto-Scaling on tilt velocity)
        set(h_g4_tilt, 'XData', state.history_t, 'YData', state.history_tilt);
        set(h_g4_alert, 'XData', state.history_t, 'YData', state.history_alert);
        xlim(ax4, [max(0, state.sim_time - 30), state.sim_time + 1]);
        yyaxis(ax4, 'left');
        max_tilt_val = max(state.history_tilt);
        ylim(ax4, [0, max(5, max_tilt_val * 1.25)]);
        yyaxis(ax4, 'right');
        ylim(ax4, [-0.2, 2.3]);
    end

    function onClose(~, ~)
        try
            stop(tmr);
            delete(tmr);
        catch
        end
        delete(f);
        fprintf('GeoGuard Command Console closed.\n');
    end
end
