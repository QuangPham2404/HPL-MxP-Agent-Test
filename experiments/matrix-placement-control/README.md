# FP64 Matrix Placement Control

# Details

The idea is that the more part of the FP64 original matrix stored in VRAM, the faster the IR process, which is a clear bottle neck as we already see from our baseline run reported timings. With VRAM unused fully after we push n and nb, i think we can ultilize it for this "Precision and memory-placement controls" with these flags:

- `--sloppy-type <value>`

- `--Anq-device <int>`

- `--fill-device <0|1>`

- `--fill-device-buffer-size <int>`

- `--cuda-host-register-step <int>`
