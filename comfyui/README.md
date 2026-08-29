# Local Image Generation — ComfyUI + FLUX.1-dev on Docker

This setup runs **FLUX.1-dev** with FP8 weights in ComfyUI through Docker Desktop.
FP8 is appropriate for this machine's 16 GB GPU; model quality and behavior are not
intended to reproduce any specific hosted image service.

## Verified system (August 29, 2026)

| Component | Installed / detected |
|---|---|
| OS | Windows 11 Pro 25H2, build 26200, 64-bit |
| CPU | AMD Ryzen 9 9950X, 16 cores / 32 threads |
| System memory | 61.56 GiB usable (64 GB installed) |
| GPU | NVIDIA GeForce RTX 5080, 16,303 MiB VRAM |
| NVIDIA Windows driver | 610.88 |
| WSL | 2.4.11.0; kernel 5.15.167.4; Ubuntu and `docker-desktop` use WSL 2 |
| Docker Desktop | 4.88.1 |
| Docker Engine / CLI | 29.7.2 |
| Docker Compose | v5.4.0 |
| Docker VM resources | 32 logical CPUs and about 30.1 GiB RAM |
| Free disk space at verification | About 517 GiB on `C:` |

Docker GPU passthrough was verified successfully with the CUDA 12.8 Ubuntu test
image. The container detected the RTX 5080 and all 16,303 MiB of VRAM. The host also
has CUDA Toolkit 12.8 installed, although ComfyUI does not require a host CUDA toolkit
because its CUDA runtime is supplied by the container.

---

## 0. Files in this folder
- `docker-compose.yml` — runs ComfyUI with GPU passthrough
- `setup-folders.ps1` — creates the model/output folder structure and fixes ownership
- `flux_txt2img_workflow.json` — a ready-to-load text-to-image workflow

The image tag is pinned to `ubuntu24_cuda12.9-latest`. Blackwell (RTX 50-series)
requires `ubuntu24_cuda12.8` or newer, and pinning avoids `latest` silently moving to
a different CUDA version, which forces the Python environment to be rebuilt.

---

## 1. Install prerequisites

All required runtime dependencies are already installed and working on this machine:

- An NVIDIA driver with RTX 50-series support
- WSL 2 and its virtualization support
- Docker Desktop using its WSL 2 Linux engine
- Docker Compose and NVIDIA GPU passthrough

No separate Python, PyTorch, CUDA toolkit, or NVIDIA Container Toolkit installation
inside Ubuntu is required for this Docker setup. To re-check GPU passthrough after a
driver or Docker update, run:

   ```powershell
   docker run --rm --gpus all nvidia/cuda:12.8.0-base-ubuntu22.04 nvidia-smi
   ```

The output should list `NVIDIA GeForce RTX 5080` with approximately 16,303 MiB VRAM.
If it fails, first update the NVIDIA Windows driver, restart Docker Desktop, and verify
that Docker Desktop is using the WSL 2 engine. Do not install a second Linux NVIDIA
driver inside the `docker-desktop` distribution.

---

## 2. Set up folders

This checkout is already in a permanent location. Create the `basedir` tree once:

```powershell
cd C:\Users\devra\docker\comfyui
powershell -ExecutionPolicy Bypass -File setup-folders.ps1
```

This creates `basedir/models/{checkpoints,unet,clip,vae,loras,clip_vision}`,
`basedir/output`, `basedir/input`, `basedir/custom_nodes`, and `basedir/user`, then sets
them to UID/GID 1000.

### How the volumes are arranged

The container image expects one *run* directory at `/comfy/mnt` and a separate
*base* directory for user files. Do not bind-mount individual folders inside
`ComfyUI/` — that prevents the first-run install from completing.

| Location | Mounted at | Holds |
|---|---|---|
| `comfyui-run` Docker named volume | `/comfy/mnt` | ComfyUI source, the Python venv, Hugging Face cache |
| `./basedir` in this folder | `/basedir` | models, input, output, user, custom_nodes |

The run directory is a named volume on purpose: a Python virtual environment on a
Windows bind mount is slow and hits permission problems. Model files stay on a
normal Windows path so they are easy to manage.

> The container runs as UID/GID 1000 and exits if a mount is owned by anyone else.
> New folders start out as `root:root`, which is why setup runs a `chown`. If you add
> a folder later and startup fails with an ownership error, run:
> ```powershell
> docker run --rm -v C:\Users\devra\docker\comfyui\basedir:/basedir alpine chown -R 1000:1000 /basedir
> ```

---

## 3. Download Flux.1-dev models (fp8, fits in 16GB VRAM)

You need a free Hugging Face account + accept the FLUX.1-dev license at
`https://huggingface.co/black-forest-labs/FLUX.1-dev`.

Download these into the matching folders (use browser or `huggingface-cli`):

