function filters = ds_design_filters(cfg)
%DS_DESIGN_FILTERS Design the two existing decimation-filter candidates.

Fs = cfg.derived.sample_rate_Hz;
f_band = cfg.signal.bandwidth_Hz;
f_design_band = cfg.filter.design_bandwidth_Hz;
f_tone = cfg.signal.tone_Hz;
target_dB = cfg.spec.minimum_stopband_attenuation_dB;
K = cfg.filter.cic_order;
M = cfg.filter.differential_delay;

R_A = cfg.filter.A.decimation;
h_cic_A = cic_impulse_response(R_A, M, K);

R_B1 = cfg.filter.B.cic_decimation;
R_B2 = cfg.filter.B.fir_decimation;
R_B = R_B1*R_B2;
h_cic_B = cic_impulse_response(R_B1, M, K);

fir_input_rate = Fs/R_B1;
Fpass = f_design_band;
Fstop = fir_input_rate/R_B2 - f_design_band;
if Fstop <= Fpass
    error('No transition band: Fstop %.1f Hz is not above Fpass %.1f Hz.', ...
        Fstop, Fpass);
end

beta = kaiser_beta(target_dB);
Apass_dB = cfg.spec.passband_ripple_dB;
Rp = (10^(Apass_dB/20)-1)/(10^(Apass_dB/20)+1);
Rs = 10^(-target_dB/20);
[estimated_fir_order, Wn_fir, ~, ~] = kaiserord( ...
    [Fpass Fstop], [1 0], [Rp Rs], fir_input_rate);

if cfg.filter.B.use_kaiser_estimated_order
    fir_order = estimated_fir_order;
else
    fir_order = cfg.filter.B.initial_fir_order;
end
maximum_iterations = cfg.filter.B.maximum_design_iterations;
combined_attenuation_dB = -Inf;

for iteration = 1:maximum_iterations
    h_fir = fir1(fir_order, Wn_fir, kaiser(fir_order+1, beta));
    h_combined_test = conv(h_cic_B, upsample(h_fir, R_B1));
    [H_test, f_test] = freqz(h_combined_test, 1, 8192, Fs);
    stopband_index = find(f_test >= Fstop, 1);
    combined_attenuation_dB = ...
        -20*log10(abs(H_test(stopband_index))+1e-15);
    if combined_attenuation_dB >= target_dB
        break;
    end
    fir_order = round(fir_order*1.5);
end

if combined_attenuation_dB < target_dB
    warning('FIR search stopped at %.1f dB, below %.1f dB target.', ...
        combined_attenuation_dB, target_dB);
end

coefficient_bits = cfg.filter.B.coefficient_bits;
fractional_bits = coefficient_bits-1;
coefficient_scale = 2^fractional_bits;
coefficient_integers = round(h_fir*coefficient_scale);
coefficient_minimum = -2^(coefficient_bits-1);
coefficient_maximum = 2^(coefficient_bits-1)-1;

if any(coefficient_integers < coefficient_minimum | ...
       coefficient_integers > coefficient_maximum)
    error('The FIR coefficients overflow the selected Q1.%d format.', ...
        fractional_bits);
end

h_fir_quantized = coefficient_integers/coefficient_scale;
hex_width = ceil(coefficient_bits/4);
coefficient_hex = string(dec2hex( ...
    mod(coefficient_integers, 2^coefficient_bits), hex_width));
coefficient_verilog = string(coefficient_bits) + ...
    "'sh" + coefficient_hex;
integer_variable_name = sprintf('Q1_%d_Integer', fractional_bits);
hex_variable_name = sprintf('Hex%dBit', coefficient_bits);
coefficient_table = table( ...
    (0:numel(h_fir)-1)', h_fir(:), coefficient_integers(:), ...
    coefficient_hex(:), coefficient_verilog(:), ...
    'VariableNames', {'TapIndex', 'FloatCoefficient', ...
    integer_variable_name, hex_variable_name, 'VerilogLiteral'});

h_fir_input_rate = upsample(h_fir, R_B1);
h_fir_quantized_input_rate = upsample(h_fir_quantized, R_B1);
h_combined_B = conv(h_cic_B, h_fir_input_rate);
h_combined_B_quantized = conv(h_cic_B, h_fir_quantized_input_rate);

response_point_count = 65536;
[H_A, f_response] = freqz(h_cic_A, 1, response_point_count, Fs);
[H_B, ~] = freqz(h_combined_B, 1, response_point_count, Fs);
[H_B_quantized, ~] = freqz( ...
    h_combined_B_quantized, 1, response_point_count, Fs);
