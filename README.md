# 20-Bit Delta-Sigma ADC MATLAB Model

This repository contains the MATLAB model and simulation study for a nominal 20-bit delta-sigma ADC. It covers the required modulator comparison, the 0.5-2 ksps Nyquist-rate versus ENOB study, and a bit-true MATLAB reference for the selected decimation filter.

HDL is intentionally not included. It can later be added as an independent `rtl/` module without mixing MATLAB and Verilog sources.

## Repository layout

```text
matlab/
  delta_sigma_adc.m                 Main simulation and study entry point
  delta_sigma_adc_setup.m           Adds all source subfolders to the path
  export_rtl_test_vectors.m         Generates Verilog stimulus and golden files
  src/
    core/
      ds_default_config.m           Central specifications and design settings
      ds_generate_signal.m          Coherent sine and analog input-noise source
      ds_run_modulators.m           Runs all candidate modulator architectures
      ds_run_mash_2_1.m             Selected two-stage MASH behavioral model
      ds_run_third_order_single_loop.m
                                     Third-order comparison model
      ds_measure_performance.m      Collects SINAD, ENOB, and filter metrics
      ds_coherent_inband_performance.m
                                     Coherent FFT-based SINAD/ENOB calculation
    filters/
      ds_design_filters.m           CIC/FIR design and coefficient quantization
      ds_filter_and_decimate.m      Floating-point architecture comparison path
      ds_filter_and_decimate_integer.m
                                     Bit-true CIC16/FIR4 golden reference
      ds_quantize_output.m          Signed 20-bit rounding and saturation
    analysis/
      ds_plot_results.m             Spectra and filter-response figures
      ds_print_summary.m            Console report and coefficient information
      ds_run_common_signal_tradeoff.m
                                     Required 0.5-2 ksps ENOB sweep
      ds_run_decimation_split_sweep.m
                                     Compares CIC/FIR decimation-factor splits
      ds_run_input_level_sweep.m    Input-level versus ENOB study
      ds_run_third_order_pole_sweep.m
                                     Third-order stability/design study

rtl_vectors/                        Generated RTL stimulus and golden outputs
README.md                           Project instructions and recorded results
```

### How the MATLAB directory is organized

The three files directly inside `matlab/` are the user-facing entry points:

- Start with `delta_sigma_adc.m` to reproduce the selected 2 ksps simulation
  or the complete Nyquist-rate tradeoff.
- `delta_sigma_adc_setup.m` only configures the MATLAB search path. It does
  not run a simulation or modify any design values.
- Use `export_rtl_test_vectors.m` when preparing files for the Verilog
  decimator testbench. It reruns the deterministic selected design before
  writing the vectors, so the stimulus and golden outputs remain matched.

Files under `matlab/src/` are implementation functions called by those entry
points. Normally, users should change design requirements in
`core/ds_default_config.m` rather than editing values independently in several
functions. The folders have separate responsibilities:

- `core/` builds the input, runs the delta-sigma modulators, and measures
  system performance.
- `filters/` designs and applies the decimation filters. The floating-point
  path is used for architecture studies; the integer path defines the exact
  signed widths, wrapping, scaling, rounding, and saturation expected from
  RTL.
- `analysis/` contains reporting, plots, and optional parameter sweeps. These
  functions analyze the design but do not define the selected configuration.

### MATLAB data flow

For one simulation point, the functions execute in this order:

1. `ds_default_config` creates the common specifications and selected design.
2. `ds_generate_signal` creates the coherent sine wave and seeded input noise.
3. `ds_run_modulators` produces candidate high-rate modulator streams. The
   selected MASH model also retains its two raw one-bit stage streams.
4. `ds_design_filters` creates the CIC response and the 64 signed 24-bit
   Q1.23 FIR coefficients.
5. `ds_filter_and_decimate` evaluates all architectures, while
   `ds_filter_and_decimate_integer` produces the bit-true selected result.
6. `ds_measure_performance` calculates SINAD and ENOB; the plot and summary
   functions then present those results.

The returned `results` structure contains performance values, coefficient
tables, and the integer-filter result. Raw MASH streams are intentionally not
stored in `results` because they are large; the RTL exporter regenerates and
writes them directly. Generated files belong in the top-level `rtl_vectors/`
directory and should not be confused with MATLAB source code.

## Requirements

- MATLAB R2025a or later
- Signal Processing Toolbox

## Run the submission study

Make the `matlab` directory the current MATLAB folder, then run:

```matlab
results = delta_sigma_adc;
```

This evaluates the selected design at 2 ksps and runs the required sweep from 0.5 to 2 ksps. To run the sweep without plots:

