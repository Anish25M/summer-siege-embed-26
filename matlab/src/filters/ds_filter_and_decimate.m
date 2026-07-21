function filtered = ds_filter_and_decimate(modulators, filters, cfg)
%DS_FILTER_AND_DECIMATE Apply both decimation candidates to every modulator.

names = modulators.architecture_names;

for index = 1:numel(names)
    name = names{index};
    modulator_output = modulators.(name);

    output_A = filter(filters.A.impulse_response, 1, modulator_output);
    output_A = output_A(1:filters.A.decimation:end);
    [filtered.A.(name), ~] = ds_quantize_output( ...
        output_A, cfg.output.word_length_bits);

    output_B1 = filter( ...
        filters.B.cic_impulse_response, 1, modulator_output);
    output_B1 = output_B1(1:filters.B.cic_decimation:end);
    output_B = filter(filters.B.fir_quantized, 1, output_B1);
    output_B = output_B(1:filters.B.fir_decimation:end);
    [filtered.B.(name), ~] = ds_quantize_output( ...
        output_B, cfg.output.word_length_bits);
end

filtered.architecture_names = names;
filtered.architecture_labels = modulators.architecture_labels;
end
