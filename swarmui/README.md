# SwarmUI — primary image generation UI

A prompt box, a model dropdown, and an image editor, with ComfyUI running underneath
as the engine. This is the front door for image work; the [comfyui](../comfyui/README.md)
stack remains available for node-graph editing.

**http://localhost:7801**

---

## 0. What is set up

| Piece | Where |
|---|---|
| SwarmUI web UI | `127.0.0.1:7801` |
| ComfyUI backend | Self-started inside the container, in the `swarmui-backend` volume |
| Models | Shared with ComfyUI at `../comfyui/basedir/models` |
| Generated images | `swarmui/Output/` |
| Settings, users, history | `swarmui-data` volume |

Models are **shared, not copied**. SwarmUI's model folder settings were widened to
include ComfyUI's folder names, so the same 16 GB of FLUX weights serves both apps:

```
SDModelFolder: Stable-Diffusion;checkpoints;unet;diffusion_models
SDLoraFolder:  Lora;loras
SDVAEFolder:   VAE;vae
SDClipFolder:  text_encoders;clip
```

Anything either app downloads lands in the same place and appears in both.

---

## 1. Daily use

```powershell
cd C:\Users\devra\docker\swarmui
docker compose up -d
```

Then open **http://localhost:7801**. It starts automatically on boot
(`restart: unless-stopped`), so normally there is nothing to run.

The first generation after a restart loads 11 GB of weights and takes a few minutes.
Later ones take about 20 seconds at 1024x1024 with 20 steps.

---

## 2. Creating an image

1. Open the **Generate** tab.
2. Pick `flux1-dev-fp8.safetensors` from the model list on the left.
3. Type a prompt in the box.
4. Press **Generate**.

Useful parameters, all on the left panel:

| Parameter | Suggested | Notes |
|---|---|---|
| Images | 1-4 | Batch count |
| Resolution | 1024x1024, or 896x1152 for portraits | FLUX is trained at ~1 megapixel |
| Steps | 20-28 | Above ~30 gains little |
| CFG Scale | **1.0** | Must stay 1.0 for FLUX.1-dev |
| Flux Guidance | **2.0-2.8** for realism, 3.5 default | The main quality dial |
| Seed | -1 for random | Reuse a seed to keep a subject and vary the rest |

FLUX.1-dev is guidance-distilled, so **the negative prompt does nothing** and CFG must
stay at 1.0. Steer with Flux Guidance instead: lower is more photographic, higher
follows the prompt more literally but looks more synthetic.

Write in full sentences rather than comma-separated tags. Naming a camera and lens
("shot on a Canon EOS R5, 85mm f/1.4") and asking for skin texture measurably improves
realism.

---

## 3. Editing an existing photo

Use the **Init Image** panel on the Generate tab.

**Whole-image restyle or variation**

1. Open **Init Image** and drop your photo in.
2. Set **Creativity** (denoise strength): 0.2-0.4 keeps the original closely, 0.6-0.8
   is a loose reinterpretation.
3. Prompt for what you want, then **Generate**.

**Inpainting — change part of an image**

1. Drop the image into **Init Image**.
2. Click **Edit Image** to open the built-in editor.
3. Paint a mask over the region to change.
4. Prompt for what belongs there, then **Generate**.

**Outpainting — extend beyond the borders**

In the image editor, enlarge the canvas, leave the new area masked, and prompt for the
surroundings.

**Instruction editing** ("make her jacket red", no masking) needs the FLUX Kontext
model. See section 4; once installed, select it as the model and put an init image in.

Every generated image is kept, so nothing is destroyed. Browse past work in the
**Image History** tab.

---

## 4. Adding a model

**Easiest — from inside SwarmUI.** Open the **Models** tab, then **Download Models**,
paste a Hugging Face or CivitAI link, and pick the type. It lands in the shared folder
and appears in ComfyUI too.

**Manually.** Drop the file into the matching folder under
`C:\Users\devra\docker\comfyui\basedir\models\`:

| Type | Folder |
|---|---|
| Checkpoint (SDXL, SD 3.5) | `checkpoints` |
| Diffusion model / UNet (FLUX, Qwen) | `unet` |
| LoRA | `loras` |
| VAE | `vae` |
| Text encoder | `clip` or `text_encoders` |
| ControlNet | `controlnet` |

Then click **Refresh** in the Models tab.

New files created from Windows may not be readable by the container. If a model does
not appear, re-apply ownership:

```powershell
docker run --rm -v C:\Users\devra\docker\comfyui\basedir:/basedir alpine chown -R 1000:1000 /basedir
```

Unlike raw ComfyUI, SwarmUI builds the correct workflow for whichever model you pick,
so there is no rewiring when switching between FLUX, SDXL, or anything else. It also
auto-downloads missing components: selecting FLUX for the first time fetched
`t5xxl_enconly.safetensors` (~5 GB) on its own.

---

## 5. Maintenance

Update (also handled by [Update_Docker_Images.bat](../Update_Docker_Images.bat)):

```powershell
cd C:\Users\devra\docker\swarmui
git -C SwarmUI pull
docker compose build
docker compose up -d
```

**Never run `docker compose down -v` here.** The `swarmui-*` volumes hold the ComfyUI
backend, its Python environment (~11 GB), and all settings and history. Rebuilding
means another long download.

Disk use, if you need to reclaim space:

```powershell
docker exec swarmui du -sh /SwarmUI/dlbackend /SwarmUI/Data
```

---

## 6. Notes and gotchas

- **Bound to `127.0.0.1` only.** SwarmUI has no authentication in this configuration.
  To reach it remotely, publish it through the Tailscale service rather than binding
  to `0.0.0.0`.
- **Built from source.** There is no official published image, so `swarmui/SwarmUI/`
  is an upstream git clone. It is gitignored; `docker compose build` compiles it.
- **Do not pick "just yourself" if you ever rerun the installer.** That option binds
  SwarmUI to `localhost` *inside* the container, which Docker's port mapping cannot
  reach, and the UI becomes unreachable. Use **"just yourself (LAN)"**; the container
  is already isolated by the `127.0.0.1` port binding.
  [install-backend.ps1](install-backend.ps1) records the correct values.
- **Volumes must be owned by UID 1000.** New Docker volumes start root-owned and
  SwarmUI refuses to start, logging a `fixch` hint. Fix with:
  ```powershell
  docker run --rm -v swarmui_swarmui-data:/a -v swarmui_swarmui-backend:/b -v swarmui_swarmui-dlnodes:/c -v swarmui_swarmui-extensions:/d -v swarmui_swarmui-workflows:/e alpine chown -R 1000:1000 /a /b /c /d /e
  ```
- **Two ComfyUI backends now exist** — this one, and the standalone `comfyui`
  container. They share models but not GPU memory. Running a large generation in both
  at once will contend for the 16 GB of VRAM; use one at a time.
- **The DotNET 10 warning in the logs is harmless.** SwarmUI builds against .NET 8
  today and warns about a future requirement.
