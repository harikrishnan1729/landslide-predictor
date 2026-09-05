function predictive_dashboard()
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
    state.rain = 0;               % mm/h
    state.cum_rain = 0;           % mm
    state.beta = 35;              % degrees
    state.c_prime = 12;           % kPa
    state.moist = 0.18;           % 18% volumetric water content
    state.pore_pressure = 0;      % kPa
    state.manual_tilt = 0;        % deg/h
    state.tilt_rate = 0.05;       % deg/h
    state.fos = 1.82;             % current factor of safety
    state.prev_fos = 1.82;        % previous factor of safety
    state.dfos_dt = 0;            % filtered rate of change of FoS
    state.fos_pred = 1.82;        % 15-min predicted factor of safety
    state.time_to_collapse = 999; % minutes
    state.alert_level = 0;        % 0=Safe, 1=Advisory, 2=Evacuate
    state.sim_time = 0;           % seconds
    state.slip_offset = 0;        % physical slide displacement for graphics

    % Accelerated Storm Simulation & Prediction State
    state.storm_active = false;
    state.storm_rain = 0;
    state.storm_dur_hr = 0;
    state.storm_step_count = 0;
    state.storm_total_steps = 75;
    state.storm_min_fos = 1.82;
    state.storm_collapse_hr = -1;

    % History buffers for high-detail plotting (150 time steps)
    BUF_LEN = 150;
    state.history_t = zeros(1, BUF_LEN);
    state.history_rain = zeros(1, BUF_LEN);
    state.history_cum_rain = zeros(1, BUF_LEN);
    state.history_moist = 18 * ones(1, BUF_LEN);
    state.history_u = zeros(1, BUF_LEN);
    state.history_fos = 1.82 * ones(1, BUF_LEN);
    state.history_fos_pred = 1.82 * ones(1, BUF_LEN);
    state.history_tilt = 0.05 * ones(1, BUF_LEN);
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
    'String', 'STATUS: NOMINAL  |  SLOPE STABLE (FoS = 1.82)  |  NO FAILURE PREDICTED', ...
    'FontSize', 13, ...
    'FontWeight', 'bold', ...
    'Color', [1 1 1], ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'EdgeColor', 'none', ...
    'BackgroundColor', [0.12 0.50 0.22]);

% -------------------------------------------------------------
% LEFT SECTION: INTERACTIVE GEOMECHANICAL HILLSIDE GRAPHIC
% -------------------------------------------------------------
p_geo = uipanel('Parent', f, 'Units', 'normalized', 'Position', [0.015, 0.23, 0.38, 0.61], ...
    'BackgroundColor', [0.96 0.90 0.78], 'ForegroundColor', [0.15 0.15 0.20], ...
    'Title', 'REAL-TIME HILLSIDE DEFORMATION & GEOMECHANICS', 'FontWeight', 'bold');

ax_geo = axes('Parent', p_geo, 'Units', 'normalized', 'Position', [0.05, 0.08, 0.90, 0.86], ...
    'Color', [1.0 1.0 1.0]);
hold(ax_geo, 'on');

% Dynamic Bedrock (Dark Slate)
h_bedrock = patch(ax_geo, [0 10 10 0], [0 0 3 1], [0.22 0.24 0.27], 'EdgeColor', 'none');

% Dynamic Shear Slip Surface (Red dotted line)
h_slip_line = plot(ax_geo, [0 10], [1 3], 'r:', 'LineWidth', 2.5);

% Dynamic Overburden Soil Body (Changes color: Green -> Yellow -> Red, and physically displaces on failure!)
h_soil = patch(ax_geo, [0 10 10 0], [1 3 6 2], [0.18 0.48 0.20], 'EdgeColor', [0.1 0.3 0.1], 'LineWidth', 1.5);

% Dynamic Groundwater Seepage / Pore Pressure Line (Cyan dotted)
h_water_table = plot(ax_geo, [0 10], [0.8 2.0], 'c:', 'LineWidth', 2.5);

