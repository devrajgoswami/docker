# Local Image Generation — ComfyUI + FLUX.1-dev on Docker

> **SwarmUI is the primary UI for image generation and editing:
> http://localhost:7801.** It offers a prompt box, a model dropdown, and an image
> editor, and it shares this folder's models. See [../swarmui/README.md](../swarmui/README.md).
>
> Use ComfyUI directly when you want to build node graphs by hand. Both apps read
> models from `comfyui/basedir/models`, so anything downloaded in one appears in the
> other.

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
- `flux_txt2img_workflow.json` — graph workflow to load in the browser UI
- `flux_txt2img_api.json` — the same graph in API format, for `POST /prompt`

The two workflow files are not interchangeable. The UI loads the graph format; the
`/prompt` endpoint accepts only the API format.

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
pip install -U "huggingface_hub[cli,hf_xet]<1.0"
hf auth login
hf download comfyanonymous/flux_text_encoders t5xxl_fp8_e4m3fn.safetensors --local-dir .\basedir\models\clip
hf download comfyanonymous/flux_text_encoders clip_l.safetensors --local-dir .\basedir\models\clip
hf download black-forest-labs/FLUX.1-dev ae.safetensors --local-dir .\basedir\models\vae
hf download Kijai/flux-fp8 flux1-dev-fp8.safetensors --local-dir .\basedir\models\unet
```

Notes:
- `huggingface-cli` is retired; the command is now `hf`. Pin `huggingface_hub` below
  1.0 if `transformers` or `tokenizers` share the same environment, as they require it.
- `ae.safetensors` is gated. Accept the licence at the FLUX.1-dev repo page first, or
  the download returns 403. The other three files are open.
- `hf download` leaves a `.cache` folder beside each file that duplicates the download.
  Delete `basedir/models/*/.cache` afterwards to reclaim the space.
- Verify exact repo/filenames on Hugging Face at download time — repacked fp8 versions
  move between repos occasionally.

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
4. Click **Queue Prompt**. The first run loads 11 GB of weights and compiles CUDA
   kernels, so it takes a few minutes. Measured on this machine, a warm run at
   1024x1024 and 20 steps takes about 17 s.

Generated images land in `basedir/output/`. Docker Desktop currently assigns about
30.1 GiB of system RAM to its Linux VM. That is sufficient for this FP8 setup; if model
loading falls back heavily to CPU memory and fails, increase Docker Desktop's WSL
memory limit.

---

## 6. Adding a new model

### Where files go

The folder decides which node can see a file. Everything lives under
`C:\Users\devra\docker\comfyui\basedir\models\`.

| Model type | Folder | Loader node |
|---|---|---|
| All-in-one checkpoint (SDXL, SD 3.5) | `checkpoints` | `CheckpointLoaderSimple` |
| Diffusion model / UNet only (FLUX, Qwen, Z-Image) | `unet` | `UNETLoader` |
| Text encoder | `clip` | `CLIPLoader`, `DualCLIPLoader` |
| VAE | `vae` | `VAELoader` |
| LoRA | `loras` | `LoraLoader`, `LoraLoaderModelOnly` |
| Upscaler | `upscale_models` | `UpscaleModelLoader` |
| CLIP vision | `clip_vision` | `CLIPVisionLoader` |
| Textual inversion | `embeddings` | prompt syntax: `embedding:name` |

Some folders ComfyUI supports do not exist here yet, notably `controlnet`,
`diffusion_models`, and `text_encoders`. Create the folder yourself if a model needs
one, then re-apply ownership (see below).

### Three ways to install

**A. ComfyUI Manager (easiest).** In the web UI, click **Manager** → **Model
Manager**, search, and install. It picks the correct folder automatically and handles
gated repos if a token is configured.

**B. Command line.** Best for large or gated files, because it resumes:

```powershell
cd C:\Users\devra\docker\comfyui
hf download <repo-id> <filename> --local-dir .\basedir\models\<folder>
```

**C. Copy the file in** to the matching folder with Explorer.

### After installing

1. Delete the `.cache` folder that `hf download` leaves behind (see section 7).
2. In the web UI press **R**, or click **Refresh**, to repopulate the dropdowns. No
   container restart is needed.
3. If a loader dropdown stays empty, the file is in the wrong folder or unreadable.
   Re-apply ownership:
   ```powershell
   docker run --rm -v C:\Users\devra\docker\comfyui\basedir:/basedir alpine chown -R 1000:1000 /basedir
   ```

### Wiring it into a workflow

A new model usually needs a different graph, not just a different filename in the
dropdown. Two mismatches cause most errors:

- **Checkpoints bundle model + CLIP + VAE.** A single `CheckpointLoaderSimple`
  replaces `UNETLoader`, `DualCLIPLoader`, and `VAELoader` together. Loading an SDXL
  checkpoint into `UNETLoader` will not work.
- **The empty-latent node must match the model family.** `EmptySD3LatentImage` is
  16-channel and is used by FLUX, SD3, and Qwen. SDXL and SD 1.5 need
  `EmptyLatentImage`, which is 4-channel. Mixing them produces the shape-mismatch
  errors described in section 9.

Sampler settings differ too. FLUX.1-dev is guidance-distilled and runs at `cfg 1.0`
with `FluxGuidance`, so its negative prompt is inert. SDXL and SD 3.5 use a real
`cfg` around 5-8 and honour negative prompts.

The reliable shortcut is **Workflow → Browse Templates**. The install ships correct,
ready-made graphs for the models it supports, and Manager offers to download whatever
weights are missing. Start from a template rather than rewiring by hand.

---

## 7. Housekeeping and disk cleanup

Check current usage first:

```powershell
docker exec comfyui du -sh /comfy/mnt/uv_cache /comfy/mnt/venv /comfy/mnt/ComfyUI /comfy/mnt/HF
docker system df
```

### Safe to delete

**Hugging Face download caches.** `hf download` writes a `.cache` folder next to each
file holding a second full copy of the model. This is the single biggest easy win —
it roughly doubles the size of every download until removed:

```powershell
cd C:\Users\devra\docker\comfyui
Get-ChildItem .\basedir\models -Recurse -Directory -Filter '.cache' | Remove-Item -Recurse -Force
```

**ComfyUI scratch space.** Preview and intermediate files:

```powershell
Get-ChildItem .\basedir\temp -File -Recurse | Remove-Item -Force
```

**The uv package cache.** It reached 8.3 GB here after the PyTorch install. It is
rebuilt automatically on the next package install:

```powershell
docker exec comfyui rm -rf /comfy/mnt/uv_cache
```

Note that this frees less than its reported size. uv hardlinks packages from the cache
into the venv, so large libraries carry two links and the data survives until both are
gone. Clearing the cache is safe — it never breaks the venv — but measure the real
gain with `docker system df` rather than trusting the `du` figure.

**Dangling Docker images:**

```powershell
docker image prune -f
```

### Not worth deleting

- **The empty folders in `basedir/models`.** They are ComfyUI's standard layout, cost
  no space, and the container recreates them from ComfyUI's own `models/` tree on the
  next start. They also document where each model type belongs.
- **`basedir/user`.** Small, and holds the ComfyUI database, saved workflows, settings,
  and Manager cache.

### Never do this

- **`docker compose down -v`** destroys the `comfyui-run` volume, forcing a multi-GB
  reinstall of ComfyUI and PyTorch.
- **`docker volume prune`** operates on the whole machine, not just this stack. Other
  services in this repository keep state in volumes, and Tailscale's holds its node
  identity.
- **Deleting `basedir/models` contents** to save space. All four FLUX files are
  required; re-downloading is about 16 GB.

---

## 8. Simpler prompt-box UI

**SwarmUI is already installed for this** at http://localhost:7801 — a prompt box, a
model dropdown, an image editor for inpainting and photo edits, and automatic workflow
building for whichever model you select. It shares this folder's models. See
[../swarmui/README.md](../swarmui/README.md).

Fooocus is the other well-known simple UI, but it is SDXL-only, cannot load FLUX, and
is no longer actively maintained, so it would strand these weights.

---

## 9. Common issues

- **`ERROR: Directory /comfy/mnt not found`**: the run volume is not mounted. The image
  needs `/comfy/mnt` plus a `BASE_DIRECTORY`; mounting paths inside `ComfyUI/` instead
  will fail this way.
- **`ERROR: Directory ... owned by unexpected user/group, expected 1000:1000`**: chown
  the mount as shown in step 2. `FORCE_CHOWN` does not help, because the container
  cannot re-own a path that was mounted at startup.
- **`Found Max driver CUDA version:` is blank, followed by `integer expression
  expected`**: harmless. Recent `nvidia-smi` prints `CUDA UMD Version` rather than
  `CUDA Version`, so the init script's parser comes up empty. Startup continues.
- **`mat1 and mat2 shapes cannot be multiplied (77x768 and 4096x3072)`**: the text
  encoder is wrong for FLUX. `77x768` is CLIP-L alone, but FLUX's `txt_in` layer
  expects T5-XXL's 4096-dim output. Use `DualCLIPLoader` with `t5xxl_fp8_e4m3fn` +
  `clip_l` and type `flux`, not a single `CLIPLoader`. This usually means a workflow
  built for another model (Z-Image, Lumina, SD3) had FLUX files selected in it.
- **Workflow will not load in the browser**: check you are opening
  `flux_txt2img_workflow.json` and not `flux_txt2img_api.json`. The API format has no
  node positions and is meant for `POST /prompt`.
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
