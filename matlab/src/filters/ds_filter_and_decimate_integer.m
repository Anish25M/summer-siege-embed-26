function integer_filter = ds_filter_and_decimate_integer( ...
    modulator_output, filters, cfg)
%DS_FILTER_AND_DECIMATE_INTEGER Bit-true selected CIC16/FIR4 reference.

if any(modulator_output ~= round(modulator_output))
    error('The selected integer filter requires integer modulator samples.');
end

R1 = filters.B.cic_decimation;
R2 = filters.B.fir_decimation;
M = cfg.filter.differential_delay;
K = cfg.filter.cic_order;
maximum_input_magnitude = max(abs(modulator_output));
input_width = max(2,ceil(log2(maximum_input_magnitude+1))+1);
cic_growth = ceil(K*log2(R1*M));
cic_width = input_width+cic_growth;

integrator_state = zeros(1,K,'int64');
comb_delay = zeros(K,M,'int64');
cic_output_count = ceil(numel(modulator_output)/R1);
cic_output = zeros(1,cic_output_count,'int64');
output_index = 0;

for n = 1:numel(modulator_output)
    stage_value = int64(modulator_output(n));
    for stage = 1:K
        integrator_state(stage) = wrap_signed( ...
            integrator_state(stage)+stage_value, cic_width);
        stage_value = integrator_state(stage);
    end

    if mod(n-1,R1) == 0
        for stage = 1:K
            delayed_value = comb_delay(stage,end);
            if M > 1
                comb_delay(stage,2:end) = comb_delay(stage,1:end-1);
            end
            comb_delay(stage,1) = stage_value;
            stage_value = wrap_signed( ...
                stage_value-delayed_value, cic_width);
        end
        output_index = output_index+1;
        cic_output(output_index) = stage_value;
    end
end
cic_output = cic_output(1:output_index);

coefficients = int64(filters.B.coefficient_integers(:)');
coefficient_count = numel(coefficients);
fir_accumulator_width = cic_width + filters.B.coefficient_bits + ...
    ceil(log2(coefficient_count));
fir_delay = zeros(1,coefficient_count,'int64');
fir_output_count = ceil(numel(cic_output)/R2);
fir_output = zeros(1,fir_output_count,'int64');
output_index = 0;

for n = 1:numel(cic_output)
    fir_delay(2:end) = fir_delay(1:end-1);
    fir_delay(1) = cic_output(n);
    accumulator = int64(0);
    for tap = 1:coefficient_count
        accumulator = accumulator + fir_delay(tap)*coefficients(tap);
    end
    accumulator = wrap_signed(accumulator, fir_accumulator_width);

    if mod(n-1,R2) == 0
        output_index = output_index+1;
        fir_output(output_index) = accumulator;
    end
end
fir_output = fir_output(1:output_index);

normalization = double((R1*M)^K) * ...
    2^filters.B.coefficient_fractional_bits;
integer_filter.cic_output_integer = cic_output;
integer_filter.fir_output_integer = fir_output;
integer_filter.output_prequantized = double(fir_output)/normalization;
[integer_filter.output_normalized, integer_filter.output_codes] = ...
    ds_quantize_output(integer_filter.output_prequantized, ...
    cfg.output.word_length_bits);
integer_filter.output_word_length = cfg.output.word_length_bits;
integer_filter.input_width = input_width;
integer_filter.cic_width = cic_width;
integer_filter.cic_growth = cic_growth;
integer_filter.fir_accumulator_width = fir_accumulator_width;
integer_filter.normalization = normalization;
end


function wrapped = wrap_signed(value, width)
modulus = bitshift(int64(1),width);
half_modulus = bitshift(int64(1),width-1);
wrapped = mod(value,modulus);
if wrapped >= half_modulus
    wrapped = wrapped-modulus;
end
end
