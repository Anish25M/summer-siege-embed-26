function [normalized_output, output_codes] = ...
    ds_quantize_output(input_signal, word_length)
%DS_QUANTIZE_OUTPUT Round and saturate to a signed fractional output word.

scale = 2^(word_length-1);
minimum_code = -scale;
maximum_code = scale-1;
rounded_codes = round(input_signal*scale);
rounded_codes = min(max(rounded_codes,minimum_code),maximum_code);
output_codes = int64(rounded_codes);
normalized_output = double(output_codes)/scale;
end
