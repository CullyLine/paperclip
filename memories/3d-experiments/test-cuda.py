"""Test CUDA allocation in the UniRig venv."""
import torch

print(f"PyTorch {torch.__version__}, CUDA {torch.version.cuda}")
print(f"GPU: {torch.cuda.get_device_name(0)}")
free, total = torch.cuda.mem_get_info()
print(f"Free: {free / 1024**2:.0f} MiB / {total / 1024**2:.0f} MiB")

x = torch.randn(1000, 1000, device="cuda")
print(f"1000x1000 f32: OK ({x.element_size() * x.nelement() / 1024**2:.1f} MiB)")

y = torch.randn(5000, 5000, device="cuda")
print(f"5000x5000 f32: OK ({y.element_size() * y.nelement() / 1024**2:.1f} MiB)")

del x, y
torch.cuda.empty_cache()

z = torch.randn(5000, 5000, device="cuda", dtype=torch.bfloat16)
print(f"5000x5000 bf16: OK ({z.element_size() * z.nelement() / 1024**2:.1f} MiB)")

del z
torch.cuda.empty_cache()

w = torch.randn(10000, 10000, device="cuda", dtype=torch.bfloat16)
print(f"10000x10000 bf16: OK ({w.element_size() * w.nelement() / 1024**2:.1f} MiB)")

del w
torch.cuda.empty_cache()
print("All CUDA allocation tests passed")