| File | Destination | Source |
|---|---|---|
| `flux1-dev-fp8.safetensors` (~12GB) | `basedir/models/unet/` | `Kijai/flux-fp8` or `black-forest-labs/FLUX.1-dev` (fp8 repack) |
| `t5xxl_fp8_e4m3fn.safetensors` (~5GB) | `basedir/models/clip/` | `comfyanonymous/flux_text_encoders` |
| `clip_l.safetensors` (~250MB) | `basedir/models/clip/` | `comfyanonymous/flux_text_encoders` |
| `ae.safetensors` (VAE, ~335MB) | `basedir/models/vae/` | `black-forest-labs/FLUX.1-dev` |

Optional CLI approach:
```powershell
pip install -U huggingface_hub
huggingface-cli login
huggingface-cli download comfyanonymous/flux_text_encoders t5xxl_fp8_e4m3fn.safetensors --local-dir .\basedir\models\clip
huggingface-cli download comfyanonymous/flux_text_encoders clip_l.safetensors --local-dir .\basedir\models\clip
huggingface-cli download black-forest-labs/FLUX.1-dev ae.safetensors --local-dir .\basedir\models\vae
huggingface-cli download Kijai/flux-fp8 flux1-dev-fp8.safetensors --local-dir .\basedir\models\unet
```
(Verify exact repo/filenames on Hugging Face at download time — repacked fp8 versions move between repos occasionally.)

Models can also be fetched from inside the web UI via ComfyUI Manager's Model Manager,
which writes straight into `basedir/models`.

---

## 4. Launch ComfyUI

```powershell
cd C:\Users\devra\docker\comfyui
docker compose up -d
```

The first start does a lot of work: it pulls a ~19 GB image, clones ComfyUI, and
builds a Python environment including PyTorch and the CUDA wheels (several more GB).
Expect a long wait and follow along with:
```powershell
docker compose logs -f
```

It is ready when the log shows `To see the GUI go to: http://0.0.0.0:8188`.

Open **http://localhost:8188** in your browser.

The port is published on `127.0.0.1` only, because ComfyUI has no authentication of
its own. To reach it from elsewhere, prefer publishing it through the Tailscale
service in this repository rather than binding it to `0.0.0.0`.

---

## 5. Load the starter workflow

1. In ComfyUI, click the folder/load icon (or drag-and-drop).
2. Load `flux_txt2img_workflow.json` from this folder.
3. Edit the `CLIPTextEncode` node's text to your prompt.
4. Click **Queue Prompt**. First run compiles CUDA kernels and is slower; subsequent runs are much faster (~5–15s per 1024x1024 image on a 5080).

Generated images land in `basedir/output/`. Docker Desktop currently assigns about
30.1 GiB of system RAM to its Linux VM. That is sufficient for this FP8 setup; if model
loading falls back heavily to CPU memory and fails, increase Docker Desktop's WSL
memory limit.

---

## 6. (Optional) Friendlier prompt-box UI

If you want a single text box instead of node graphs:
- **SwarmUI**: connects to your existing ComfyUI backend, gives a simple prompt/generate UI. Can run alongside in another container or natively on Windows pointing at `http://localhost:8188`.
- **Fooocus**: simpler standalone, but has its own model management (less flexible with raw Flux fp8 setups than SwarmUI/ComfyUI).

---

## 7. Common issues

- **`ERROR: Directory /comfy/mnt not found`**: the run volume is not mounted. The image
  needs `/comfy/mnt` plus a `BASE_DIRECTORY`; mounting paths inside `ComfyUI/` instead
  will fail this way.
- **`ERROR: Directory ... owned by unexpected user/group, expected 1000:1000`**: chown
  the mount as shown in step 2. `FORCE_CHOWN` does not help, because the container
  cannot re-own a path that was mounted at startup.
- **`Found Max driver CUDA version:` is blank, followed by `integer expression
  expected`**: harmless. Recent `nvidia-smi` prints `CUDA UMD Version` rather than
  `CUDA Version`, so the init script's parser comes up empty. Startup continues.
- **OOM / CUDA out of memory**: use the fp8 unet (already default here) or drop to `1024x1024` → `768x768`. GGUF-quantized Flux (Q8/Q6) is also viable via the `ComfyUI-GGUF` custom node if fp8 is still tight.
- **`nvidia-smi` not found in container**: Docker Desktop GPU support isn't enabled — recheck step 1.
- **Slow first generation**: normal, PyTorch/CUDA graph compilation on first run.
- **Blackwell/PyTorch compatibility**: GPU passthrough working in the CUDA test image
  proves that Docker can see the GPU, but the ComfyUI image must also contain a PyTorch
  build with RTX 50-series support. Check `docker compose logs` for errors mentioning
  `sm_120`, `no kernel image`, or an unsupported CUDA capability.
- **Rebuilding from scratch**: `docker compose down`, then
  `docker volume rm comfyui_comfyui-run`, then `docker compose up -d`. Models in
  `basedir/` are untouched.
