function out = lews_physics(action, varargin)
%% LEWS_PHYSICS - Authoritative Geotechnical & Hydrological Core
% Provides unified limit equilibrium slope stability, pore-water pressure,
% infiltration hydrology, and kinematics across dashboard, Simulink, and tests.

switch lower(action)
    case 'params'
        % Standard geotechnical & hydrological baseline parameters
        p.beta_deg    = 35;       % Slope inclination (degrees)
        p.c_prime     = 12;       % Effective soil cohesion (kPa)
        p.phi_deg     = 30;       % Internal friction angle (degrees)
        p.gamma_s     = 18;       % Soil unit weight (kN/m^3)
        p.gamma_w     = 9.81;     % Water unit weight (kN/m^3)
        p.z           = 1.5;      % Failure plane depth (m)
        p.theta_field = 0.18;     % Baseline field-capacity moisture (18%)
        p.theta_crit  = 0.34;     % Moisture threshold for positive pore pressure
        p.theta_sat   = 0.55;     % Saturated moisture capacity / porosity
        p.k_drain     = 0.000025; % Physical gravity drainage rate (s^-1)
        out = p;
        
    case 'pore_pressure'
        % u = lews_physics('pore_pressure', moist, theta_crit, gamma_w, z, beta_deg)
        moist = varargin{1};
        p = lews_physics('params');
        if nargin >= 3 && ~isempty(varargin{2}), p.theta_crit = varargin{2}; end
        if nargin >= 4 && ~isempty(varargin{3}), p.gamma_w = varargin{3}; end
        if nargin >= 5 && ~isempty(varargin{4}), p.z = varargin{4}; end
        if nargin >= 6 && ~isempty(varargin{5}), p.beta_deg = varargin{5}; end
        
        if moist > p.theta_crit
            head_factor = (moist - p.theta_crit) / (p.theta_sat - p.theta_crit);
            out = p.gamma_w * (p.z * cosd(p.beta_deg)^2) * head_factor * 1.8;
        else
            out = 0.0;
        end
        
    case 'fos'
        % FoS = lews_physics('fos', beta_deg, c_prime, phi_deg, gamma_s, z, u, tremor_rate)
        p = lews_physics('params');
        beta_deg    = varargin{1};
        c_prime     = p.c_prime;
        phi_deg     = p.phi_deg;
        gamma_s     = p.gamma_s;
        z           = p.z;
        u           = 0.0;
        tremor_rate = 0.0;
        
        if nargin >= 3 && ~isempty(varargin{2}), c_prime = varargin{2}; end
        if nargin >= 4 && ~isempty(varargin{3}), phi_deg = varargin{3}; end
        if nargin >= 5 && ~isempty(varargin{4}), gamma_s = varargin{4}; end
        if nargin >= 6 && ~isempty(varargin{5}), z = varargin{5}; end
        if nargin >= 7 && ~isempty(varargin{6}), u = varargin{6}; end
        if nargin >= 8 && ~isempty(varargin{7}), tremor_rate = varargin{7}; end
        
        beta_rad = deg2rad(beta_deg);
        phi_rad  = deg2rad(phi_deg);
        
        % Pseudostatic seismic coefficient
        k_h = max(0, tremor_rate) * 0.015;
        
        normal_stress = gamma_s * z * (cos(beta_rad) - k_h * sin(beta_rad)) * cos(beta_rad);
        eff_stress    = max(normal_stress - u, 0.05);
        resisting     = c_prime + eff_stress * tan(phi_rad);
        driving       = gamma_s * z * (sin(beta_rad) + k_h * cos(beta_rad)) * cos(beta_rad);
        
        out = max(0.1, resisting / max(driving, 0.001));
        
    case 'hydrology_step'
        % out = lews_physics('hydrology_step', current_moist, rain_rate, dt_sec, current_cum_rain)
        current_moist = varargin{1};
        rain_rate     = varargin{2}; % mm/h
        dt_sec        = varargin{3}; % physical time step in seconds
        cum_rain      = 0;
        if nargin >= 5 && ~isempty(varargin{4}), cum_rain = varargin{4}; end
        
        p = lews_physics('params');
        
        % 1. Physical cumulative rainfall accumulation (mm)
        cum_rain = cum_rain + (rain_rate / 3600) * dt_sec;
        
        % 2. Soil water balance (mass conservation over soil column depth z)
        infil_mm = (rain_rate / 3600) * dt_sec * 0.85; % 85% infiltration, 15% surface runoff
        delta_theta_infil = (infil_mm / 1000) / p.z;
        
        % Gravity drainage flux relaxation towards field capacity
        drainage_mm = (p.k_drain * 1000) * max(0, current_moist - p.theta_field) * dt_sec;
        delta_theta_drain = (drainage_mm / 1000) / p.z;
        
        new_moist = min(p.theta_sat, max(0.12, current_moist + delta_theta_infil - delta_theta_drain));
        res.moist = new_moist;
        res.cum_rain = cum_rain;
        out = res;
        
    case 'kinematics'
        % tilt_rate = lews_physics('kinematics', fos, tremor_rate)
        fos         = varargin{1};
        tremor_rate = 0;
        if nargin >= 3 && ~isempty(varargin{2}), tremor_rate = varargin{2}; end
        
        if fos > 1.30
            auto_creep = 0.04;
        elseif fos > 1.05
            auto_creep = (1.30 - fos) * 5.0;
        else
            auto_creep = 1.5 + (1.05 - fos) * 18.0;
        end
        out = min(10.0, auto_creep + tremor_rate);
        
    otherwise
        error('Unknown action in lews_physics: %s', action);
end
end