```matlab
study = delta_sigma_adc(500:250:2000, false);
```

## Selected design

| Item | Selected value |
| --- | --- |
| Modulator | Discrete-time MASH 2-1, two 1-bit stages |
| Modulator clock | 256 kHz |
| Input | 125 Hz coherent sine, -6 dBFS |
| Nominal ADC output | Signed 20-bit |
| Decimator | Fourth-order CIC by 16, then 64-tap FIR by 4 |
| Total decimation | 64 |
| Output sample rate | 4 ksps |
| FIR coefficients | Fixed 2 ksps design, signed 24-bit Q1.23 |
| Input-noise density | 69.745 nFS/sqrt(Hz) |

The physical input-noise density is derived from the 19-ENOB full-scale noise budget at the minimum 250 Hz signal bandwidth. This keeps the ideal behavioral simulation within the nominal 20-bit converter model.

The FIR is designed once for the most demanding 2 ksps Nyquist-rate case and reused at every sweep point. The signal frequency, amplitude, noise policy, output quantization, modulator settings, and FIR coefficients are therefore unchanged throughout the comparison.

## Export RTL test vectors

Run the following after making `matlab/` the current MATLAB folder:

```matlab
manifest = export_rtl_test_vectors;
```

This creates `rtl_vectors/` at the repository root. For a Verilog decimation
filter, the input stimulus is
`mash_combined_twos_complement.mem`: the digitally cancelled MASH 2-1 output,
represented as signed 5-bit two's-complement samples at 256 kHz. It contains
327,680 samples, one hexadecimal sample per line, with values from -9 to +9.
The decimator must therefore have a signed 5-bit input when digital MASH
cancellation is performed before the filter.

The files `mash_stage1_bits.mem` and `mash_stage2_bits.mem` are the two raw
one-bit MASH quantizer streams, using the mapping -1 to logic 0 and +1 to
logic 1. They are provided for testing the MASH cancellation logic and must
not be connected individually to the CIC. The combined 5-bit stream is the
correct direct CIC stimulus.

The vector package also contains:

- `fir_coefficients_twos_complement.mem`: 64 signed 24-bit Q1.23 FIR taps,
  with tap 0 first.
- `cic_output_twos_complement.mem`: golden signed 21-bit CIC results.
- `fir_output_twos_complement.mem`: golden signed 51-bit FIR accumulator
  results before normalization.
- `output_codes_20bit_twos_complement.mem`: golden signed 20-bit ADC output
  codes for final RTL comparison.
- `manifest.txt`: exact widths, sample counts, decimation phases, seeds, and
  the MASH digital cancellation equation.

## Required Nyquist-rate tradeoff

Measured ENOB for the same input and method at every rate:

| Nyquist rate (samples/s) | First order | Second order | Third-order single loop | MASH 2-1 |
| ---: | ---: | ---: | ---: | ---: |
| 500 | 11.521 | 17.725 | 18.056 | 18.052 |
| 750 | 10.865 | 16.831 | 17.614 | 17.698 |
| 1000 | 9.868 | 16.109 | 17.315 | 17.472 |
| 1250 | 9.702 | 15.324 | 16.781 | 17.306 |
| 1500 | 9.353 | 14.792 | 16.256 | 17.179 |
| 1750 | 9.078 | 14.246 | 15.404 | 17.072 |
| 2000 | 8.676 | 13.817 | 14.949 | 16.963 |

MASH 2-1 is selected because it is the only tested architecture that remains within the required 16-19 ENOB range at every requested Nyquist rate. Its ENOB also decreases monotonically as bandwidth increases. At 500 samples/s, MASH and the conventional third-order loop are effectively tied; MASH has the stronger result over the complete range.

The selected 2 ksps result is 16.963 ENOB. The floating-point filter using quantized coefficients and the integer bit-true reference produce identical signed 20-bit output codes for this test.

## Supporting design checks

After running `delta_sigma_adc_setup`, the focused checks are:

```matlab
input_sweep = ds_run_input_level_sweep(2000, -12:0.5:-0.5, true);
split_sweep = ds_run_decimation_split_sweep(2000, true);
pole_sweep = ds_run_third_order_pole_sweep(0.5:0.05:0.9, 2000, -6, true);
```

These scripts support the MASH selection, the 16-by-4 decimation split, and the stable third-order comparison. They do not change the fixed configuration used by the required rate sweep.

## Future RTL interface

The MATLAB bit-true decimator is the golden reference for a future independent HDL implementation. The HDL module should reuse the fixed FIR coefficient table, signed widths, rounding, and saturation behavior reported by the MATLAB result structure. RTL source and its testbench can be placed under a future top-level `rtl/` directory.