% Settlement and Infrastructure zone on slope
h_surface_items = text(ax_geo, .5, 7.2, '[ SURFACE SETTLEMENT ZONE ]', ...
    'Color', [0.05 0.25 0.08], ...
    'FontSize', 11, ...
    'FontWeight', 'bold', ...
    'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'middle');

% Catastrophic Slide Vector Arrow
h_slide_arrow = annotation('arrow', [0.24 0.18], [0.42 0.34], 'Color', [1 0.2 0.2], 'LineWidth', 3.5, 'Visible', 'off');

% Live Metric Badges on the Mountain Canvas
txt_angle_overlay = text(ax_geo, 0.5, 6.8, 'Slope: 35°', 'Color', [0.15 0.15 0.25], 'FontSize', 10, 'FontWeight', 'bold');
txt_fos_overlay = text(ax_geo, 0.5, 6.4, 'FoS: 1.82 (Safe)', 'Color', [0.10 0.50 0.20], 'FontSize', 10, 'FontWeight', 'bold');

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
legend(ax2, [h_g2_moist, h_g2_u], {'Moisture (%)', 'Pore Press. (kPa)'}, ...
    'TextColor', [0.15 0.15 0.20], 'FontSize', 7.5, 'FontWeight', 'bold', ...
    'Location', 'northwest', 'Box', 'off', 'Color', 'none');
grid(ax2, 'on'); ax2.GridColor = [0.80 0.80 0.80];

% GRAPH 3 (Bottom-Left): PREDICTIVE COLLAPSE FORECASTER
ax3 = axes('Parent', p_graphs, 'Units', 'normalized', 'Position', [0.075, 0.080, 0.415, 0.385], ...
    'Color', [1.0 1.0 1.0], 'XColor', [0.20 0.20 0.20], 'YColor', [0.20 0.20 0.20]);
hold(ax3, 'on');
h_g3_fos = plot(ax3, state.history_t, state.history_fos, 'Color', [0.80 0.40 0.05], 'LineWidth', 2);
h_g3_pred = plot(ax3, state.history_t, state.history_fos_pred, 'Color', [0.75 0.10 0.65], 'LineWidth', 2, 'LineStyle', ':');
yline(ax3, 1.0, 'r:', 'Failure (1.0)', 'LineWidth', 1.5);
yline(ax3, 1.3, 'Color', [0.80 0.60 0.00], 'LineStyle', ':', 'Label', 'Marginal (1.3)', 'LineWidth', 1.0);
ylabel(ax3, 'Factor of Safety'); ylim(ax3, [0.3 2.4]);
xlabel(ax3, 'Timeline (Sec)');
title(ax3, '3. Predictive Forecaster (Current vs 15-Min Ahead)', 'Color', [0.15 0.15 0.20], 'FontSize', 9);
legend(ax3, [h_g3_fos, h_g3_pred], {'Current FoS', '15-Min Forecast'}, ...
    'TextColor', [0.15 0.15 0.20], 'FontSize', 7.5, 'FontWeight', 'bold', ...
    'Location', 'northwest', 'Box', 'off', 'Color', 'none');
grid(ax3, 'on'); ax3.GridColor = [0.80 0.80 0.80];

% GRAPH 4 (Bottom-Right): Kinematic Ground Velocity & Warning Tier
ax4 = axes('Parent', p_graphs, 'Units', 'normalized', 'Position', [0.555, 0.080, 0.415, 0.385], ...
    'Color', [1.0 1.0 1.0], 'XColor', [0.20 0.20 0.20], 'YColor', [0.20 0.20 0.20]);
yyaxis(ax4, 'left');
h_g4_tilt = plot(ax4, state.history_t, state.history_tilt, 'Color', [0.55 0.15 0.80], 'LineWidth', 1.8);
ylabel(ax4, 'Tilt (deg/h)'); ylim(ax4, [0 10]);
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

% Slider 1: Rainfall (0 to 100 mm/h)
uicontrol('Style', 'text', 'Parent', p_ctrl, 'Units', 'normalized', 'Position', [0.02, 0.62, 0.18, 0.28], ...
    'String', 'Rainfall Intensity (mm/h):', 'ForegroundColor', [0.05 0.30 0.65], ...
    'BackgroundColor', [0.96 0.90 0.78], 'FontWeight', 'bold', 'HorizontalAlignment', 'left');
lbl_rain_val = uicontrol('Style', 'text', 'Parent', p_ctrl, 'Units', 'normalized', 'Position', [0.20, 0.62, 0.08, 0.28], ...
    'String', '0 mm/h', 'ForegroundColor', [0.15 0.15 0.20], 'BackgroundColor', [0.96 0.90 0.78], 'FontWeight', 'bold');
sld_rain = uicontrol('Style', 'slider', 'Parent', p_ctrl, 'Units', 'normalized', 'Position', [0.02, 0.24, 0.26, 0.34], ...
    'Min', 0, 'Max', 100, 'Value', 0, 'Callback', @(s,~) updateRain(s.Value));

% Slider 2: Slope Angle (20 to 50 deg)
uicontrol('Style', 'text', 'Parent', p_ctrl, 'Units', 'normalized', 'Position', [0.32, 0.62, 0.18, 0.28], ...
    'String', 'Hillside Slope Angle:', 'ForegroundColor', [0.70 0.35 0.00], ...
    'BackgroundColor', [0.96 0.90 0.78], 'FontWeight', 'bold', 'HorizontalAlignment', 'left');
lbl_slope_val = uicontrol('Style', 'text', 'Parent', p_ctrl, 'Units', 'normalized', 'Position', [0.50, 0.62, 0.08, 0.28], ...
    'String', '35°', 'ForegroundColor', [0.15 0.15 0.20], 'BackgroundColor', [0.96 0.90 0.78], 'FontWeight', 'bold');
sld_slope = uicontrol('Style', 'slider', 'Parent', p_ctrl, 'Units', 'normalized', 'Position', [0.32, 0.24, 0.26, 0.34], ...
    'Min', 20, 'Max', 50, 'Value', 35, 'Callback', @(s,~) updateSlope(s.Value));

% Slider 3: Ground Vibration / Tremor (0 to 10 deg/h)
uicontrol('Style', 'text', 'Parent', p_ctrl, 'Units', 'normalized', 'Position', [0.62, 0.62, 0.18, 0.28], ...
    'String', 'Seismic / Ground Tremor:', 'ForegroundColor', [0.45 0.10 0.70], ...
    'BackgroundColor', [0.96 0.90 0.78], 'FontWeight', 'bold', 'HorizontalAlignment', 'left');
lbl_tremor_val = uicontrol('Style', 'text', 'Parent', p_ctrl, 'Units', 'normalized', 'Position', [0.80, 0.62, 0.08, 0.28], ...
    'String', '0.0 deg/h', 'ForegroundColor', [0.15 0.15 0.20], 'BackgroundColor', [0.96 0.90 0.78], 'FontWeight', 'bold');
sld_tremor = uicontrol('Style', 'slider', 'Parent', p_ctrl, 'Units', 'normalized', 'Position', [0.62, 0.24, 0.26, 0.34], ...
    'Min', 0, 'Max', 10, 'Value', 0, 'Callback', @(s,~) updateTremor(s.Value));

% -------------------------------------------------------------
% REAL-TIME SIMULATION ENGINE (TIMER)
% -------------------------------------------------------------
tmr = timer('ExecutionMode', 'fixedRate', 'Period', 0.2, 'TimerFcn', @(~,~) stepSim());
start(tmr);

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
        set(sld_slope, 'Value', 35); set(lbl_slope_val, 'String', '35°');
        set(sld_tremor, 'Value', 0); set(lbl_tremor_val, 'String', '0.0 deg/h');
        updateMountainGeometry();
        set(h_slide_arrow, 'Visible', 'off');
        set(p_banner, 'String', 'STATUS: SYSTEM RESET  |  SLOPE STABLE (FoS = 1.82)  |  ALL NOMINAL', ...
            'BackgroundColor', [0.12 0.50 0.22]);
        fprintf('System reset to nominal conditions.\n');
    end

    % Button 2: Simulate Configurable Storm with Disaster Prediction & Accelerated Playback
    function triggerCloudburst()
        prompt = { ...
            'Rainfall Intensity (mm/h) [10 to 120]:', ...
            'Storm Duration (Hours) [e.g. 1.0 to 8.0]:', ...
            'Hillside Slope Angle (degrees) [20 to 50]:', ...
            'Antecedent Soil Moisture (%) [15 to 55]:'};
        dlgtitle = 'Rainfall Event & Disaster Prediction Setup';
        dims = [1 55];
        definput = {'75', '3.0', num2str(state.beta), sprintf('%.1f', state.moist * 100)};
        answer = inputdlg(prompt, dlgtitle, dims, definput);
        
        if isempty(answer)
            return; % User pressed Cancel
        end
        
        rain_in = str2double(answer{1});
        dur_hr_in = str2double(answer{2});
        beta_in = str2double(answer{3});
        moist_in = str2double(answer{4});
        
        if isnan(rain_in) || isnan(dur_hr_in) || isnan(beta_in) || isnan(moist_in)
            errordlg('Please enter valid numerical values.', 'Input Error');
            return;
        end
        
        % Validate & clamp within safe physical limits
        rain_val = max(10, min(120, rain_in));
        dur_hr = max(0.2, min(12.0, dur_hr_in));
        beta_val = max(20, min(50, beta_in));
        moist_val = max(15, min(55, moist_in)) / 100;
        
        % Apply slope & moisture setup
        updateSlope(beta_val);
        set(sld_slope, 'Value', beta_val);
        state.moist = moist_val;
        
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
        
        gamma_s_val = 18; z_val = 1.5; phi_rad_val = deg2rad(30);
        beta_rad_val = deg2rad(beta_val);
        norm_s = gamma_s_val * z_val * (cos(beta_rad_val))^2;
        driv_s = gamma_s_val * z_val * sin(beta_rad_val) * cos(beta_rad_val);
        
        for k = 1:(N_storm_steps + N_post_steps)
            curr_t_hr = (k / N_storm_steps) * dur_hr;
            if k <= N_storm_steps
                r_step = rain_val;
            else
                r_step = 0;
            end
            
            inf_step = (r_step / 100) * 0.0035;
            drn_step = 0.0006 * max(0, sim_moist - 0.18);
            sim_moist = min(0.58, max(0.15, sim_moist + inf_step - drn_step));
            if sim_moist > max_proj_moist
                max_proj_moist = sim_moist;
            end
            
            if sim_moist > 0.34
                u_step = 9.81 * (sim_moist - 0.34) * 1.5 * 3.5;
            else
                u_step = 0;
            end
            if u_step > max_proj_u
                max_proj_u = u_step;
            end
            
            eff_s = max(norm_s - u_step, 0.05);
            res_s = state.c_prime + eff_s * tan(phi_rad_val);
            k_fos = max(0.2, res_s / max(driv_s, 0.001));
            
            if k_fos < min_proj_fos
                min_proj_fos = k_fos;
            end
            
            if time_to_advisory_hr < 0 && (k_fos <= 1.45 || sim_moist >= 0.24 || r_step >= 25)
                time_to_advisory_hr = curr_t_hr;
            end
            if time_to_collapse_hr < 0 && k_fos <= 1.05
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
                'EVENT DETAILS:\n' ...
                '  - Rainfall Rate: %.0f mm/h for %.1f Hours (Total: %.0f mm)\n' ...
                '  - Terrain Slope: %.0f deg | Antecedent Moisture: %.1f%%\n\n' ...
                'PREDICTIVE IMPACT CONSEQUENCES:\n' ...
                '  - Catastrophic Failure: Forecast at T + %.1f hr (%.0f mins into storm)\n' ...
                '  - Advisory Stage (Yellow): Triggered at T + %.1f hr\n' ...
                '  - Advance Evacuation Lead Time: %.0f minutes ahead of collapse\n' ...
                '  - Critical Factor of Safety: FoS drops to %.2f (FAIL)\n' ...
                '  - Peak Soil Saturation: %.1f%% (Pore Pressure: %.1f kPa)\n\n' ...
                'ACTION MANDATE: EVACUATION ORDER RECOMMENDED.\n\n' ...
                'Press OK to begin time-accelerated playback (~15 seconds on graphs).'], ...
                rain_val, dur_hr, rain_val * dur_hr, beta_val, moist_val*100, ...
                time_to_collapse_hr, time_to_collapse_hr*60, time_to_advisory_hr, ...
                lead_time_min, min_proj_fos, max_proj_moist*100, max_proj_u);
            helpdlg(report_msg, 'DISASTER PREDICTION REPORT');
        else
            report_msg = sprintf([ ...
                '===============================================\n' ...
                '       PREDICTIVE FORECAST: SLOPE REMAINS STABLE\n' ...
                '===============================================\n\n' ...
                'EVENT DETAILS:\n' ...
                '  - Rainfall Rate: %.0f mm/h for %.1f Hours\n' ...
                '  - Terrain Slope: %.0f deg | Antecedent Moisture: %.1f%%\n\n' ...
                'PREDICTIVE IMPACT CONSEQUENCES:\n' ...
                '  - Slope Stability: Stable throughout event\n' ...
                '  - Minimum Factor of Safety: FoS = %.2f (Above critical 1.0)\n' ...
                '  - Peak Soil Saturation: %.1f%% (Pore Pressure: %.1f kPa)\n\n' ...
                'ACTION MANDATE: CONTINUED ROUTINE MONITORING.\n\n' ...
                'Press OK to begin time-accelerated playback (~15 seconds on graphs).'], ...
                rain_val, dur_hr, beta_val, moist_val*100, min_proj_fos, max_proj_moist*100, max_proj_u);
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
    function updateMountainGeometry()
        slope_h = 1 + 6 * tan(deg2rad(state.beta)) / tan(deg2rad(50));
        % Bedrock points
        set(h_bedrock, 'XData', [0 10 10 0], 'YData', [0 0 slope_h*0.5 slope_h*0.2]);
        % Slip plane line
        set(h_slip_line, 'XData', [0 10], 'YData', [slope_h*0.2 slope_h*0.5]);
        % Soil points (including slip displacement if failed)
        off_x = state.slip_offset;
        off_y = -state.slip_offset * 0.4;
        set(h_soil, 'XData', [0+off_x 10+off_x 10+off_x 0+off_x], ...
            'YData', [slope_h*0.2+off_y slope_h*0.5+off_y slope_h+off_y slope_h*0.4+off_y]);
        set(txt_angle_overlay, 'String', sprintf('Slope: %.0f°', state.beta));

    end

    % Main Simulation Step (Every 0.2s)
    function stepSim()
        if ~isvalid(f); return; end
        
        state.sim_time = state.sim_time + 0.2;
        
        sim_elapsed_hr = 0;
        if state.storm_active
            state.storm_step_count = state.storm_step_count + 1;
            sim_elapsed_hr = (state.storm_step_count / state.storm_total_steps) * state.storm_dur_hr;
            if state.storm_step_count >= state.storm_total_steps
                % Storm duration complete! Automatically shut off rain
                state.storm_active = false;
                state.rain = 0;
                set(sld_rain, 'Value', 0);
                set(lbl_rain_val, 'String', '0 mm/h');
                fprintf('Storm duration ended (%.1f hr event finished). Rain shut off.\n', state.storm_dur_hr);
            end
        end
        
        % 1. Hydrology: Infiltration & Cumulative Rain
        state.cum_rain = state.cum_rain + (state.rain / 3600) * 0.2;
        infil = (state.rain / 100) * 0.0035;
        drainage = 0.0006 * max(0, state.moist - 0.18);
        state.moist = min(0.58, max(0.15, state.moist + infil - drainage));
        
        % Pore-water pressure (kPa) driven by soil moisture infiltration
        theta_crit = 0.34;
        if state.moist > theta_crit
            state.pore_pressure = 9.81 * (state.moist - theta_crit) * 1.5 * 3.5;
        else
            state.pore_pressure = 0;
        end
        
        % 2. Geotechnical Stability (Factor of Safety)
        gamma_s = 18; z = 1.5; phi_rad = deg2rad(30);
        beta_rad = deg2rad(state.beta);
        normal_stress = gamma_s * z * (cos(beta_rad))^2;
        eff_stress = max(normal_stress - state.pore_pressure, 0.05);
        resisting = state.c_prime + eff_stress * tan(phi_rad);
        driving = gamma_s * z * sin(beta_rad) * cos(beta_rad);
        
        state.prev_fos = state.fos;
        state.fos = max(0.2, resisting / max(driving, 0.001));
        
        % 3. Predictive Disaster Forecaster (Smooth derivative filter)
        dt = 0.2;
        raw_dfos = (state.fos - state.prev_fos) / dt;
        state.dfos_dt = 0.15 * raw_dfos + 0.85 * state.dfos_dt; % Low-pass filter
        lead_sec = 600; % 10 minutes ahead
        state.fos_pred = max(0.1, min(2.5, state.fos + (state.dfos_dt * lead_sec)));
        
        % Estimated Time-to-Failure (TTF in minutes)
        if state.dfos_dt < -0.00003 && state.fos > 1.05
            ttf_sec = (state.fos - 1.0) / (-state.dfos_dt);
            state.time_to_collapse = max(1, min(90, ttf_sec / 60));
        elseif state.fos <= 1.05
            state.time_to_collapse = 0; % Slope reached failure
        else
            state.time_to_collapse = 999;
        end
        
        % 4. Kinematics (Ground Velocity / Tilt Rate)
        if state.fos > 1.30
            auto_creep = 0.04;
        elseif state.fos > 1.05
            auto_creep = (1.30 - state.fos) * 5.0;
        else
            auto_creep = 1.5 + (1.05 - state.fos) * 18.0;
        end
        state.tilt_rate = min(10, auto_creep + state.manual_tilt);
        
        % Physical slip displacement animation if FoS < 1.0
        if state.fos < 1.0
            state.slip_offset = min(1.2, state.slip_offset + 0.03);
        else
            state.slip_offset = max(0, state.slip_offset - 0.02);
        end
        
        % 5. Multi-tier Emergency Decision (Decoupled with Guaranteed Intermediate Advisory Stage)
        % Level 2: RED (Critical Failure & Immediate Evacuation)
        if state.fos <= 1.08 || ...
           (state.moist >= 0.40 && state.fos <= 1.20) || ...
           (state.tilt_rate >= 2.2 && state.fos <= 1.25) || ...
           (state.time_to_collapse <= 10 && state.fos < 1.25)
            state.alert_level = 2; % EVACUATE NOW
        % Level 1: YELLOW / AMBER (Intermediate Advisory Stage)
        elseif state.rain >= 25 || ...
               state.moist >= 0.24 || ...
               state.fos <= 1.45 || ...
               state.tilt_rate >= 0.6 || ...
               (state.time_to_collapse <= 45 && state.time_to_collapse > 10)
            state.alert_level = 1; % PREDICTIVE ADVISORY
        % Level 0: GREEN (Safe / Nominal)
        else
            state.alert_level = 0; % SAFE
        end
        
        % 6. UPDATE GRAPHICAL CANVASES
        % Update Mountain Visuals
        updateMountainGeometry();
        
        water_y = 1.0 + (state.moist - 0.18) * 5.0;
        set(h_water_table, 'YData', [water_y*0.7, water_y*1.4]);
        
        if state.alert_level == 2
            set(h_soil, 'FaceColor', [0.85 0.15 0.15]); % Red
            set(h_slide_arrow, 'Visible', 'on');
            set(h_surface_items, 'String', '[ CRITICAL DEFORMATION ZONE ]', 'Color', [0.80 0.05 0.05]);
            set(txt_fos_overlay, 'String', sprintf('FoS: %.2f (CRITICAL)', state.fos), 'Color', [0.80 0.05 0.05]);
            if state.storm_active
                set(p_banner, 'String', sprintf('EMERGENCY [STAGE 2/2]: ACCELERATED STORM (%.1fh event, T+%.1fh) - CRITICAL COLLAPSE IN PROGRESS! EVACUATE!', state.storm_dur_hr, sim_elapsed_hr), ...
                    'BackgroundColor', [0.85 0.15 0.15]);
            else
                set(p_banner, 'String', sprintf('EMERGENCY [STAGE 2/2]: PREDICTED COLLAPSE IN %.1f MINS! SIREN & EVACUATION BROADCAST ACTIVE!', max(0.1, state.time_to_collapse)), ...
                    'BackgroundColor', [0.85 0.15 0.15]);
            end
        elseif state.alert_level == 1
            set(h_soil, 'FaceColor', [0.85 0.65 0.15]); % Yellow
            set(h_slide_arrow, 'Visible', 'off');
            set(h_surface_items, ...
            'String', '[ ACTIVE SATURATION ZONE ]', ...
            'Color', [0.30 0.15 0.00], ...
            'FontSize', 11, ...
            'FontWeight', 'bold');
            set(txt_fos_overlay, 'String', sprintf('FoS: %.2f (Degrading)', state.fos), 'Color', [0.65 0.35 0.00]);
            if state.storm_active
                set(p_banner, 'String', sprintf('PREDICTIVE ADVISORY [STAGE 1/2]: ACCELERATED STORM (%.1fh event, T+%.1fh) - INFILTRATING (Moist: %.0f%%, FoS: %.2f)', state.storm_dur_hr, sim_elapsed_hr, state.moist*100, state.fos), ...
                    'BackgroundColor', [0.85 0.55 0.05]);
            else
                set(p_banner, 'String', sprintf('PREDICTIVE ADVISORY [STAGE 1/2]: HEAVY RAIN INFILTRATING (Moist: %.0f%%, FoS: %.2f) - EARLY WARNING ACTIVE', state.moist*100, state.fos), ...
                    'BackgroundColor', [0.85 0.55 0.05]);
            end
        else
            set(h_soil, 'FaceColor', [0.18 0.48 0.20]); % Green
            set(h_slide_arrow, 'Visible', 'off');
            set(h_surface_items, 'String', '[ Surface Settlement Zone ]', 'Color', [0.10 0.40 0.15]);
            set(txt_fos_overlay, 'String', sprintf('FoS: %.2f (Stable)', state.fos), 'Color', [0.10 0.45 0.20]);
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
