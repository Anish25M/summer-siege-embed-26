function cfg = ds_default_config(nyquist_rate_Hz)
%DS_DEFAULT_CONFIG Define one requirements-driven simulation point.

if nargin < 1
    nyquist_rate_Hz = 2000;
end

cfg.spec.nominal_resolution_bits = 20;
cfg.spec.minimum_target_enob = 16;
cfg.spec.maximum_target_enob = 19;
cfg.spec.target_enob = 19;
cfg.spec.modulator_clock_Hz = 256e3;
cfg.spec.minimum_nyquist_rate_Hz = 500;
cfg.spec.maximum_nyquist_rate_Hz = 2000;
cfg.spec.nyquist_rate_Hz = nyquist_rate_Hz;
cfg.spec.passband_ripple_dB = 0.5;
cfg.spec.minimum_stopband_attenuation_dB = 120;

cfg.signal.full_scale_peak = 1;
% MASH peaks here with 2 dB clearance from its measured -4 dBFS limit.
cfg.signal.input_level_dBFS = -6;
cfg.signal.amplitude = cfg.signal.full_scale_peak * ...
    10^(cfg.signal.input_level_dBFS/20);
cfg.signal.bandwidth_Hz = nyquist_rate_Hz/2;
cfg.signal.requested_tone_Hz = 125;

target_sinad_dB = 6.02*cfg.spec.maximum_target_enob + 1.76;
reference_bandwidth_Hz = cfg.spec.minimum_nyquist_rate_Hz/2;
full_scale_signal_power = cfg.signal.full_scale_peak^2/2;
reference_noise_power = full_scale_signal_power / ...
    10^(target_sinad_dB/10);
cfg.analog.enable_input_noise = true;
cfg.analog.input_noise_seed = 17;
cfg.analog.reference_bandwidth_Hz = reference_bandwidth_Hz;
cfg.analog.input_noise_density_FS_per_sqrt_Hz = ...
    sqrt(reference_noise_power/reference_bandwidth_Hz);

cfg.modulator.quantizer_step = 2;
cfg.modulator.dither_amplitude = 0.2;
cfg.modulator.random_seed = 1;
cfg.modulator.mash_interstage_gain = 0.25;
% This pole limits the single-loop third-order NTF peak to about 1.49.
cfg.modulator.third_order_ntf_pole = 0.75;

cfg.filter.cic_order = 4;
cfg.filter.differential_delay = 1;
cfg.filter.design_nyquist_rate_Hz = cfg.spec.maximum_nyquist_rate_Hz;
cfg.filter.design_bandwidth_Hz = cfg.filter.design_nyquist_rate_Hz/2;
cfg.filter.A.decimation = 64;
cfg.filter.B.cic_decimation = 16;
cfg.filter.B.fir_decimation = 4;
cfg.filter.B.initial_fir_order = 63;
cfg.filter.B.use_kaiser_estimated_order = false;
cfg.filter.B.maximum_design_iterations = 12;
cfg.filter.B.coefficient_bits = 24;

cfg.output.word_length_bits = cfg.spec.nominal_resolution_bits;

cfg.simulation.measurement_output_samples = 4096;
cfg.simulation.settling_output_samples = 1024;

cfg.derived.sample_rate_Hz = cfg.spec.modulator_clock_Hz;
cfg.derived.osr = cfg.spec.modulator_clock_Hz/nyquist_rate_Hz;
cfg.derived.target_sinad_dB = target_sinad_dB;

total_decimation_A = cfg.filter.A.decimation;
total_decimation_B = cfg.filter.B.cic_decimation * ...
    cfg.filter.B.fir_decimation;
if total_decimation_A ~= total_decimation_B
    error('Filter A and Filter B must currently have equal total decimation.');
end
cfg.derived.total_decimation = total_decimation_A;
cfg.derived.output_rate_Hz = ...
    cfg.spec.modulator_clock_Hz/total_decimation_A;

tone_bin = round(cfg.signal.requested_tone_Hz * ...
    cfg.simulation.measurement_output_samples/cfg.derived.output_rate_Hz);
tone_bin = max(tone_bin,1);
cfg.signal.tone_bin = tone_bin;
cfg.signal.tone_Hz = tone_bin*cfg.derived.output_rate_Hz / ...
    cfg.simulation.measurement_output_samples;

if cfg.signal.tone_Hz >= cfg.signal.bandwidth_Hz
    error('The fixed coherent test tone must remain inside the signal band.');
end
end