[H_CIC_B, ~] = freqz(h_cic_B, 1, response_point_count, Fs);
[H_FIR_B, ~] = freqz(h_fir_input_rate, 1, response_point_count, Fs);

H_A_dB = 20*log10(abs(H_A)+1e-15);
H_B_dB = 20*log10(abs(H_B)+1e-15);
H_B_quantized_dB = 20*log10(abs(H_B_quantized)+1e-15);
H_CIC_B_dB = 20*log10(abs(H_CIC_B)+1e-15);
H_FIR_B_dB = 20*log10(abs(H_FIR_B)+1e-15);

passband = f_response <= f_band;
gain_A_at_tone_dB = interp1(f_response, H_A_dB, f_tone, 'linear');
gain_B_at_tone_dB = interp1(f_response, H_B_dB, f_tone, 'linear');
gain_B_quantized_at_tone_dB = interp1( ...
    f_response, H_B_quantized_dB, f_tone, 'linear');
droop_A_dB = max(H_A_dB(passband))-min(H_A_dB(passband));
droop_B_dB = max(H_B_dB(passband))-min(H_B_dB(passband));
droop_B_quantized_dB = ...
    max(H_B_quantized_dB(passband))-min(H_B_quantized_dB(passband));
attenuation_B_quantized_at_Fstop_dB = -interp1( ...
    f_response, H_B_quantized_dB, Fstop, 'linear');
relevant_stopband = f_response >= Fstop & ...
    f_response <= fir_input_rate/2;
worst_stopband_attenuation_dB = ...
    -max(H_B_quantized_dB(relevant_stopband));

if worst_stopband_attenuation_dB < target_dB
    warning(['Quantized combined stopband reaches only %.1f dB; ' ...
        'the target is %.1f dB.'], ...
        worst_stopband_attenuation_dB, target_dB);
end

filters.A.decimation = R_A;
filters.A.impulse_response = h_cic_A;

filters.B.cic_decimation = R_B1;
filters.B.fir_decimation = R_B2;
filters.B.total_decimation = R_B;
filters.B.cic_impulse_response = h_cic_B;
filters.B.fir_order = fir_order;
filters.B.kaiser_estimated_fir_order = estimated_fir_order;
filters.B.fir_float = h_fir;
filters.B.fir_quantized = h_fir_quantized;
filters.B.coefficient_bits = coefficient_bits;
filters.B.coefficient_fractional_bits = fractional_bits;
filters.B.coefficient_integers = coefficient_integers;
filters.B.coefficient_hex = coefficient_hex;
filters.B.coefficient_verilog = coefficient_verilog;
filters.B.coefficient_table = coefficient_table;
filters.B.stopband_start_Hz = Fstop;
filters.B.combined_attenuation_dB = combined_attenuation_dB;

filters.response.frequency_Hz = f_response;
filters.response.A_dB = H_A_dB;
filters.response.B_dB = H_B_dB;
filters.response.B_quantized_dB = H_B_quantized_dB;
filters.response.B_cic_dB = H_CIC_B_dB;
filters.response.B_fir_dB = H_FIR_B_dB;

filters.metrics.gain_at_tone_dB = ...
    [gain_A_at_tone_dB gain_B_at_tone_dB];
filters.metrics.passband_droop_dB = [droop_A_dB droop_B_dB];
filters.metrics.quantized_gain_at_tone_dB = ...
    gain_B_quantized_at_tone_dB;
filters.metrics.quantized_passband_droop_dB = ...
    droop_B_quantized_dB;
filters.metrics.quantized_attenuation_at_Fstop_dB = ...
    attenuation_B_quantized_at_Fstop_dB;
filters.metrics.quantized_worst_stopband_attenuation_dB = ...
    worst_stopband_attenuation_dB;
end

function h = cic_impulse_response(decimation, differential_delay, order)
h = 1;
section_length = decimation*differential_delay;
for stage = 1:order
    h = conv(h, ones(1,section_length));
end
h = h/section_length^order;
end

function beta = kaiser_beta(attenuation_dB)
if attenuation_dB > 50
    beta = 0.1102*(attenuation_dB-8.7);
elseif attenuation_dB >= 21
    beta = 0.5842*(attenuation_dB-21)^0.4 + ...
        0.07886*(attenuation_dB-21);
else
    beta = 0;
end
end
