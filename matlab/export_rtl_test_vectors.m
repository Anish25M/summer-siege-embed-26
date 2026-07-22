function manifest = export_rtl_test_vectors(output_directory, nyquist_rate_Hz)
%EXPORT_RTL_TEST_VECTORS Export deterministic MASH and decimator RTL vectors.
%   MANIFEST = EXPORT_RTL_TEST_VECTORS() writes vectors for the selected
%   2 ksps design to ../rtl_vectors. Raw MASH quantizer streams are written
%   as logic bits, while the digitally cancelled MASH stream and golden
%   decimator outputs are written in signed decimal and two's-complement
%   hexadecimal forms.

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

stage1_bits = int64((modulators.mash_details.stage1_output+1)/2);
stage2_bits = int64((modulators.mash_details.stage2_output+1)/2);
combined = int64(modulators.mash_2_1);
combined_width = integer_filter.input_width;
cic_width = integer_filter.cic_width;
fir_width = integer_filter.fir_accumulator_width;
output_width = integer_filter.output_word_length;

write_decimal(fullfile(output_directory, 'mash_stage1_bits.mem'), stage1_bits);
write_decimal(fullfile(output_directory, 'mash_stage2_bits.mem'), stage2_bits);
write_decimal(fullfile(output_directory, ...
    'mash_combined_signed_decimal.txt'), combined);
write_twos_complement_hex(fullfile(output_directory, ...
    'mash_combined_twos_complement.mem'), combined, combined_width);
write_twos_complement_hex(fullfile(output_directory, ...
    'fir_coefficients_twos_complement.mem'), ...
    filters.B.coefficient_integers, filters.B.coefficient_bits);
write_decimal(fullfile(output_directory, ...
    'cic_output_signed_decimal.txt'), integer_filter.cic_output_integer);
write_twos_complement_hex(fullfile(output_directory, ...
    'cic_output_twos_complement.mem'), ...
    integer_filter.cic_output_integer, cic_width);
write_decimal(fullfile(output_directory, ...
    'fir_output_signed_decimal.txt'), integer_filter.fir_output_integer);
write_twos_complement_hex(fullfile(output_directory, ...
    'fir_output_twos_complement.mem'), ...
    integer_filter.fir_output_integer, fir_width);
write_decimal(fullfile(output_directory, ...
    'output_codes_20bit_signed_decimal.txt'), integer_filter.output_codes);
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

write_manifest(fullfile(output_directory, 'manifest.txt'), manifest);
fprintf('RTL test vectors written to %s\n', output_directory);
end

function write_decimal(filename, values)
file_id = fopen(filename, 'w');
if file_id < 0
    error('Could not open %s for writing.', filename);
end
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, '%d\n', values(:));
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

function write_manifest(filename, manifest)
file_id = fopen(filename, 'w');
if file_id < 0
    error('Could not open %s for writing.', filename);
end
cleanup = onCleanup(@() fclose(file_id));

fprintf(file_id, 'Delta-sigma ADC RTL test-vector manifest\n');
fprintf(file_id, 'All .mem files contain one sample per line.\n');
fprintf(file_id, ['Raw MASH stages use 0/1 logic mapping: ' ...
    'bipolar -1 -> 0, bipolar +1 -> 1.\n']);
fprintf(file_id, ['Hexadecimal files use fixed-width signed ' ...
    'two''s-complement values.\n\n']);

fields = fieldnames(manifest);
for index = 1:numel(fields)
    name = fields{index};
    value = manifest.(name);
    if ischar(value)
        fprintf(file_id, '%s=%s\n', name, value);
    else
        fprintf(file_id, '%s=%.15g\n', name, value);
    end
end

fprintf(file_id, '\nFiles:\n');
fprintf(file_id, 'mash_stage1_bits.mem: raw MASH stage-1 quantizer bits\n');
fprintf(file_id, 'mash_stage2_bits.mem: raw MASH stage-2 quantizer bits\n');
fprintf(file_id, ['mash_combined_*: digitally cancelled multilevel ' ...
    'stream presented to the CIC\n']);
fprintf(file_id, ['For zero-based n >= 2, combined[n] = stage1_bipolar[n] ' ...
    '- (stage2_bipolar[n] - 2*stage2_bipolar[n-1] + ' ...
    'stage2_bipolar[n-2])/mash_interstage_gain.\n']);
fprintf(file_id, ['The first two combined samples are zero, matching the ' ...
    'MATLAB model initialization.\n']);
fprintf(file_id, ['fir_coefficients_*: tap 0 first, signed %d-bit ' ...
    'Q1.%d\n'], manifest.coefficient_width_bits, ...
    manifest.coefficient_fractional_bits);
fprintf(file_id, 'cic_output_*: golden CIC output before the FIR\n');
fprintf(file_id, ['fir_output_*: golden decimated FIR accumulator ' ...
    'before normalization\n']);
fprintf(file_id, ['output_codes_20bit_*: golden rounded and saturated ' ...
    'ADC output codes\n']);
fprintf(file_id, '\nTiming:\n');
fprintf(file_id, ['The CIC accepts mash_combined sample 1 immediately ' ...
    'after reset and emits its first output for that sample.\n']);
fprintf(file_id, ['The FIR accepts CIC output 1 immediately after reset ' ...
    'and emits its first decimated output for that sample.\n']);
fprintf(file_id, ['Initial transient samples are intentionally retained ' ...
    'for cycle-accurate comparison.\n']);
end
