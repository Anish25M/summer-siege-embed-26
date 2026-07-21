function [y, details] = ds_run_third_order_single_loop( ...
    x, dither, ntf_pole)
%DS_RUN_THIRD_ORDER_SINGLE_LOOP Simulate a third-order error-feedback loop.

N = numel(x);
ntf_denominator = [1 -3*ntf_pole ...
    3*ntf_pole^2 -ntf_pole^3];
ntf_numerator = [1 -3 3 -1];
error_feedback_numerator = ntf_numerator-ntf_denominator;

y = zeros(1,N);
quantization_error = zeros(1,N);
quantizer_input = zeros(1,N);
feedback_output = zeros(1,N);

for n = 1:N
    for delay = 1:3
        previous_index = n-delay;
        if previous_index >= 1
            feedback_output(n) = feedback_output(n) ...
                + error_feedback_numerator(delay+1) ...
                * quantization_error(previous_index) ...
                - ntf_denominator(delay+1) ...
                * feedback_output(previous_index);
        end
    end

    quantizer_input(n) = x(n)+feedback_output(n);
    y(n) = 2*double(quantizer_input(n)+dither(n) >= 0)-1;
    quantization_error(n) = y(n)-quantizer_input(n);
end

details.quantization_error = quantization_error;
details.quantizer_input = quantizer_input;
details.feedback_output = feedback_output;
details.ntf_numerator = ntf_numerator;
details.ntf_denominator = ntf_denominator;
details.ntf_pole = ntf_pole;
end
