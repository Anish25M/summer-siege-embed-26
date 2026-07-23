function manifest = export_rtl_test_vectors(output_directory, nyquist_rate_Hz)
%EXPORT_RTL_TEST_VECTORS Export only the files used by the RTL simulation.
%   MANIFEST = EXPORT_RTL_TEST_VECTORS() writes the digitally cancelled
%   MASH stimulus, FIR coefficients, and final golden output codes for the
%   selected 2 ksps design to ../rtl_vectors.

delta_sigma_adc_setup();

if nargin < 1 || isempty(output_directory)
    matlab_directory = fileparts(mfilename('fullpath'));
    output_directory = fullfile(matlab_directory, '..', 'rtl_vectors');
end
if nargin < 2
    nyquist_rate_Hz = 2000;
end

if ~isfolder(output_directory)
    mkdir(output_directory);
end

cfg = ds_default_config(nyquist_rate_Hz);
signal = ds_generate_signal(cfg);
modulators = ds_run_modulators(signal.vin, cfg);
filters = ds_design_filters(cfg);
integer_filter = ds_filter_and_decimate_integer( ...
    modulators.mash_2_1, filters, cfg);

combined = int64(modulators.mash_2_1);
combined_width = integer_filter.input_width;
cic_width = integer_filter.cic_width;
fir_width = integer_filter.fir_accumulator_width;
output_width = integer_filter.output_word_length;

write_twos_complement_hex(fullfile(output_directory, ...
    'mash_combined_twos_complement.mem'), combined, combined_width);
write_twos_complement_hex(fullfile(output_directory, ...
    'coeffs.hex'), ...
    filters.B.coefficient_integers, filters.B.coefficient_bits);
write_twos_complement_hex(fullfile(output_directory, ...
    'output_codes_20bit_twos_complement.mem'), ...
    integer_filter.output_codes, output_width);

manifest.modulator_clock_Hz = cfg.spec.modulator_clock_Hz;
manifest.nyquist_rate_Hz = nyquist_rate_Hz;
manifest.input_sample_count = numel(combined);
manifest.mash_stage_stream_width_bits = 1;
manifest.mash_combined_width_bits = combined_width;
manifest.mash_combined_minimum = double(min(combined));
manifest.mash_combined_maximum = double(max(combined));
manifest.mash_interstage_gain = cfg.modulator.mash_interstage_gain;
manifest.cic_order = cfg.filter.cic_order;
manifest.cic_decimation = filters.B.cic_decimation;
manifest.cic_width_bits = cic_width;
manifest.fir_order = filters.B.fir_order;
manifest.fir_tap_count = numel(filters.B.coefficient_integers);
manifest.fir_decimation = filters.B.fir_decimation;
manifest.coefficient_width_bits = filters.B.coefficient_bits;
manifest.coefficient_fractional_bits = ...
    filters.B.coefficient_fractional_bits;
manifest.fir_accumulator_width_bits = fir_width;
manifest.output_width_bits = output_width;
manifest.output_sample_count = numel(integer_filter.output_codes);
manifest.input_noise_seed = cfg.analog.input_noise_seed;
manifest.modulator_dither_seed = cfg.modulator.random_seed;
manifest.first_cic_output_input_index_one_based = 1;
manifest.first_fir_output_cic_index_one_based = 1;

fprintf('RTL test vectors written to %s\n', output_directory);
end

function write_twos_complement_hex(filename, values, width)
if width < 1 || width > 63
    error('Hex export supports signed widths from 1 through 63 bits.');
end
values = int64(values(:));
minimum = -bitshift(int64(1), width-1);
maximum = bitshift(int64(1), width-1)-1;
if any(values < minimum | values > maximum)
    error('A value does not fit in the requested signed %d-bit width.', width);
end

encoded = uint64(values);
negative = values < 0;
modulus = bitshift(uint64(1), width);
encoded(negative) = modulus-uint64(-values(negative));
hexadecimal = string(dec2hex(encoded, ceil(width/4)));
writelines(hexadecimal, filename, 'LineEnding', '\n');
end
