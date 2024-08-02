--[[

MIT License

Copyright(c) 2022-2024 Reality XP

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and /or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions :

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

]]--

if XPLANE_VERSION < 12060 then logMsg("This script is not compatible with this X-Plane version") return end
if not SUPPORTS_FLOATING_WINDOWS then logMsg("ImgUI is not supported by your FlyWithLua version") return end

--[[ Script Globals ]]--

-- set to 1 to disable all the script overrides at once.
-- set to 0 and reload the script to enable and see the changes.
local RXP_XP12E_DEBUG_DISABLE_ALL = 0

local RXP_XP12E_WINDOW_TITLE = "Reality XP X-Plane 12 Enhancer"
local RXP_XP12E_VERSION_NMBR = "v1.9.6" 
local RXP_XP12E_XPL_VERS_MAX = 12110
local RXP_XP12E_XPL_VERS_MIN = "12.1.1"

local rxp_xp12_enhancer = {

    -------------------------------------------------------------------------------
    -- Description                                                               --
    ------------------------------------------------------------------------------- 
    --[[

    This script is enhancing the X-Plane 12 visual experience and provides a set of 
    options which are carrefuly selected and adjusted for their direct and visible
    changes. The main goal is to achieve a more realistic rendition inside and out,
    while at the same time trying to correct some of the most glaring limitations
    of X-Plane 12 rendering engine. This script is only modifying a few datarefs at
    runtime in order to improve, among other things, the following: exposure, tone
    mapping, white balance, sky, atmosphere, volumetric clouds and night lighting. 

    The script also handles mettering and auto-exposure in order to try reaching a 
    better balance between brights and darks when in-cockpit, to get closer to the
    sunny 16 rule when outside, to maintain a consistent level of exposure whether
    zooming the view, or to maintain a natural change of exposure when looking 
    from darker to brighter places. 

    The script offers a settings window which can show up automatically when the
    script loads, otherwise in using either this menu or command:

        Menu:    FlyWithLua > FlyWithLua Macros > RealityXP X-Plane 12 Enhancer...
        Command: 'RXP/Utility/Enhancer/toggle_window'

    In order to configure the script, change any of the 'Public' settings below and
    load or reload the script with FlyWithLua. These 'Public' settings are used by
    default unless a companion rxp-xp12-enhancer.ini file is present in the same
    folder (in the FWL scripts folder). This companion .ini file persists all of the
    settings between sessions, loads automatically when the scripts loads, and saves
    automatically when the settings window closes.

    NB: if using the supplemental '1000_ligths_close.png', also change the following
    option for better results: override_lights_sheet = 1

    NB: some of the settings are not revertible because XP12 is varying some values,
    which is preventing the script from restoring the default dataref values. Change
    the script settings and restart XP12 in this case instead.

    ]]--

    -------------------------------------------------------------------------------
    -- Public: User Default Settings when the script loads                       --
    -------------------------------------------------------------------------------

    settings = {

        -- Typical: auto_show_wnd = false, auto_ibl = true (RTX 40xx), fog_light = false, contrast = <any> (true for airliner cockpits), and all others = true

        auto_show_wnd           = true ,          -- Show the settings window automatically when the script loads.

        override_exposure       = true ,          -- Use realistic exposure and tone mapping both in-cockpit and outside.
        override_contrast       = false,          -- Allow adjusting tone mapping strength and reduce the apparent cockpit darkness against bright skies (req. override_exposure).
        override_contrast_level = 0    ,          -- The default amount of contrast when the script loads, between 0 (low) and 10 (hi) (req. override_contrast).
        override_contrast_range = true ,          -- Use no less than half contrast (0.5) when true (same as in previous versions), or use the lowest minimum (1.0) when false (same as XP12) (req. override_exposure).
        override_illumination   = true ,          -- Enhance global illumination (req. override_exposure).
        override_lights         = true ,          -- Enhance night lighting, moon and stars (req. override_exposure).
        override_lights_sheet   = 0    ,          -- Select sprite sheet options (1000_lights_close.png): 0: using XP12 (default sheet), 1: using RXP (optional sheet).
        override_shadows        = true ,          -- Enhance cascaded shadow maps range with minimal fps loss (req. override_exposure).
        
        override_clouds         = true ,          -- Enhance cloud details, lightning strikes and smoother cloud shadows.
        override_rain           = true ,          -- Enable more realistic 3D rain in dynamically adjusting the size of the rain drops size.
        override_rain_lines     = true ,          -- Disable legacy X-Plane black rain lines (req. override_rain).
    
        override_water          = true ,          -- Enhance ocean waves, rivers and lakes, while eliminating most of the rendering moire artifacts.
        override_water_style    = 2    ,          -- Select different wave settings options, 0: v1.5 style, 1: v1.6 style, 2: v1.7 style (req. override_water).
        -- override_turbidity      = false,          -- Disable turbidity with enable reflections, can help rendering water and shores when using orthos and/or meshes (req. override_water).
        
        override_ssao           = true ,          -- Enhance SSAO look and feel and reduce flickering artifacts.
        override_ssao_cockpit   = true ,          -- Enable SSAO in the cockpit (req. override_ssao).
        
        override_bloom_effect   = true ,          -- Disable bloom effect in order to eliminate smearing and/or flickering.
        override_auto_ibl       = false,          -- Enable ambient lighting auto-update (experimental - medium fps hit).
        override_fog_light      = false,          -- Enable volumetric light (experimental - large fps hit).

        override_sharpen_level  = 95   ,          -- The level of sharpness when using AMD FidelityFX™ Super Resolution mode (0 to 100)

    },

    -------------------------------------------------------------------------------
    -- Private: Don't edit or change                                             --
    -------------------------------------------------------------------------------

    wnd = nil, run_once = false, lut = {
        
        -- Override Exposure and Global Illumination:
        ['tonemap/blend']                       = { nil     , nil , 0 },-- varying  (v12.06) use a mix of ACESFilmic and Uncharted2 in order to assist exposure
        ['tonemap/desaturate']                  = { 0.05    , nil , 0 },-- varying  (v12.06) 0.025 is the maximum until colour hues shift too much (disable varying)
        ['tonemap/white_balance_k']             = { 6750    , nil , 1 },-- 6500     (v12.09) slightly warmer in order to match scattering colour temp
        ['photometric/ev100_bias']              = { nil     , nil , 0 },-- varying  (v12.06) disable varying (lut based)
        ['photometric/ev100_min']               = { 4.0     , nil , 1 },-- 5.0      (v12.06) ideally we would use 0 but some of the XP12 render fx seem hard coded for 5
        ['photometric/ev100_max']               = { 15.0    , nil , 1 },-- 15.0     (v12.06)
        ['photometric/interior_lit_boost']      = { 6.0     , nil , 1 },-- 1.0      (v12.06)    -- 25.0
        ['panel/auto_atten_stops']              = { 2.0     , nil , 1 },-- 3.5      (v12.06)    -- -2.5
        ['lighting/E_sun_lx']                   = { nil     , nil , 1 },-- 115000   (v12.06)
        ['scattering/earth_albedo']             = { 0.28    , nil , 1 },-- 0.1      (v12.06)
        ['cube/lod_bias_forest']                = { 999999.0, nil , 1 },-- 5        (v12.08)
        ['cube/lod_bias_objects']               = { 999999.0, nil , 1 },-- 10       (v12.08)
        ['cube/max_dsf_dist']                   = { 999999.0, nil , 1 },-- 15000    (v12.08)
        ['cube_map/extra samples']              = { 9.0     , nil , 1 },-- 1        (v12.06)
        ['cubemap/interior_proj_size']          = { 100.0   , nil , 1 },-- 100.0    (v12.06)
        ['cubemap/pmrem/rough_mip1']            = { 0.5     , nil , 1 },-- 0.3      (v12.06)
        ['cubemap/pmrem/rough_mip2']            = { 0.5     , nil , 1 },-- 0.5      (v12.06)
        ['cubemap/pmrem/rough_mip3']            = { 0.32    , nil , 1 },-- 0.75     (v12.06)
        ['cubemap/pmrem/rough_mip4']            = { 1.0     , nil , 1 },-- 0.85     (v12.06)
        ['cubemap/pmrem/rough_mip5']            = { 1.0     , nil , 1 },-- 1.0      (v12.06)
        ['cubemap/x_scale']                     = { 0.0     , nil , 1 },-- 0.0      (v12.06)
        ['cubemap/z_offset']                    = { 0.0     , nil , 1 },-- 0.1      (v12.06)
        ['nightvision/static_alpha']            = { 0.01    , nil , 1 },-- 0.03     (v12.06)
        ["debug/histo_bottom"]                  = { nil     , nil,  1 },-- -2.0     (v12.06)
        ["debug/histo_top"   ]                  = { nil     , nil,  1 },-- 18.0     (v12.06)

        -- Ozone: Reduce purple skies and balance out scenery tone white balance
        -- ['atmo/ozone_b']                    = { 0.15    , nil , 0 },-- 0.085    (v12.05) - more blue  BGR(0.15, 2.40, 2.85)
        -- ['atmo/ozone_g']                    = { 2.00    , nil , 0 },-- 1.881    (v12.05) - less blue  BGR(0.15, 2.00, 2.25)
        -- ['atmo/ozone_r']                    = { 2.25    , nil , 0 },-- 0.65     (v12.05) - balanced   BGR(0.15, 2.04, 2.42)
        -- ['atmo/ozone_center']               = { 22500   , nil , 0 },-- 25000    (v12.05)
        -- ['atmo/ozone_width']                = { 45000   , nil , 0 },-- 30000    (v12.05)

        -- Override Mettering (natural exp curve in both 3D and VR):
        ['autoexposure/gain_hi']                = { 0.5     , nil , 1 },-- 0.35     (v12.06)
        ['autoexposure/gain_lo']                = { 0.5     , nil , 1 },-- 0.65     (v12.06)
        ['autoexposure/null_hi']                = { 0.0     , nil , 1 },-- 1.0      (v12.06)
        ['autoexposure/null_lo']                = { 0.0     , nil , 1 },-- 1.0      (v12.06)
        ['autoexposure/trim_hi']                = { 0.1     , nil , 1 },-- 0.0      (v12.06)
        ['autoexposure/trim_lo']                = { 0.1     , nil , 1 },-- 0.0      (v12.06)
        ['exposure/speed_down']                 = { 10.0    , nil , 1 },-- 5.0      (v12.06)
        ['exposure/speed_up']                   = { 10.0    , nil , 1 },-- 3.0      (v12.06)

        ['skyc/shadow_level_clean']             = { 1.0     , nil , 1 },-- 1.0      (v12.06)
        ['skyc/shadow_level_foggy']             = { 1.0     , nil , 1 },-- 0.1      (v12.06)
        ['skyc/shadow_level_hazy' ]             = { 1.0     , nil , 1 },-- 0.2      (v12.06)
        ['skyc/shadow_level_hialt']             = { 1.0     , nil , 1 },-- 1.0      (v12.06)
        ['skyc/shadow_level_mount']             = { 1.0     , nil , 1 },-- 1.0      (v12.06)
        ['skyc/shadow_level_ocast']             = { 1.0     , nil , 1 },-- 0.3      (v12.06)
        ['skyc/shadow_level_orbit']             = { 1.0     , nil , 1 },-- 1.0      (v12.06)
        ['skyc/shadow_level_snowy']             = { 1.0     , nil , 1 },-- 0.2      (v12.06)
        ['skyc/shadow_level_sockd']             = { 1.0     , nil , 1 },-- 0.1      (v12.06)
        ['skyc/shadow_level_strat']             = { 1.0     , nil , 1 },-- 0.1      (v12.06)
        ['skyc/shadow_offset_clean']            = { 1.0     , nil , 1 },-- 1.0      (v12.06)
        ['skyc/shadow_offset_foggy']            = { 1.0     , nil , 1 },-- 0.1      (v12.06)
        ['skyc/shadow_offset_hazy' ]            = { 1.0     , nil , 1 },-- 0.2      (v12.06)
        ['skyc/shadow_offset_hialt']            = { 1.0     , nil , 1 },-- 1.0      (v12.06)
        ['skyc/shadow_offset_mount']            = { 1.0     , nil , 1 },-- 1.0      (v12.06)
        ['skyc/shadow_offset_ocast']            = { 1.0     , nil , 1 },-- 0.3      (v12.06)
        ['skyc/shadow_offset_orbit']            = { 1.0     , nil , 1 },-- 1.0      (v12.06)
        ['skyc/shadow_offset_snowy']            = { 1.0     , nil , 1 },-- 0.5      (v12.06)
        ['skyc/shadow_offset_sockd']            = { 1.0     , nil , 1 },-- 0.5      (v12.06)
        ['skyc/shadow_offset_strat']            = { 1.0     , nil , 1 },-- 0.1      (v12.06)
        ['skyc/min_shadow_angle']               = { -15.0   , nil , 1 },-- -15.0    (v12.06)
        ['skyc/max_shadow_angle']               = { 2.0     , nil , 1 },--  2.0     (v12.06)

        -- Override Water:
        ['water/projector/displacement']        = { 0.0     , nil , 3 },-- 7.0      (v12.06)
        ['water/wake_amp_ratio']                = { 1.0     , nil , 3 },-- 1.0      (v12.06)
        ['water/cascade_0_scale']               = { 2.0     , nil , 3 },-- 1.0      (v12.06) 
        ['water/cascade_1_scale']               = { 0.5     , nil , 3 },-- 1.0      (v12.06)
        ['water/cascade_2_scale']               = { 0.32    , nil , 3 },-- 1.0      (v12.06)
        ['water/cascade_3_scale']               = { 0.32    , nil , 3 },-- 1.0      (v12.06)
        ['water/h_displace_lambda']             = { 1.75    , nil , 3 },-- 1.0      (v12.06)
        ['water/foam_bias']                     = { 0.73    , nil , 3 },-- 0.8      (v12.06)
        ['water/foam_scale']                    = { 0.95    , nil , 3 },-- 2.4      (v12.06)
        ['water/F0']                            = { 0.02    , nil , 3 },-- 0.02     (v12.06)
        ['water/gloss']                         = { 0.82    , nil , 3 },-- 0.78     (v12.06)
        ['water/spectrum/fetch_hi_m']           = { 10000.0 , nil , 3 },-- 5000.0   (v12.06)
        ['water/spectrum/fetch_lo_m']           = { 5000.0  , nil , 3 },-- 1000.0   (v12.06)
        ['water/spectrum/fetch_multiplier']     = { 20.0    , nil , 3 },-- 10.0     (v12.06)
        -- ['water/enable_refraction']             = { nil     , nil , 3 },-- 0.0      (v12.06)
        ['water/enable_turbidity']              = { nil     , nil , 3 },-- 1.0      (v12.06)
        -- ['water/turbidity']                     = { 0.1     , nil , 3 },-- 2.0      (v12.06)
        -- ['water/turbidity/cutoff']              = { nil     , nil , 3 },-- -4.60517 (v12.06)

        -- Override Night Lighting:
        ['lights/photobb/hack_ev_hi']           = { 0       , nil , 4 },-- 15.0     (v12.06)
        ['lights/photobb/hack_ev_lo']           = { 0       , nil , 4 },--  7.0     (v12.06)
        ['lights/photobb/hack_value_hi']        = { 0       , nil , 4 },-- 250000.0 (v12.06)
        ['lights/photobb/hack_value_lo']        = { 0       , nil , 4 },-- 15000.0  (v12.06)
        ['lights/photobb/dist_exp']             = { -1.6    , nil , 4 },-- -1.75    (v12.06)
        ['lights/photobb/attenuation1']         = { 0.5     , nil , 4 },-- 4.5      (v12.06)
        ['lights/photobb/exp_lim1']             = { 8       , nil , 4 },-- 10       (v12.06)
        ['lights/photobb/cellx1']               = { 8       , nil , 4 },-- 8        (v12.06)
        ['lights/photobb/celly1']               = { 4       , nil , 4 },-- 4        (v12.06)
        ['lights/photobb/mult1']                = { 2       , nil , 4 },-- 2        (v12.06)
        ['lights/photobb/size1']                = { 0.75    , nil , 4 },-- 0.65     (v12.06)
        ['lights/photobb/attenuation2']         = { 0.0005  , nil , 4 },-- 0.002    (v12.06)
        ['lights/photobb/exp_lim2']             = { 6       , nil , 4 },-- 8        (v12.06)
        ['lights/photobb/cellx2']               = { 8       , nil , 4 },-- 8        (v12.06)
        ['lights/photobb/celly2']               = { 6       , nil , 4 },-- 6        (v12.06)
        ['lights/photobb/mult2']                = { 2       , nil , 4 },-- 2        (v12.06)
        ['lights/photobb/size2']                = { 12      , nil , 4 },-- 15.0     (v12.06)
        ['lights/photobb/attenuation3']         = { 0.00001 , nil , 4 },-- 0.000015 (v12.06)
        ['lights/photobb/exp_lim3']             = { 5       , nil , 4 },-- 6        (v12.06)
        ['lights/photobb/cellx3']               = { 14      , nil , 4 },-- 8        (v12.06)
        ['lights/photobb/celly3']               = { 2       , nil , 4 },-- 0        (v12.06)
        ['lights/photobb/mult3']                = { 2       , nil , 4 },-- 4        (v12.06)
        ['lights/photobb/size3']                = { 35.0    , nil , 4 },-- 40.0     (v12.06)
        ['lights/exponent_far']                 = { 0.28    , nil , 4 },-- 0.42     (v12.06)
        ['lights/exponent_near']                = { 0.38    , nil , 4 },-- 0.38     (v12.06)
        ['lights/legacy_luminenace_billboards'] = { 100.0   , nil , 4 },-- 100.0    (v12.06)
        ['lights/legacy_luminenace_spills']     = { 20.0    , nil , 4 },-- 52.0     (v12.06)
        ['lights/spill_cutoff_level']           = { 0.05    , nil , 4 },-- 0.025    (v12.06)
        ['lightning/brightness']                = { 1000.0  , nil , 4 },-- 10.0     (v12.06)
        ['terrain/far_lit_ratio']               = { 0.125   , nil , 4 },-- 0.15     (v12.06)
        ['lighting/E_moon_lx']                  = { 0.5     , nil , 4 },-- 0.6      (v12.06)
        ['moon/nits']                           = { 75      , nil , 4 },-- 500      (v12.06)
        ['stars/gain_photometric']              = { 75      , nil , 4 },-- 20.0     (v12.06)
        ['cars/lod_min']                        = { 15000   , nil , 4 },--10000.0   (v12.09)
        ['terrain/car_lod_boost']               = { 1.0     , nil , 4 },-- 1.0      (v12.06)
        ['skyc/sun_angle_cars']                 = { 10.0    , nil , 4 },--2.6       (v12.06)
        ['skyc/sun_angle_lights']               = { 3.0     , nil , 4 },--5.0       (v12.09)

        -- Override Ambient Occlusion:
        ['ssao/visibility']                     = { 0.0     , nil , 5 },-- 0.0      (v12.06)
        ['ssao/exterior_curve']                 = { 1.25    , nil , 5 },-- 1.0      (v12.06)
        ['ssao/exterior_strength']              = { 0.75    , nil , 5 },-- 1.0      (v12.06)
        ['ssao/interior']                       = { 1.0     , nil , 6 },-- 0.0      (v12.06)
        ['ssao/interior_curve']                 = { 2.25    , nil , 6 },-- 1.0      (v12.06)
        ['ssao/interior_strength']              = { 0.75    , nil , 6 },-- 1.0      (v12.06)

        -- Override Clouds:
        ['cloud/extinction']                    = { 0.7     , nil , 7 },-- 0.5      (v12.06)
        ['cloud/noise_hi_limit']                = { 75000   , nil , 7 },-- 30000    (v12.06)
        ['cloud/temporal_alpha']                = { 0.32    , nil , 7 },-- 0.15     (v12.06)
        -- ['new_clouds/shadow_blur_size']         = { 2.0     , nil , 7 },-- 1.0      (v12.06)
        -- ['new_clouds/shadow_kill_blur']         = { 0.0     , nil , 7 },-- 1.0      (v12.06)
        -- ['new_clouds/shadow_step_mtr']          = { 500.0   , nil , 7 },-- 500.0    (v12.06)
        ['new_clouds/density']                  = { 100.0   , nil , 7 },-- 125.0    (v12.06)
        ['new_clouds/march/samples_max']        = { 500.0   , nil , 7 },-- 500      (v12.06)
        ['new_clouds/march/samples_max_km']     = { 120.0   , nil , 7 },-- 60       (v12.06)
        ['new_clouds/march/samples_min']        = { 2.0     , nil , 7 },-- 2        (v12.06)
        ['new_clouds/march/seg_count']          = { 16.0    , nil , 7 },-- 7        (v12.06)
        ['new_clouds/march/seg_mul']            = { 1.35    , nil , 7 },-- 1.5      (v12.06)
        ['new_clouds/march/seg_steps']          = { 75.0    , nil , 7 },-- 80       (v12.06)
        ['new_clouds/march/step_len_start']     = { 50.0    , nil , 7 },-- 60       (v12.06)
        ['new_clouds/high_freq_amp']            = { nil     , nil , 7 },-- 0.5      (v12.06)
        ['new_clouds/high_freq_rat']            = { nil     , nil , 7 },-- 7.3      (v12.06)
        ['new_clouds/low_freq_rat']             = { nil     , nil , 7 },-- 8.0      (v12.06)

        -- ['new_clouds/ambient']                  = { 0.3     , nil , 7 },-- varying  (v12.06)
        -- ['new_clouds/direct']                   = { 0.95    , nil , 7 },-- varying  (v12.06)

        ['shadow/lod_bias_adjust']              = { 6.0     , nil , 13},-- 1.0      (v12.09)
        ['shadow/total_fade_ratio']             = { 0.75    , nil , 13},-- 0.7      (v12.09)
        ['shadow/csm/far_limit_exterior']       = { nil     , nil , 13},-- varying  (v12.09)
        ['shadow/csm/far_limit_interior']       = { nil     , nil , 13},-- varying  (v12.09)

        -- Override Rain:
        ['rain/scale']                          = { 0.45    , nil , 8 },-- 1.0      (v12.06)
        ['rain/spawn_adjust']                   = { 1500    , nil , 8 },-- 1000     (v12.06)
        ['rain/kill_3d_rain']                   = { 1       , nil , 9 },-- 0        (v12.06)

        -- Override Rain Forces:
        ['rain/acceleration_factor']            = { 1.5     , nil , 8 },-- 0.3      (v12.09)
        ['rain/dynamic_drag']                   = { 0.4     , nil , 8 },-- 0.1      (v12.09)  -- 0.3
        ['rain/force_factor']                   = { 0.07    , nil , 8 },-- 0.1      (v12.09)  -- 0.04
        ['rain/friction_dynamic']               = { 0.03    , nil , 8 },-- 0.3      (v12.09)
        ['rain/friction_static']                = { 0.07    , nil , 8 },-- 0.7      (v12.09)

        -- Override Cosmetic Features:
        ['exposure_fusion/dis_far']             = { 1       , nil , 10},-- 4        (v12.06)
        ['exposure_fusion/dis_near']            = { 1000000 , nil , 10},-- 1        (v12.06)
        ['ibl/update_mode']                     = { 1.0     , nil , 11},-- 0.0      (v12.06)
        ['lights/do_spill_fog']                 = { 1       , nil , 12},-- 0        (v12.06) 
        ['fog/std_deviation_cutoff']            = { 0.2     , nil , 12},-- 4.5      (v12.06)

        -- Override Debug Utils
        ['debug/show_histo']                    = { 1       , nil , 100 },-- 0      (v12.05)
        ['debug/luminance_histo_scale']         = { 4096    , nil , 100 },-- 512    (v12.05)
    },

    -- Internal state (don't edit)
    priv_override_clouds_march_mode = 1,    -- different cloud ray marching experimental presets, 0: v1.7 style, 1: v1.8 style (req. override_clouds).
    priv_override_clouds_noise_mode = 0,    -- different cloud noise option experimental presets, 0: default   , 1: v1.8 style (req. override_clouds).
    priv_override_eclipse_emulation = 1,    -- emulate solar eclipse, 0: disabled, 1: enabled
    -- priv_override_mettering = false,
    
    priv_blend_ratio = 0, priv_ev100_min = 0, priv_ev100_max = 0, priv_tickle_cubemaps = 0, priv_view_is_external = 2, priv_start_time = 0,
    k_ev100_bias_lut = { {5.0,3.5}, {8.0,3.0}, {11.0,0.0}, {12.0,0.0}, {12.33,-0.3}, }          -- similar to internal XP12 ev100_bias LUT
}


--[[ Helpers ]]--

local function math_lerp(t, a, b)                   return a + (b - a) * t end
local function math_clamp(v, vmin, vmax)            return math.min(math.max(v, vmin), vmax) end
local function math_ratio(v, vmin, vmax)            return math_clamp((v - vmin) / (vmax - vmin), 0.0, 1.0) end
local function math_interpolate(v, i1, i2, o1, o2)  return o1 + (o2 - o1) * (v - i1) / (i2 - i1) end
local function math_hypot(a, b)                     return math.sqrt(a*a + b*b) end

local function table_interpolate(tbl, x)
    local a = 1
    local b = #tbl
    if x <= tbl[a][1] then return tbl[a][2] elseif x >= tbl[b][1] then return tbl[b][2] end
    local m = 0
    while (b-a) > 1 do
        m = math.floor((b+a)/2)
        local v = tbl[m][1]
        if v < x then a = m elseif v > x then b = m else break end
    end
    if x == tbl[m][1] then return tbl[m][2] end
    return math_interpolate(x, tbl[a][1], tbl[b][1], tbl[a][2], tbl[b][2])
end


local function smalest_angle_deg(a, b)
    local v = b - a
    if (v > 180) then v = v - 360 elseif (v < -180) then v = v + 360 end
    return v
 end

--[[ Implementation ]]--

function rxp_xp12_enhancer:set(key, val)
    if self.lut[key] then self.lut[key][1] = val end
end

function rxp_xp12_enhancer:get(key)
    if self.lut[key] then return self.lut[key][2] else return nil end
end

function rxp_xp12_enhancer:clr(key)
    if self.lut[key] and self.lut[key][2] ~= nil then self.lut[key][1] = self.lut[key][2] end
end

function rxp_xp12_enhancer:apply(category, override)
    local idx = override and 1 or 2
    for k, v in pairs(self.lut) do 
        if not category or category == v[3] then
            if v[idx] then set("sim/private/controls/" .. k, v[idx]) end
        end
    end
end

function rxp_xp12_enhancer:update(category)
    if category == 0 then rxp_xp12_enhancer.priv_tickle_cubemaps = 5
    elseif category == 1  then
    
        -- adjust the mix of ACESFilmic and Uncharted2 in order to assist exposure.
        self.settings.override_contrast_level = math_clamp(self.settings.override_contrast_level, 0.0, 10.0)                    -- sanitize on init or update
        self.priv_blend_ratio = self.settings.override_contrast and (1.0 - self.settings.override_contrast_level * 0.1) or 0      -- 1 (blended) to 0 (no blend)
        self.priv_ev100_min   = 4.0                                                                             -- set reasonably balanced for both 3D and VR

        if self.settings.override_contrast_range then
            self.priv_ev100_max = (self.settings.override_illumination and 14.75 or 15.0) - ((self.settings.override_contrast and self.priv_blend_ratio or 0.0) + 0.4) * 0.25    -- with 'tonemap/blend' from 1.0 to 0.0
        else
            self.priv_ev100_max = (self.settings.override_illumination and 14.75 or 15.0) - ((self.settings.override_contrast and self.priv_blend_ratio or 0.4) + 1.0) * 0.25    -- with 'tonemap/blend' from 0.5 to 0.0
        end

        self.priv_ev100_max = self.priv_ev100_max + 0.1
        self:set('photometric/ev100_min'   , self.priv_ev100_min)
        self:set('photometric/ev100_max'   , self.priv_ev100_max)

        self:apply(0       , self.settings.override_exposure)
        self:apply(category, self.settings.override_exposure)

    elseif category == 2  then 

        if self.settings.override_illumination then
            self:set('scattering/earth_albedo'    , 0.20  )
            self:set('cube_map/extra samples'     , 1.0   )
            self:set('cubemap/interior_proj_size' , 100.0 )
            self:set('cubemap/pmrem/rough_mip1'   , 0.625 )
            self:set('cubemap/pmrem/rough_mip2'   , 0.625 )
            self:set('cubemap/pmrem/rough_mip3'   , 0.3125)
            self:set('cubemap/pmrem/rough_mip4'   , 0.625 )
            self:set('cubemap/pmrem/rough_mip5'   , 0.625 )
            self:set('cubemap/z_offset'           , -100.0)
            self:set('autoexposure/trim_hi'       , 0.0   )
            self:set('autoexposure/trim_lo'       , 0.25  )
            --self:set('autoexposure/trim_hi'       , 0.1   )
            --self:set('autoexposure/trim_lo'       , 0.25  )
            self:set('skyc/min_shadow_angle'      ,-15.0  )
            self:set('skyc/max_shadow_angle'      ,  2.0  )
            self:set('ssao/interior_curve'        , 0.75  )
            self:set('ssao/interior_strength'     , 0.75  )
        else
            self:set('scattering/earth_albedo'    , 0.28  )
            self:set('cube_map/extra samples'     , 0.625 )
            self:set('cubemap/interior_proj_size' , 5.0   )
            self:set('cubemap/pmrem/rough_mip1'   , 0.3125)
            self:set('cubemap/pmrem/rough_mip2'   , 0.3125)
            self:set('cubemap/pmrem/rough_mip3'   , 0.625 )
            self:set('cubemap/pmrem/rough_mip4'   , 0.625 )
            self:set('cubemap/pmrem/rough_mip5'   , 0.3125)
            self:set('cubemap/z_offset'           , 0.5   )
            self:set('autoexposure/trim_hi'       , 0.1   )
            self:set('autoexposure/trim_lo'       , 0.1   )
            self:set('skyc/min_shadow_angle'      ,-15.0  )
            self:set('skyc/max_shadow_angle'      ,-14.0  )
            self:set('ssao/interior_curve'        , 2.25  )
            self:set('ssao/interior_strength'     , 0.75  )
        end
        
        self:apply(0, self.settings.override_exposure)
        self:apply(1, self.settings.override_exposure)
        self:apply(6, self.settings.override_exposure and self.settings.override_ssao and self.settings.override_ssao_cockpit)

    elseif category == 3  then
    
        local water_gloss

        if self.settings.override_water_style == 2 then
            -- v1.7 (23NOV2023): tighter spread with more close up details, suppresses most moire and noise
            self:set('water/cascade_0_scale'          , 2.0    )
            self:set('water/cascade_1_scale'          , 0.64   )
            self:set('water/cascade_2_scale'          , 0.64   )
            self:set('water/cascade_3_scale'          , 0.64   )
            self:set('water/h_displace_lambda'        , 1.75   )
            self:set('water/foam_bias'                , 0.73   )
            self:set('water/foam_scale'               , 1.5    )
            self:set('water/spectrum/fetch_hi_m'      , 10000.0)
            self:set('water/spectrum/fetch_lo_m'      , 5000.0 )
            self:set('water/spectrum/fetch_multiplier', 20.0   )
            water_gloss = 0.82
        elseif self.settings.override_water_style == 1 then
            -- v1.6 (01JUN2023): tighter spread, suppresses most moire and noise
            self:set('water/cascade_0_scale'          , 2.0    )
            self:set('water/cascade_1_scale'          , 0.5    )
            self:set('water/cascade_2_scale'          , 0.32   )
            self:set('water/cascade_3_scale'          , 0.32   )
            self:set('water/h_displace_lambda'        , 1.75   )
            self:set('water/foam_bias'                , 0.73   )
            self:set('water/foam_scale'               , 0.95   )
            self:set('water/spectrum/fetch_hi_m'      , 10000.0)
            self:set('water/spectrum/fetch_lo_m'      , 5000.0 )
            self:set('water/spectrum/fetch_multiplier', 20.0   )
            water_gloss = 0.82
        else
            -- v1.5 (31MAY2023): larger spread, suppresses nearly all moire and noise
            self:set('water/cascade_0_scale'          , 4.0    )
            self:set('water/cascade_1_scale'          , 0.5    )
            self:set('water/cascade_2_scale'          , 0.5    )
            self:set('water/cascade_3_scale'          , 0.5    )
            self:set('water/h_displace_lambda'        , 3.0    )
            self:set('water/foam_bias'                , 0.44   )
            self:set('water/foam_scale'               , 0.9    )
            self:set('water/spectrum/fetch_hi_m'      , 10000.0)
            self:set('water/spectrum/fetch_lo_m'      , 1000.0 )
            self:set('water/spectrum/fetch_multiplier', 15.0   )
            water_gloss = 0.65
        end

        -- self:set('water/F0'                , self.settings.override_turbidity and 0.04 or 0.02)
        -- self:set('water/gloss'             , self.settings.override_turbidity and 0.85 or water_gloss)
        -- self:set('water/wake_amp_ratio'    , self.settings.override_turbidity and 0.5  or 1.0)
        -- self:set('water/enable_refraction' , self.settings.override_turbidity and 1.0  or 0.0)
        -- self:set('water/enable_turbidity'  , not self.settings.override_turbidity and 1.0 or 0.0)
        self:set('water/enable_turbidity'  , 1.0)

        self:apply(category, self.settings.override_water)

    elseif category == 4  then
    
        self:set('lights/photobb/attenuation3'  , self.settings.override_lights_sheet == 0 and  0.00001 or  0.0000005)  -- alt1: 0.000005 alt2: 0.0000002 alt3: 0.0000001
        self:set('lights/photobb/exp_lim3'      , self.settings.override_lights_sheet == 0 and  5       or  6        )  -- alt1: 2        alt2: 4         alt3: 8
        self:set('lights/photobb/size3'         , self.settings.override_lights_sheet == 0 and 35       or 60        )  -- alt1: 50       alt2: 50        alt3: 80
        self:set('lights/photobb/cellx3'        , self.settings.override_lights_sheet == 0 and 14       or  8        )
        self:set('lights/photobb/celly3'        , self.settings.override_lights_sheet == 0 and  2       or  0        )
        self:set('lights/photobb/mult3'         , self.settings.override_lights_sheet == 0 and  2       or  4        )
        
        self:apply(category, self.settings.override_exposure and self.settings.override_lights)
        
    elseif category == 7  then
        
        if self.priv_override_clouds_noise_mode == 1 then
            self:set('new_clouds/high_freq_amp', 0.35)
            self:set('new_clouds/high_freq_rat', 9.5 )
            self:set('new_clouds/low_freq_rat' , 4.5 )
        else
            self:clr('new_clouds/high_freq_amp')
            self:clr('new_clouds/high_freq_rat')
            self:clr('new_clouds/low_freq_rat' )
        end

        if self.priv_override_clouds_march_mode == 1 then
            self:set('new_clouds/march/seg_count'     , 5.0   )
            self:set('new_clouds/march/seg_mul'       , 1.25  )
            self:set('new_clouds/march/seg_steps'     , 50.0  )
            self:set('new_clouds/march/step_len_start', 100.0 )
        else
            self:set('new_clouds/march/seg_count'     , 16.0  )
            self:set('new_clouds/march/seg_mul'       , 1.35  )
            self:set('new_clouds/march/seg_steps'     , 75.0  )
            self:set('new_clouds/march/step_len_start', 50.0  )
        end
        self:apply(category, self.settings.override_clouds)

    elseif category == 13 then
        
        if self.settings.override_shadows then
            self:set('shadow/csm/far_limit_exterior', self:get('shadow/csm/far_limit_exterior') * 2.0);
            self:set('shadow/csm/far_limit_interior', self:get('shadow/csm/far_limit_interior') * 2.0);
        end
        
        self:apply(category, self.settings.override_exposure and self.settings.override_shadows)

    elseif category == 5  then self:apply(category, self.settings.override_exposure and self.settings.override_ssao)
    elseif category == 6  then self:apply(category, self.settings.override_exposure and self.settings.override_ssao and self.settings.override_ssao_cockpit)
    elseif category == 8  then self:apply(category, self.settings.override_rain)
    elseif category == 9  then self:apply(category, self.settings.override_rain and self.settings.override_rain_lines)
    elseif category == 10 then self:apply(category, self.settings.override_bloom_effect)
    elseif category == 11 then self:apply(category, self.settings.override_auto_ibl ~= (bit.band(self.priv_tickle_cubemaps, 1) ~= 0))
    elseif category == 12 then self:apply(category, self.settings.override_fog_light)
    end 
end

function rxp_xp12_enhancer:update_group(...)
    for _, e in ipairs({...}) do self:update(e) end
end

function rxp_xp12_enhancer:init(data)
    -- if (XPLANE_VERSION < 12070) then end

    self.priv_tickle_cubemaps = 0

    -- apply custom settings if any

    if data ~= nil then
        for key, val in pairs(data.settings) do
            if key ~= nil and val ~= nil and self.settings[key] ~= nil then
                self.settings[key] = val
            end
        end
    end

    -- memoize datarefs and update overrides

    for k, v in pairs(self.lut) do 
        if XPLMFindDataRef("sim/private/controls/" .. k) ~= nil then
            if not v[2] and v[3] ~= 0 then
                v[2] = get("sim/private/controls/" .. k)
                -- logMsg("RXP XP12E: " .. "sim/private/controls/" .. k .. " = " .. v[2])
            end
        else v[1] = nil;  print("rxp_xp12_enhancer_lut: dataref not found " .. k) end
    end
    for i = 0, 20 do self:update(i) end
    -- self:apply(100, RXP_XP12E_DEBUG_DISABLE_ALL == 0)   -- uncomment to show debug histogram
end

function rxp_xp12_enhancer_ini_decode(str, name)
    local data = {}
    local section
    local pos = 0
    for st, sp in function() return string.find(str, "\n", pos, true) end do
        local line = string.sub(str, pos, st - 1); pos = sp + 1
        if #line > 0 and not line:match("^[%;#]") then      -- skip comments
            if string.sub(line, 1, 1) == "[" then
                section = string.sub(line, 2, string.find(line, "]") - 1)
                if (section == name) then data[section] = {} else section = nil end
            elseif section then
                local key, val = string.match(line, "^([%w|_]+)%s-=%s-(.+)$")
                if key and val then
                    val = val:gsub("^%s*(.-)%s*$", "%1")    -- trim ws
                    if tonumber(val) then val = tonumber(val) elseif val == "true" then val = true elseif val == "false" then val = false else val = nil end
                    if val ~= nil then data[section][key] = val end
                end
            end
        end
    end
    return data
end

function rxp_xp12_enhancer_ini_encode(data, name)
    local function spairs(t) -- sorted pairs
        local keys = {}; for k in pairs(t) do keys[#keys+1] = k end table.sort(keys) 
        local i = 0; return function() i = i + 1; if keys[i] then return keys[i], t[keys[i]] end end
    end

    local str = ""
    for section, content in pairs(data) do
        if (section == name) then
            str = str .. ("[%s]\n"):format(section)
            for key, value in spairs(content) do
                str = str .. ("%s = %s\n"):format(key, tostring(value))
            end
            str = str .. "\n"
        end
    end
    return str
end

function rxp_xp12_enhancer_load_settings()
    local path = SCRIPT_DIRECTORY .. "rxp-xp12-enhancer.ini"
    local file = io.open(path, "r")
    if file then local data = rxp_xp12_enhancer_ini_decode(file:read("*a"), "settings"); file:close(); return data end
end

function rxp_xp12_enhancer_save_settings() 
    local path = SCRIPT_DIRECTORY .. "rxp-xp12-enhancer.ini"
    local file = io.open(path, "w+b")
    if file then file:write(rxp_xp12_enhancer_ini_encode(rxp_xp12_enhancer, "settings")); file:close() 
    else logMsg("RXP XP12E: Error saving file '" .. path .. "'") end
end


--[[ Main Init and Update ]]--

local xvar_sce_sunglasses_on          = dataref_table("sim/cockpit/electrical/sunglasses_on"             )
local xvar_sce_night_vision_on        = dataref_table("sim/cockpit/electrical/night_vision_on"           )
local xvar_spc_photometric_ev100      = dataref_table("sim/private/controls/photometric/ev100"           )
local xvar_spc_photometric_ev100_mtr  = dataref_table("sim/private/controls/photometric/ev100_mtr"       )
local xvar_spc_photometric_ev100_mid  = dataref_table("sim/private/controls/photometric/ev100_mid"       ) 
local xvar_spc_photometric_ev100_min  = dataref_table("sim/private/controls/photometric/ev100_min"       )
local xvar_spc_photometric_ev100_bias = dataref_table("sim/private/controls/photometric/ev100_bias"      )
local xvar_spc_tonemap_blend          = dataref_table("sim/private/controls/tonemap/blend"               )
local xvar_spc_tonemap_grayscale      = dataref_table("sim/private/controls/tonemap/grayscale"           )

local xvar_sgv_view_is_external       = dataref_table("sim/graphics/view/view_is_external"               )
local xvar_spc_ssao_radius            = dataref_table("sim/private/controls/ssao/radius"                 )
local xvar_spc_ssao_exterior_curve    = dataref_table("sim/private/controls/ssao/exterior_curve"         )
local xvar_spc_ssao_visibility        = dataref_table("sim/private/controls/ssao/visibility"             )

local xvar_spc_cars_lod_min           = dataref_table("sim/private/controls/cars/lod_min"                )
local xvar_sgs_moon_illumination      = dataref_table("sim/graphics/scenery/moon_illumination"           )
local xvar_spc_moon_nits              = dataref_table("sim/private/controls/moon/nits"                   )
local xvar_spc_stars_gain_photometric = dataref_table("sim/private/controls/stars/gain_photometric"      )
local xvar_spc_photobb_hack_value_hi  = dataref_table("sim/private/controls/lights/photobb/hack_value_hi")

local xvar_sgs_moon_heading_degrees   = dataref_table("sim/graphics/scenery/moon_heading_degrees"        )
local xvar_sgs_moon_pitch_degrees     = dataref_table("sim/graphics/scenery/moon_pitch_degrees"          )
local xvar_sgs_sun_heading_degrees    = dataref_table("sim/graphics/scenery/sun_heading_degrees"         )
local xvar_sgs_sun_pitch_degrees      = dataref_table("sim/graphics/scenery/sun_pitch_degrees"           )
local xvar_spc_lighting_E_sun_lx      = dataref_table("sim/private/controls/lighting/E_sun_lx"           )

local xvar_spc_shadow_level_clean     = dataref_table("sim/private/controls/skyc/shadow_level_clean"     )
local xvar_spc_shadow_level_foggy     = dataref_table("sim/private/controls/skyc/shadow_level_foggy"     )
local xvar_spc_shadow_level_hazy      = dataref_table("sim/private/controls/skyc/shadow_level_hazy"      )
local xvar_spc_shadow_level_hialt     = dataref_table("sim/private/controls/skyc/shadow_level_hialt"     )
local xvar_spc_shadow_level_mount     = dataref_table("sim/private/controls/skyc/shadow_level_mount"     )
local xvar_spc_shadow_level_ocast     = dataref_table("sim/private/controls/skyc/shadow_level_ocast"     )
local xvar_spc_shadow_level_orbit     = dataref_table("sim/private/controls/skyc/shadow_level_orbit"     )
local xvar_spc_shadow_level_snowy     = dataref_table("sim/private/controls/skyc/shadow_level_snowy"     )
local xvar_spc_shadow_level_sockd     = dataref_table("sim/private/controls/skyc/shadow_level_sockd"     )
local xvar_spc_shadow_level_strat     = dataref_table("sim/private/controls/skyc/shadow_level_strat"     )
local xvar_spc_shadow_offset_clean    = dataref_table("sim/private/controls/skyc/shadow_offset_clean"    )
local xvar_spc_shadow_offset_foggy    = dataref_table("sim/private/controls/skyc/shadow_offset_foggy"    )
local xvar_spc_shadow_offset_hazy     = dataref_table("sim/private/controls/skyc/shadow_offset_hazy"     )
local xvar_spc_shadow_offset_hialt    = dataref_table("sim/private/controls/skyc/shadow_offset_hialt"    )
local xvar_spc_shadow_offset_mount    = dataref_table("sim/private/controls/skyc/shadow_offset_mount"    )
local xvar_spc_shadow_offset_ocast    = dataref_table("sim/private/controls/skyc/shadow_offset_ocast"    )
local xvar_spc_shadow_offset_orbit    = dataref_table("sim/private/controls/skyc/shadow_offset_orbit"    )
local xvar_spc_shadow_offset_snowy    = dataref_table("sim/private/controls/skyc/shadow_offset_snowy"    )
local xvar_spc_shadow_offset_sockd    = dataref_table("sim/private/controls/skyc/shadow_offset_sockd"    )
local xvar_spc_shadow_offset_strat    = dataref_table("sim/private/controls/skyc/shadow_offset_strat"    )

local xvar_spc_fsr_enable             = dataref_table("sim/private/controls/fsr/enable"                  )
local xvar_spc_fsr_rcas_attenuation   = dataref_table("sim/private/controls/reno/rcas_rat"               )

local xvar_spc_debug_histo_bottom     = dataref_table("sim/private/controls/debug/histo_bottom"          )
local xvar_spc_debug_histo_top        = dataref_table("sim/private/controls/debug/histo_top"             )
local xvar_snm_network_time_sec       = dataref_table("sim/network/misc/network_time_sec"                )

function rxp_xp12_enhancer_update_shadow_level(shadow_level)
    xvar_spc_shadow_level_clean[0]     = shadow_level
    xvar_spc_shadow_level_foggy[0]     = shadow_level
    xvar_spc_shadow_level_hazy [0]     = shadow_level
    xvar_spc_shadow_level_hialt[0]     = shadow_level
    xvar_spc_shadow_level_mount[0]     = shadow_level
    xvar_spc_shadow_level_ocast[0]     = shadow_level
    xvar_spc_shadow_level_orbit[0]     = shadow_level
    xvar_spc_shadow_level_snowy[0]     = shadow_level
    xvar_spc_shadow_level_sockd[0]     = shadow_level
    xvar_spc_shadow_level_strat[0]     = shadow_level
end
function rxp_xp12_enhancer_update_shadow_offset(shadow_offset)
    xvar_spc_shadow_offset_clean[0]    = shadow_offset
    xvar_spc_shadow_offset_foggy[0]    = shadow_offset
    xvar_spc_shadow_offset_hazy [0]    = shadow_offset
    xvar_spc_shadow_offset_hialt[0]    = shadow_offset
    xvar_spc_shadow_offset_mount[0]    = shadow_offset
    xvar_spc_shadow_offset_ocast[0]    = shadow_offset
    xvar_spc_shadow_offset_orbit[0]    = shadow_offset
    xvar_spc_shadow_offset_snowy[0]    = shadow_offset
    xvar_spc_shadow_offset_sockd[0]    = shadow_offset
    xvar_spc_shadow_offset_strat[0]    = shadow_offset
end

function rxp_xp12_enhancer_do_init()
    local settings = rxp_xp12_enhancer_load_settings()
    rxp_xp12_enhancer:init(settings)    -- prepare all the datarefs
    priv_override_eclipse_emulation = priv_override_eclipse_emulation ~= 0 and xvar_spc_lighting_E_sun_lx[0] or 0.0  -- memoize actual X-Plane Sun Lx (should be 115000 with XP12.09)
    xvar_spc_fsr_rcas_attenuation[0] = math_clamp(1.0 - (rxp_xp12_enhancer.settings.override_sharpen_level * 0.01), 0.0, 1.0)
    rxp_xp12_enhancer.run_once = true
    logMsg("rxp_xp12_enhancer started")
end

function rxp_xp12_enhancer_do_deinit()
    rxp_xp12_enhancer:apply()           -- restore all the datarefs
    rxp_xp12_enhancer_save_settings()
    rxp_xp12_enhancer.run_once = false
    logMsg("rxp_xp12_enhancer stopped")
end

function rxp_xp12_enhancer_do_often()
    if rxp_xp12_enhancer.run_once then
        -- update the cubemaps for a few frames
        if rxp_xp12_enhancer.priv_tickle_cubemaps > 0 then
            rxp_xp12_enhancer.priv_tickle_cubemaps = rxp_xp12_enhancer.priv_tickle_cubemaps - 1
            rxp_xp12_enhancer:update(11)
        end
    else
        -- lazy init otherwise some datarefs aren't read properly. 
        rxp_xp12_enhancer_do_init()
        if rxp_xp12_enhancer.settings.auto_show_wnd then rxp_xp12_enhancer_wnd_show() end
    end
end

function rxp_xp12_enhancer_do_every_frame()
    if rxp_xp12_enhancer.run_once then
        local ev100_mid = xvar_spc_photometric_ev100_mid[0]
        --local tone_blend = math_lerp(math_ratio(ev100_mid, 10.0, 8.0600004), 0.2, 1.0)           -- same as XP12 LUT

        if not rxp_xp12_enhancer.settings.override_exposure then
            -- use the same ev100 bias and tonemap blend as XP12 but with a few changes:
            --   use ev100_mid which is equivalent to xp12 using sun elev internally.
            --   using ev100_mid also makes the bias independant of camera height.
            --   this allows both overriding and reverting to xp12 defaults.
            --   this also allows to implement the sun glasses and night vision overrides.
            xvar_spc_photometric_ev100_bias[0] = table_interpolate(rxp_xp12_enhancer.k_ev100_bias_lut, ev100_mid)
            --xvar_spc_tonemap_blend = tone_blend
            xvar_spc_tonemap_blend[0] = math_lerp(math_ratio(ev100_mid, 10.0, 8.0600004), 0.2, 1.0)           -- same as XP12 LUT
        
        else
            -- if rxp_xp12_enhancer.priv_override_mettering then
            --     -- xvar_spc_photometric_ev100 = math.min(xvar_spc_photometric_ev100_mtr, ev100_mid)
            --     -- xvar_spc_photometric_ev100 = ev100_mid
            --     
            --     local ev100_mtr = xvar_spc_photometric_ev100_mtr
            --     --xvar_spc_photometric_ev100 = math.min(ev100_mid, (ev100_mtr + ev100_mid) * 0.5)
            --     xvar_spc_photometric_ev100 = math.min(rxp_xp12_enhancer.priv_ev100_max, (ev100_mtr + ev100_mid) * 0.5) - 0.25
            -- 
            -- else
                -- clamp the mettering range around the sun reference.
                xvar_spc_debug_histo_bottom[0] = math.max(ev100_mid - 7, -3.0)                             -- -2.0 (v12.06)
                xvar_spc_debug_histo_top[0]    = math.min(ev100_mid + 2, rxp_xp12_enhancer.priv_ev100_max) -- 18.0 (v12.06)
            -- end

            -- sun glasses and night vision
            local night_vision_on = xvar_sce_night_vision_on[0]
            local ev100_mtr = xvar_spc_photometric_ev100_mtr[0]
            xvar_spc_tonemap_grayscale[0]      = night_vision_on ~= 0 and 1.0 or 0.0
            xvar_spc_photometric_ev100_min[0]  = night_vision_on ~= 0 and -2.0 or rxp_xp12_enhancer.priv_ev100_min
            xvar_spc_photometric_ev100_bias[0] = (1.0 * xvar_sce_sunglasses_on[0]) - ((15.0 - math.min(ev100_mtr, 5.0)) * night_vision_on)
            
            -- adjust blend (contrast or night vision), and bias (more vidid night lighting)
            local tone_blend = rxp_xp12_enhancer.settings.override_contrast_range and 1.0 or 0.5

            if night_vision_on ~= 0.0 then tone_blend = 1.25
            elseif rxp_xp12_enhancer.settings.override_contrast then tone_blend = tone_blend * rxp_xp12_enhancer.priv_blend_ratio
            else tone_blend = math_lerp(math_ratio(ev100_mid, 10.0, 8.0600004), 0.0, tone_blend) end       -- wider than XP12 LUT
            xvar_spc_tonemap_blend[0] = tone_blend

            -- correct shadows
            if not rxp_xp12_enhancer.settings.override_illumination then
                -- https://www.desmos.com/calculator/aypmdschcs
                -- mitigate lack of ambient lightin reducing shadows strength, but prevent light leaks when sun is low.
                local shadow_rat = math_ratio(xvar_sgs_sun_pitch_degrees[0], 5.0, 35.0)
                rxp_xp12_enhancer_update_shadow_level(1.0 + 0.04 * shadow_rat)
                rxp_xp12_enhancer_update_shadow_offset(-2.0 * shadow_rat)
            end

            -- correct the moon brightness with exposure and adjust visible stars magnitude brightness with a pseudo moon light polution
            if rxp_xp12_enhancer.settings.override_lights then
                local ev100 = xvar_spc_photometric_ev100[0]
                xvar_spc_moon_nits[0] = night_vision_on ~= 0 and 500.0 or math.min(math.pow(2.0, ev100 + tone_blend + 0.5), 20000.0)
                xvar_spc_stars_gain_photometric[0] = math_lerp(xvar_sgs_moon_illumination[0], 30.0, 5.0)
                xvar_spc_photobb_hack_value_hi[0] = math.pow(2.0, math.max(ev100_mid + 7.0, 0.0)) + 50000.0
                xvar_spc_cars_lod_min[0] = 12000.0 + (4000.0 * math_ratio(ev100_mid, 13.0, 10.0))    -- equivalent to sun elev +3 -> -2

            --elseif xvar_spc_cars_lod_min[0] ~= 15000.0 then
            --    xvar_spc_cars_lod_min[0] = 15000.0  -- default for XP12.09
            end

            -- correct SSAO
            if rxp_xp12_enhancer.settings.override_ssao then
                -- (1.7,23.0) with visibility 0, (5.5,23.0) with visibility 1, (2.5,23.0) with visibility 0.2105
                xvar_spc_ssao_visibility[0] = xvar_sgv_view_is_external[0] * 0.2105    -- this locks the shadow multiplier to a fixed value (1.8)!
                local ssao_radius_rat = math_ratio(xvar_spc_ssao_radius[0], 2.5, 23.0)
                xvar_spc_ssao_exterior_curve[0] = math_lerp(ssao_radius_rat, 1.2, 1.0)
            end

            -- tickle cube maps update when changing view
            if not rxp_xp12_enhancer.settings.override_auto_ibl then
                local view_is_external = xvar_sgv_view_is_external[0]
                if priv_view_is_external ~= view_is_external then
                    priv_view_is_external = view_is_external
                    rxp_xp12_enhancer:update(0)
                end
            end

            -- emulate solar eclipse (VFX only and not physically based)
            -- for exact simulation see: https://sci-hub.se/10.1088/0143-0807/27/6/004
            if priv_override_eclipse_emulation ~= 0 then
                local sun_lx = priv_override_eclipse_emulation
                local sun_pitch_degrees = xvar_sgs_sun_pitch_degrees[0]
                if sun_pitch_degrees > -5.0 then
                    local eclipse_v = math_hypot( smalest_angle_deg(sun_pitch_degrees, xvar_sgs_moon_pitch_degrees[0]), smalest_angle_deg(xvar_sgs_sun_heading_degrees[0], xvar_sgs_moon_heading_degrees[0]) )
                    sun_lx = math_lerp(math_ratio(eclipse_v, 0.0, 1.0), 200.0, sun_lx)
                end
                if xvar_spc_lighting_E_sun_lx[0] ~= sun_lx then xvar_spc_lighting_E_sun_lx[0] = sun_lx end
            end
        
        end

    end
end

function rxp_xp12_enhancer_do_every_draw()
    if rxp_xp12_enhancer.run_once then
        if ( (xvar_snm_network_time_sec[0] - rxp_xp12_enhancer.priv_start_time) < 5 ) then
            local string_w = measure_string(RXP_XP12E_WINDOW_TITLE .. " " .. RXP_XP12E_VERSION_NMBR .. ": DISABLED")
            draw_string( (SCREEN_WIDTH - string_w) / 2, SCREEN_HEIGHT - 100, RXP_XP12E_WINDOW_TITLE .. " " .. RXP_XP12E_VERSION_NMBR .. ": DISABLED", "green" )
        end
    else 
        rxp_xp12_enhancer.priv_start_time = xvar_snm_network_time_sec[0] + 5.0
        rxp_xp12_enhancer.run_once = true;
    end
end


--[[ Settings Window ]]--

function rxp_xp12_enhancer_wnd_on_draw(wnd, x, y)
    local changed
    local win_w = imgui.GetWindowWidth()
    local win_h = imgui.GetWindowHeight()
    
    local function imgui_TextUnformattedColor(t,c) imgui.PushStyleColor(imgui.constant.Col.Text, c); imgui.TextUnformatted(t); imgui.PopStyleColor() end
    local function imgui_TextUnformattedColorSize(t,c,s) imgui.SetWindowFontScale(s); imgui_TextUnformattedColor(t,c); imgui.SetWindowFontScale(1.0) end
    local function imgui_HeaderText(t,s) imgui_TextUnformattedColorSize(t, 0xffffaf5f, s) end

    local function imgui_CheckboxEx(t,v,c)
        if c then return imgui.Checkbox(t,v) end
        imgui.PushStyleColor(imgui.constant.Col.Text, 0xff7f7f7f)
        imgui.PushStyleColor(imgui.constant.Col.CheckMark, 0xff7f7f7f)
        imgui.Checkbox(t,v)
        imgui.PopStyleColor()
        imgui.PopStyleColor()
        return false, v
    end

    local function imgui_MakeHelpMarker(t)
        imgui.SameLine(); imgui_TextUnformattedColor("(?)", 0xff7f7f7f);
        if imgui.IsItemHovered() then imgui.BeginTooltip(); imgui.PushTextWrapPos(win_w - 10.0); imgui_TextUnformattedColor("Tip: " .. t, 0xff7f7f7f); imgui.PopTextWrapPos(); imgui.EndTooltip() end
    end
    
    -- Header
    imgui_HeaderText(RXP_XP12E_WINDOW_TITLE .. " " .. RXP_XP12E_VERSION_NMBR, 1.3)

    if XPLANE_VERSION <= RXP_XP12E_XPL_VERS_MAX then
        imgui_TextUnformattedColor("Tested with X-Plane " .. RXP_XP12E_XPL_VERS_MIN .. " | (c) reality-xp.com", 0xff7f7f7f)
        imgui.TextUnformatted(" ")
    else
	    imgui_TextUnformattedColor("ATTENTION: newer XP12 version detected", 0xff00ffff)
	    imgui_TextUnformattedColor("This script might not work as expected", 0xff00ffff)
    end

    if RXP_XP12E_DEBUG_DISABLE_ALL ~= 0 then
        imgui.TextUnformatted(" ")
        imgui_TextUnformattedColor("DISABLED", 0xff00ffff)
	    imgui.TextUnformatted(" ")
        imgui.TextUnformatted("1) Edit the script file and set:")
        imgui.TextUnformatted("    RXP_XP12E_DEBUG_DISABLE_ALL = 0")
	    imgui.TextUnformatted(" ")
        imgui.TextUnformatted("2) Reload the script")
        return
    end
    
    -- Exposure, Shadows, Lights
    imgui_HeaderText("Shadows & Lighting", 1.15)

    changed, rxp_xp12_enhancer.settings.override_exposure = imgui.Checkbox("Enhance Exposure, Shadows, Lightning", rxp_xp12_enhancer.settings.override_exposure)
    if changed then rxp_xp12_enhancer:update_group(2,0,1,4,5,6,13) end
    imgui_MakeHelpMarker("This is enhancing:\n\n- Dynamic range and global exposure\n- White balance and tone mapping\n- Eye adaptation when light intensity changes\n- Shadows rendering consistency (clear to overcast)\n- Clouds reflections on ocean and water\n- EFIS and cockpit integral lighting\n- Working Sun Glasses and Night Vision Goggles")

    changed, rxp_xp12_enhancer.settings.override_illumination = imgui_CheckboxEx("Enhance Global Illumination (GI)", rxp_xp12_enhancer.settings.override_illumination, rxp_xp12_enhancer.settings.override_exposure)
    if changed then rxp_xp12_enhancer:update_group(2,0,1,4,5,6,13) end
    imgui_MakeHelpMarker("This simulates Global Illumination (GI):\n\n- More realistic environment luminosity\n- More realistic environment reflections\n- Better cockpit ambient lighting\n- Better light scattering on scenery and objects\n- Better sky reflection on rain puddles\n\n'Ambient Light Auto-Update (IBL)' is recommended for best effect.\n\nNote: Cockpits can render a little bit blueish when flying in clear skies.")

    changed, rxp_xp12_enhancer.settings.override_shadows = imgui_CheckboxEx("Enhance Shadows (CSM)", rxp_xp12_enhancer.settings.override_shadows, rxp_xp12_enhancer.settings.override_exposure)
    if changed then rxp_xp12_enhancer:update(13) end
    imgui_MakeHelpMarker("This doubles the visible range of ground shadows (minor to no fps loss).\n\nNote: Requires XP12 Shadow Quality MAX for best results.")

    changed, rxp_xp12_enhancer.settings.override_ssao = imgui_CheckboxEx("Enhance Ambient Occlusion (SSAO)", rxp_xp12_enhancer.settings.override_ssao, rxp_xp12_enhancer.settings.override_exposure)
    if changed then rxp_xp12_enhancer:update_group(5,6) end
    -- imgui_MakeHelpMarker("Reduce flickering and rendering artifacts\n\nThis settings reduces most flickering artifacts\nwhile dynamically controlling the effect strength.\nAO is more realistic and consistent both on ground\nand up to higher altitudes")
    imgui_MakeHelpMarker("Reduce most of the ambiant occlusion rendering artifacts while making AO more realistic and consistent on scenery, both on the ground and when looking from higher altitudes")

    changed, rxp_xp12_enhancer.settings.override_ssao_cockpit = imgui_CheckboxEx("Enable Cockpit Ambient Occlusion", rxp_xp12_enhancer.settings.override_ssao_cockpit, rxp_xp12_enhancer.settings.override_ssao and rxp_xp12_enhancer.settings.override_exposure)
    if changed then rxp_xp12_enhancer:update(6) end
    imgui_MakeHelpMarker("This adds a realistic and subtle depth effect in the cockpit")

    changed, rxp_xp12_enhancer.settings.override_lights  = imgui_CheckboxEx("Enhance Night Lighting", rxp_xp12_enhancer.settings.override_lights, rxp_xp12_enhancer.settings.override_exposure)
    if changed then rxp_xp12_enhancer:update(4) end
    imgui_MakeHelpMarker("Realistic and natural night lighting:\n\n- Changes the default light bulb sprites(*)\n- More realistic visuals from near to far\n- Balanced ground lights intensity (dusk/dawn/night)\n- Adjusted lightning strikes intensity\n- Extends cars visibility and distance\n- More realistic moon brightness (day & night)\n- Stars magnitude varying with moon light polution\n\n(*)although there is no need to change it anymore, with recommend to use the '1000_lights_close.png' inclued with this mod.")

    if rxp_xp12_enhancer.settings.override_exposure then
        changed, rxp_xp12_enhancer.settings.override_contrast = imgui.Checkbox(rxp_xp12_enhancer.settings.override_contrast and "##cb_contrast" or "Adjust Contrast", rxp_xp12_enhancer.settings.override_contrast)
        if changed then rxp_xp12_enhancer:update(1); end
    
        if rxp_xp12_enhancer.settings.override_contrast then
            imgui.SameLine()
            changed, rxp_xp12_enhancer.settings.override_contrast_level = imgui.SliderInt("##si_contrast_level", rxp_xp12_enhancer.settings.override_contrast_level, 0, 10, "Contrast: %d")
            if changed then rxp_xp12_enhancer:update(1); end
        end
    else
        imgui_CheckboxEx("Adjust Contrast", rxp_xp12_enhancer.settings.override_contrast, false)
    end
    imgui_MakeHelpMarker("Prefer Lower Contrast with airliner cockpits")


    -- Clouds, Rain
    imgui_HeaderText("Clouds & Rain", 1.15)

    changed, rxp_xp12_enhancer.settings.override_clouds  = imgui.Checkbox("Enhance Clouds", rxp_xp12_enhancer.settings.override_clouds)
    if changed then rxp_xp12_enhancer:update(7) end
    imgui_MakeHelpMarker("Enhance details, lighting and smoother ground shadows")

    changed, rxp_xp12_enhancer.settings.override_rain = imgui.Checkbox("Enhance Rain drops and streaks (3D)", rxp_xp12_enhancer.settings.override_rain)
    if changed then rxp_xp12_enhancer:update(8) end
    imgui_MakeHelpMarker("More realistic rendering of rain drops on the windshield, varying in size depending on the relative wind")

    changed, rxp_xp12_enhancer.settings.override_rain_lines = imgui_CheckboxEx("Disable legacy rain black lines", rxp_xp12_enhancer.settings.override_rain_lines, rxp_xp12_enhancer.settings.override_rain)
    if changed then rxp_xp12_enhancer:update(9) end
    imgui_MakeHelpMarker("Disable the legacy black rain lines aka 'star wars rain'")


    -- Water, Rivers, Lakes
    imgui_HeaderText("Oceans & Water", 1.15)

    changed, rxp_xp12_enhancer.settings.override_water  = imgui.Checkbox("Enhance Oceans, Lakes and Rivers", rxp_xp12_enhancer.settings.override_water)
    if changed then rxp_xp12_enhancer:update(3) end
    imgui_MakeHelpMarker("More realistic waves, both in look and amplitude, while reducing most of the default rendering artifacts (moire)")

    -- changed, rxp_xp12_enhancer.settings.override_turbidity = imgui_CheckboxEx("Disable Turbidity (use Reflection)", rxp_xp12_enhancer.settings.override_turbidity, rxp_xp12_enhancer.settings.override_water)
    -- if changed then rxp_xp12_enhancer:update(3) end
    -- imgui_MakeHelpMarker("Can help blending water with orthos/meshes shores")

        -- changed, rxp_xp12_enhancer.settings.override_water = imgui.Checkbox(rxp_xp12_enhancer.settings.override_water and "##cb_water" or "Enhance Oceans, Lakes and Rivers", rxp_xp12_enhancer.settings.override_water)
        -- if changed then rxp_xp12_enhancer:update(3) end
        -- if rxp_xp12_enhancer.settings.override_water then
        --     imgui.SameLine(); if imgui.RadioButton("Water Style 1", rxp_xp12_enhancer.settings.override_water_style == 0) then rxp_xp12_enhancer.settings.override_water_style = 0; rxp_xp12_enhancer:update(3) end
        --     imgui.SameLine(); if imgui.RadioButton("Water Style 2", rxp_xp12_enhancer.settings.override_water_style == 1) then rxp_xp12_enhancer.settings.override_water_style = 1; rxp_xp12_enhancer:update(3) end
        -- end

    -- Cosmetic
    imgui_HeaderText("Cosmetic & Misc.", 1.15)

    changed, rxp_xp12_enhancer.settings.override_bloom_effect = imgui.Checkbox("Disable bloom artifacts", rxp_xp12_enhancer.settings.override_bloom_effect)
    if changed then rxp_xp12_enhancer:update(10) end
    imgui_MakeHelpMarker("This disables the Bloom filter post-process in order to eliminate smearing and to reduce speckles")

    changed, rxp_xp12_enhancer.settings.override_auto_ibl = imgui.Checkbox("Enable Ambient Light Auto-Update (IBL)", rxp_xp12_enhancer.settings.override_auto_ibl)
    if changed then rxp_xp12_enhancer:update_group(0,11) end
    imgui_MakeHelpMarker("Update the cube map reflections and ambient lighting as the camera is moving. Can be used with a fast GPU (RTX 40xx) otherwise it can reduce fps (medium impact).\n\nPS: when disabled, the script is at least automatically updating the cube map once, when changing camera view between inside and outside, but it doesn't when the camera is only moving or rotating around.")

    changed, rxp_xp12_enhancer.settings.override_fog_light = imgui.Checkbox("Enable Volumetric Light (Experimental)", rxp_xp12_enhancer.settings.override_fog_light)
    if changed then rxp_xp12_enhancer:update(12) end
    imgui_MakeHelpMarker("Render volumetric cones of lights in foggy and low clouds conditions. Good for screenshots otherwise it can reduce fps (high impact)")

    -- Misc
    if xvar_spc_fsr_enable[0] ~= 0 then
        changed, rxp_xp12_enhancer.settings.override_sharpen_level = imgui.SliderInt("##si_fsr_sharpen", math_clamp( rxp_xp12_enhancer.settings.override_sharpen_level, 0, 100), 0, 100, "FSR Sharpen: %.0f")
        if changed then xvar_spc_fsr_rcas_attenuation[0] = math_clamp(1.0 - (rxp_xp12_enhancer.settings.override_sharpen_level * 0.01), 0.0, 1.0) end
    end
    
    changed, rxp_xp12_enhancer.settings.auto_show_wnd = imgui.Checkbox("Auto Settings Window Popup", rxp_xp12_enhancer.settings.auto_show_wnd)
    imgui_MakeHelpMarker("Display the settings window automatically when the script loads")
    
end

function rxp_xp12_enhancer_wnd_on_close()
    if not rxp_xp12_enhancer.wnd then return end
    float_wnd_destroy(rxp_xp12_enhancer.wnd)
    rxp_xp12_enhancer.wnd = nil
    if RXP_XP12E_DEBUG_DISABLE_ALL == 0 then
        rxp_xp12_enhancer_save_settings()
    end
end

function rxp_xp12_enhancer_wnd_show()
    if RXP_XP12E_DEBUG_DISABLE_ALL == 0 then
        if rxp_xp12_enhancer.wnd then return end
        rxp_xp12_enhancer.wnd = float_wnd_create(400, 530, 1, true)
        float_wnd_set_title(rxp_xp12_enhancer.wnd, RXP_XP12E_WINDOW_TITLE)
        float_wnd_set_imgui_builder(rxp_xp12_enhancer.wnd, "rxp_xp12_enhancer_wnd_on_draw")
        float_wnd_set_onclose(rxp_xp12_enhancer.wnd, "rxp_xp12_enhancer_wnd_on_close")
    else
        rxp_xp12_enhancer.priv_start_time = xvar_snm_network_time_sec[0]
    end
end

function rxp_xp12_enhancer_wnd_toggle()
    if rxp_xp12_enhancer.run_once then
        if rxp_xp12_enhancer.wnd then rxp_xp12_enhancer_wnd_on_close() else rxp_xp12_enhancer_wnd_show() end
    end
end

if RXP_XP12E_DEBUG_DISABLE_ALL == 0 then
    do_on_exit("rxp_xp12_enhancer_do_deinit()")
    do_often("rxp_xp12_enhancer_do_often()")
    do_every_frame("rxp_xp12_enhancer_do_every_frame()")
else
    do_every_draw("rxp_xp12_enhancer_do_every_draw()")
end

add_macro(RXP_XP12E_WINDOW_TITLE .. "...", "rxp_xp12_enhancer_wnd_show()")
create_command("RXP/Utility/Enhancer/toggle_window", "RXP Enhancer Window Toggle", "rxp_xp12_enhancer_wnd_toggle()", "", "")


--[[ Revisions

23MAY2023 (v1.0.0): - Initial release.
25MAY2023 (v1.1.0): - Added: Shadows and Global Illumination.
                    - Added: adjustable contrast value.
27MAY2023 (v1.2.0): - Added: Water, Lakes and Rivers.
29MAY2023 (v1.3.0): - Updated: Water, Lakes and Rivers.
30MAY2023 (v1.3.1): - Fixed: script.
02JUN2023 (v1.4.0): - Updated: Auto Cube map reflections are disabled by default for better fps when trying the mod the first time.
                    - Updated: Water, Lakes and Rivers.
06JUN2023 (v1.5.0): - Added: Working sun glasses (use XP12 sun glasses mode SHIFT+S).
                    - Added: Working night vision goggles (use XP12 night vision mode SHIFT+N).
                    - Enhanced: Moon exposure now varying correctly with scene exposure.
                    - Enhanced: Visible stars magnitude with light pollution.
                    - Enhanced: Tone mapper is now using the same dynamic range as XP12 by default.
                    - Enhanced: Atmosphere and white balance.
                    - Enhanced: Dusk/Dawn exposure.
31JUL2023 (v1.5.1): - Final version for XP12 v12.05 (see: rxp-xp12-enhancer(XP12.05).lua)

17SEP2023 (v1.6.0): - New: Officially released for XP12 v12.06.
                    - New: Override Ambient Occlusion in the cockpit.
                    - New: Override Ambient Occlusion is dynamically adjusting and fighting the XP12 SSAO artifacts.
                    - New: Override Clouds with refined ray marching preserving details farther away with no fps cost.
                    - New: Override Clouds with smoother and realistic ground shadows.
                    - Enhanced: Override 3D Rain is dynamically adjusting with aircraft speed for more realistic drops and streaks.
                    - Enhanced: Override Water wave patterns are looking better, with less moire/rendering artifacts.
                    - Enhanced: Override Water Turbidity helps blending the water surface with some orthos/meshes.
                    - Enhanced: Override Exposure makes smoother looking reflections.
                    - Enhanced: Override Exposure is now mostly revertible.
                    - Enhanced: Override Lighting now controls full moon illumination on the ground and the clouds.
                    - Updated: All settings have been refined and adjusted finely for better visual results.
18SEP2023 (v1.6.1): - Enhanced: Additional night light tweaks.
                    - Enhanced: The full moon is more visible at dusk/dawn.
                    - Enhanced: Bypasses XP12.06 external light artificial 'dimming'.
                    - Enhanced: Exposure slightly darker for a better VR experience in the cockpit.
                    - Enhanced: Exposure minimum exposure at night adjusted for a better VR experience.
                    - Enhanced: Ambient lighting optimized for slightly less fps impact and better cloud reflections on water.
                    - Enhanced: Water waves adjustments.

21SEP2023 (v1.7.0): - New: Compatible with XP12.07
                    - Enhanced: Future proofing the detection and warning message for subsequent XP12 versions.
03OCT2023 (v1.7.1): - Enhanced: Exposure and Global Illumination adjustments.
                    - Enhanced: Night Lighting calibration and performance.
                    - Enhanced: Beautify the GUI.
04OCT2023 (v1.7.2): - Fixed: Lower performance introduced with 1.7.1 (missing code).
05NOV2023 (v1.7.3): - New: Override Global Illumination option to enhance both interior cockpit luminosity and overall color balance.
                    - Enhanced: Better performance when using Ambient Light Auto-Update with enabling Global Illumination.
                    - New: Default script setting 'override_contrast_range' to widen the possible contrast range to [0 to 1] (earlier versions was [0 to 0.5]).
                    - Enhanced: Contrast Override now uses up to full contrast (tonemap blend 0.0) instead of XP12 default (0.2).

07DEC2023 (v1.8.0): - New: Compatible with XP12.08
                    - New: Added a new default Water/Ocean style (see: override_water_style)
                    - New: Night Vision with automatic gain control (AGC) to dynamically and automatically adjust the intensity. 
                    - New: Cube maps are automatically refreshing at least once when changing views and/or any of these settings: exposure, global illumination and ambient light auto-update.
                    - Enhanced: nerf the moon intensity in day light for more realisitic rendering at higher atmosphere altitudes and in space.

14JAN2024 (v1.9.0): - New: Compatible with XP12.09
                    - New: Extend Cascaded Shadow Maps range with minimal fps loss, works best with XP12 Shadows HIGH or ULTRA (see: override_shadows).
                    - Enhanced: 3D Rain drops and streaks on the windshield.
10FEB2024 (v1.9.1): - New: Added an option to configure the script whether using RXP or default 1000_lights_close.png (see: override_lights_sheet).
                    - New: Added a splash reminder when the script is disabled.
                    - Fixed: Compatibility when using other FWL scripts.
                    - Fixed: Some datarefs where not properly overriden nor restored causing too bright/blue cockpits sometimes.
22FEB2024 (v1.9.2): - New: The settings persist between sessions (saved to companion file rxp-xp12-enhancer.ini).
                    - New: Detailed information and explanations added to all of the settings tooltips.
                    - Enhanced: few override values changes and adjustments.
28FEB2024 (v1.9.3): - Fixed: The scripts fails to load when the companion file rxp-xp12-enhancer.ini is missing.
                    - Enhanced: Corrected white balance adjustment.
21MAR2024 (v1.9.4): - New: The FSR Sharpness and FXAA override settings are now persistent and saved in the .ini file.
                    - Enhanced: Adjusted Global Illumination setting slightly.
01APR2024 (v1.9.5): - New: Celebrate the solar eclipse and experience the reduced luminosity while flying (see priv_override_eclipse_emulation)
                           Start from KDFW or KSLK at 16h15z on April 8th and experience the effect!
02AUG2024 (v1.9.6) [ColinM9991]: - Fixed:   Changed RCAS dataref for what I presume is the new one. 
                                            Remove several datarefs which no longer exist.
                                            Remove FXAA on MSAA option as X-Plane natively supports this now. 

]]--
