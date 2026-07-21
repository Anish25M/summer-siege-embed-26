function results = ds_measure_performance(filtered, filters, cfg)
%DS_MEASURE_PERFORMANCE Measure coherent in-band SINAD and ENOB.

Fs = cfg.derived.sample_rate_Hz;
f_tone = cfg.signal.tone_Hz;
f_band = cfg.signal.bandwidth_Hz;
Fout_A = Fs/filters.A.decimation;
Fout_B = Fs/filters.B.total_decimation;
n_meas_A = cfg.simulation.measurement_output_samples;
n_meas_B = cfg.simulation.measurement_output_samples;

tone_cycles_A = n_meas_A*f_tone/Fout_A;
tone_cycles_B = n_meas_B*f_tone/Fout_B;
assert(abs(tone_cycles_A-round(tone_cycles_A)) < 1e-10, ...
    'Filter A measurement record is not coherent.');
assert(abs(tone_cycles_B-round(tone_cycles_B)) < 1e-10, ...
    'Filter B measurement record is not coherent.');

K = cfg.filter.cic_order;
M = cfg.filter.differential_delay;
R_A = filters.A.decimation;
R_B1 = filters.B.cic_decimation;
R_B = filters.B.total_decimation;
fir_order = filters.B.fir_order;
delay_A_output_samples = (numel(filters.A.impulse_response)-1)/(2*R_A);
delay_B_output_samples = ...
    (K*(R_B1*M-1)/2 + (fir_order/2)*R_B1)/R_B;

names = filtered.architecture_names;
measured_enob_A = zeros(1,numel(names));
measured_enob_B = zeros(1,numel(names));
sinad_A = zeros(1,numel(names));
sinad_B = zeros(1,numel(names));

for index = 1:numel(names)
    name = names{index};
    assert(numel(filtered.A.(name))-n_meas_A > ...
        ceil(delay_A_output_samples), ...
        'Not enough settled samples for Filter A.');
    assert(numel(filtered.B.(name))-n_meas_B > ...
        ceil(delay_B_output_samples), ...
        'Not enough settled samples for Filter B.');

    performance_A = ds_coherent_inband_performance( ...
        filtered.A.(name), n_meas_A, Fout_A, f_tone, f_band);
    performance_B = ds_coherent_inband_performance( ...
        filtered.B.(name), n_meas_B, Fout_B, f_tone, f_band);
    measured_enob_A(index) = performance_A.measured_enob;
    measured_enob_B(index) = performance_B.measured_enob;
    sinad_A(index) = performance_A.inband_sinad_dB;
    sinad_B(index) = performance_B.inband_sinad_dB;

    results.by_architecture.(name).filter_A.measured_enob = ...
        measured_enob_A(index);
    results.by_architecture.(name).filter_A.inband_sinad_dB = sinad_A(index);
    results.by_architecture.(name).filter_A.enob = measured_enob_A(index);
    results.by_architecture.(name).filter_A.snr_dB = sinad_A(index);

    results.by_architecture.(name).filter_B.measured_enob = ...
        measured_enob_B(index);
    results.by_architecture.(name).filter_B.inband_sinad_dB = sinad_B(index);
    results.by_architecture.(name).filter_B.enob = measured_enob_B(index);
    results.by_architecture.(name).filter_B.snr_dB = sinad_B(index);
end

results.architecture_names = names;
results.architecture_labels = filtered.architecture_labels;
results.nominal_resolution_bits = cfg.spec.nominal_resolution_bits;
results.output_word_length_bits = cfg.output.word_length_bits;
results.target_enob = cfg.spec.target_enob;
results.target_sinad_dB = cfg.derived.target_sinad_dB;
results.nyquist_rate_Hz = cfg.spec.nyquist_rate_Hz;
results.bandwidth_Hz = cfg.signal.bandwidth_Hz;
results.tone_Hz = cfg.signal.tone_Hz;
results.tone_bin = cfg.signal.tone_bin;
results.input_level_dBFS = cfg.signal.input_level_dBFS;
results.input_noise_enabled = cfg.analog.enable_input_noise;
results.input_noise_density_FS_per_sqrt_Hz = ...
    cfg.analog.input_noise_density_FS_per_sqrt_Hz;
results.OSR = cfg.derived.osr;
results.Fs = Fs;
results.third_order_single_loop_ntf_pole = ...
    cfg.modulator.third_order_ntf_pole;
results.Fout_A = Fout_A;
results.Fout_B = Fout_B;
results.CIC_decimation_B = filters.B.cic_decimation;
results.FIR_decimation_B = filters.B.fir_decimation;
results.total_decimation_B = filters.B.total_decimation;
results.FIR_order = filters.B.fir_order;
results.combined_atten_dB = filters.B.combined_attenuation_dB;
results.gain_at_tone_dB = filters.metrics.gain_at_tone_dB;
results.passband_droop_dB = filters.metrics.passband_droop_dB;
results.FIR_coefficients = filters.B.fir_float;
results.FIR_coefficient_bits = filters.B.coefficient_bits;
results.FIR_coefficient_fractional_bits = ...
    filters.B.coefficient_fractional_bits;
results.FIR_coefficients_integer = filters.B.coefficient_integers;
results.FIR_coefficients_hex = filters.B.coefficient_hex;
results.FIR_coefficients_verilog = filters.B.coefficient_verilog;
results.FIR_coefficient_table = filters.B.coefficient_table;
results.quantized_gain_at_tone_dB = ...
    filters.metrics.quantized_gain_at_tone_dB;
results.quantized_passband_droop_dB = ...
    filters.metrics.quantized_passband_droop_dB;
results.quantized_atten_at_Fstop_dB = ...
    filters.metrics.quantized_attenuation_at_Fstop_dB;
results.quantized_worst_stopband_atten_dB = ...
    filters.metrics.quantized_worst_stopband_attenuation_dB;
results.enob_A = measured_enob_A;
results.enob_B = measured_enob_B;
results.snr_A = sinad_A;
results.snr_B = sinad_B;
results.measurement_sample_count_A = n_meas_A;
results.measurement_sample_count_B = n_meas_B;
end
