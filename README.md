# 20-Bit Delta-Sigma ADC MATLAB Model

This repository contains the MATLAB model and simulation study for a nominal 20-bit delta-sigma ADC. It covers the required modulator comparison, the 0.5-2 ksps Nyquist-rate versus ENOB study, and a bit-true MATLAB reference for the selected decimation filter.

HDL is intentionally not included. It can later be added as an independent `rtl/` module without mixing MATLAB and Verilog sources.

## Repository layout

```text
matlab/
  delta_sigma_adc.m          Main simulation entry point
  delta_sigma_adc_setup.m    Adds the MATLAB source folders to the path
  src/
    core/                    Stimulus, modulators, and performance measurement
    filters/                 Decimation-filter design and bit-true reference
    analysis/                Required tradeoff and supporting design sweeps

rtl/                         Future independent HDL module; not included
```

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
| Decimator | Fourth-order CIC by 16, then 65-tap FIR by 4 |
| Total decimation | 64 |
| Output sample rate | 4 ksps |
| FIR coefficients | Fixed 2 ksps design, signed Q1.22 |
| Input-noise density | 69.745 nFS/sqrt(Hz) |

The physical input-noise density is derived from the 19-ENOB full-scale noise budget at the minimum 250 Hz signal bandwidth. This keeps the ideal behavioral simulation within the nominal 20-bit converter model.

The FIR is designed once for the most demanding 2 ksps Nyquist-rate case and reused at every sweep point. The signal frequency, amplitude, noise policy, output quantization, modulator settings, and FIR coefficients are therefore unchanged throughout the comparison.

## Required Nyquist-rate tradeoff

Measured ENOB for the same input and method at every rate:

| Nyquist rate (samples/s) | First order | Second order | Third-order single loop | MASH 2-1 |
| ---: | ---: | ---: | ---: | ---: |
| 500 | 11.521 | 17.688 | 18.055 | 18.056 |
| 750 | 10.864 | 16.813 | 17.609 | 17.704 |
| 1000 | 9.868 | 16.101 | 17.316 | 17.478 |
| 1250 | 9.702 | 15.321 | 16.775 | 17.307 |
| 1500 | 9.354 | 14.792 | 16.252 | 17.189 |
| 1750 | 9.078 | 14.247 | 15.405 | 17.076 |
| 2000 | 8.676 | 13.817 | 14.952 | 16.962 |

MASH 2-1 is selected because it is the only tested architecture that remains within the required 16-19 ENOB range at every requested Nyquist rate. Its ENOB also decreases monotonically as bandwidth increases. At 500 samples/s, MASH and the conventional third-order loop are effectively tied; MASH has the stronger result over the complete range.

The selected 2 ksps result is 16.962 ENOB. The floating-point filter using quantized coefficients and the integer bit-true reference produce identical signed 20-bit output codes for this test.

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
