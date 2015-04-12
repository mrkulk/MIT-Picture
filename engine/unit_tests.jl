#Picture : Unit tests
include("torch_interface.jl")
using TORCH
TORCH.load_torch_script("test.lua")
TORCH.call("get_samples", 1)