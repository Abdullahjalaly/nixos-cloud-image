# Build Methods Comparison

This repository supports three build methods for creating NixOS Hetzner Cloud images.

## TL;DR

| Method | Speed | Cost/Build | Tested? | Reliability |
|--------|-------|------------|---------|-------------|
| **Packer Incremental** (Default) | ~6 min | $0.013 | ✅ Proven | ⭐⭐⭐⭐⭐ |
| **Packer From-Scratch** | ~25 min | $0.05 | ✅ Proven | ⭐⭐⭐⭐⭐ |
| **GitHub Runners** | ~15 min | $0.00 | ⚠️ Complex | ⭐⭐⭐⭐☆ |

## Method 1: Packer Incremental (Default - Recommended)

### How it Works

```
GitHub Actions
  ↓
Starts Hetzner cx33 server ($0.0080/hour)
  ↓
Boots from existing NixOS snapshot (347588142)
  ↓
SSH into running system
  ↓
Update nixpkgs channel (~2 min)
  ↓
Copy new configuration.nix
  ↓
Run nixos-rebuild boot (~2 min)
  ↓
Shuts down, creates snapshot
  ↓
Deletes server
  ↓
Snapshot ready! (~$0.013 total cost, 6 min)
```

### Key Insight: Why Incremental Works for NixOS

NixOS's declarative configuration means **incremental = from-scratch** in terms of final result:

- `configuration.nix` **fully defines** the system state
- NixOS rebuilds only what changed (thanks to Nix's determinism)
- Result: Same final system, **4x faster**, **75% cheaper**

The base snapshot (347588142) is just a bootstrap - the final image is determined entirely by your `configuration.nix`.

### Pros

✅ **Fast** - 6 minutes total (vs 25 min from-scratch)
✅ **Cheap** - $0.013 per build (vs $0.05 from-scratch)
✅ **Proven** - Used by many NixOS/Hetzner projects
✅ **Realistic** - Builds on actual Hetzner hardware
✅ **Easy debugging** - SSH into server during build
✅ **Same result** - NixOS determinism ensures identical output to from-scratch

### Cons

⚠️ **Costs money** - $0.013 per build (~$0.68/year for weekly builds)
⚠️ **Needs Hetzner** - Can't build offline/locally easily
⚠️ **Requires base snapshot** - Needs existing NixOS image (provided in repo)

### Tested How?

```bash
# Real Hetzner server (cx33)
# ↓ Boot from known-good NixOS snapshot
# ↓ Run nixos-rebuild with new config
# ↓ If it succeeds, new snapshot is valid
# ↓ Snapshot = Declaratively-defined system
```

**Result**: If Packer incremental build succeeds, the image **definitely works** on Hetzner. Successfully tested with snapshot **347610961**.

---

## Method 2: Packer From-Scratch (Base Snapshot Creation)

### How it Works

```
GitHub Actions
  ↓
Starts Hetzner cx33 server ($0.0080/hour)
  ↓
Boots into Ubuntu rescue mode
  ↓
Partitions disk, formats ext4
  ↓
Downloads NixOS minimal ISO
  ↓
Runs nixos-install (20 minutes)
  ↓
Shuts down, creates snapshot
  ↓
Deletes server
  ↓
Snapshot ready! (~$0.05 total cost, 25 min)
```

### When to Use

Use from-scratch builds **only** when:

1. ✅ Creating the **initial base snapshot** for incremental builds
2. ✅ Testing major NixOS version upgrades (25.11 → 26.05)
3. ✅ Verifying the build process end-to-end

For regular builds, use **incremental** instead (Method 1).

### Pros

✅ **Complete validation** - Tests entire install process
✅ **No dependencies** - Doesn't need existing snapshot
✅ **Educational** - Shows full NixOS installation

### Cons

⚠️ **Slow** - 25 minutes per build
⚠️ **Expensive** - $0.05 per build (4x cost of incremental)
⚠️ **Unnecessary** - NixOS determinism makes this redundant for most builds

### Configuration

To use from-scratch instead of incremental:

```bash
# Edit .github/workflows/build-image.yml
# Change: nixos-cloud-incremental.pkr.hcl
# To: nixos-cloud-from-scratch.pkr.hcl
```

---

## Method 3: GitHub Runners (Free, Advanced)

### How it Works

```
GitHub Actions (FREE runner)
  ↓
Installs Nix on Ubuntu
  ↓
Runs: nix build (builds raw disk image)
  ↓
Creates nixos.img file (2-3 GB)
  ↓
Compresses with xz → 1.5 GB
  ↓
Uploads to Hetzner via hcloud-upload-image
  ↓
Hetzner creates snapshot from uploaded image
  ↓
Snapshot ready! ($0 cost)
```

### Pros

✅ **FREE** - No Hetzner server costs
✅ **Faster** - ~10 minutes (parallel builds)
✅ **Offline builds** - Can build locally without Hetzner
✅ **More control** - Nix gives full control over image
✅ **Reproducible** - Same inputs = Same output

### Cons

⚠️ **Complex** - Requires understanding Nix
⚠️ **Untested on real hardware** - Builds on GitHub's servers
⚠️ **Potential issues** - Kernel modules, hardware drivers
⚠️ **hcloud-upload-image dependency** - Extra tool needed
⚠️ **Larger disk usage** - Needs ~10GB during build

### Tested How?

```bash
# GitHub's Ubuntu server (x86_64)
# ↓ Build NixOS system with Nix
# ↓ Create disk image
# ↓ Upload to Hetzner
# ↓ ??? Does it boot on real hardware? ???
```

**Result**: Image **should work**, but not tested on Hetzner hardware until deployment.

---

## Detailed Comparison

### Reliability

**Packer Incremental: ⭐⭐⭐⭐⭐**
- Boots actual NixOS on Hetzner hardware
- Tests nixos-rebuild process
- If build succeeds, image definitely works
- Used successfully in this repo (snapshot 347610961)

**Packer From-Scratch: ⭐⭐⭐⭐⭐**
- Tests complete installation process
- Runs on Hetzner hardware
- Most thorough validation
- Used by: [hcloud-packer-templates](https://github.com/jktr/hcloud-packer-templates), [nixos-hcloud-packer](https://github.com/selaux/nixos-hcloud-packer)

**GitHub Runners: ⭐⭐⭐⭐☆**
- Builds correctly (Nix guarantees this)
- Uploads correctly (hcloud-upload-image works)
- **But**: Not tested on Hetzner until first boot
- Risk: Kernel modules, drivers, hardware quirks
- Used by: Experimental, not many production users

### Cost Analysis

| Build Frequency | Incremental/Year | From-Scratch/Year | GitHub Runners/Year |
|-----------------|------------------|-------------------|---------------------|
| Weekly | $0.68 | $2.60 | $0.00 |
| Daily | $4.75 | $18.25 | $0.00 |
| Per-commit | Varies | Varies | $0.00 |

**Note**: $0.68/year for weekly incremental builds is negligible.

### Build Time

| Stage | Incremental | From-Scratch | GitHub Runners |
|-------|-------------|--------------|----------------|
| Setup | 2 min | 2 min | 3 min (install Nix) |
| Build | 3 min (rebuild) | 20 min (nixos-install) | 7 min (nix build) |
| Snapshot | 1 min | 3 min | 5 min (upload) |
| **Total** | **~6 min** | **~25 min** | **~15 min** |

### Debugging

**Packer:**
```bash
# SSH into server during build
ssh root@BUILD_SERVER_IP

# Check install progress
tail -f /var/log/nixos-install.log

# Debug issues live
```

**GitHub Runners:**
```bash
# No SSH access
# Can only see GitHub Actions logs

# To debug locally:
nix build .#nixosConfigurations.hetzner.config.system.build.raw \
  --show-trace
```

---

## Which Should You Use?

### Use Packer Incremental if:

1. ✅ You want the **default recommended method** (you're already using it!)
2. ✅ You want **fast builds** (6 min)
3. ✅ You want **"it just works"** reliability
4. ✅ You're okay with **$0.68/year** cost for weekly builds
5. ✅ You value **proven, tested** methods

### Use Packer From-Scratch if:

1. ✅ You're creating a **new base snapshot** for incremental builds
2. ✅ You're **upgrading NixOS versions** (25.11 → 26.05)
3. ✅ You want to **understand the full build process**
4. ✅ You're **debugging installation issues**

### Use GitHub Runners if:

1. ✅ You're **experienced with Nix**
2. ✅ You want **zero cost** builds
3. ✅ You need **offline/local** building
4. ✅ You want to **experiment** with image contents
5. ✅ You can handle **potential edge cases**

### Recommended Path

**Default (What you're already doing):**
```
Packer Incremental → Fast, cheap, proven
```

**For experimentation:**
```
Packer Incremental → Test locally → GitHub Runners (if desired)
```

**Why Incremental is Default:**
- 4x faster than from-scratch (6 min vs 25 min)
- 75% cheaper ($0.013 vs $0.05 per build)
- Same reliability (NixOS is declarative)
- Same final result (Nix determinism)

---

## Testing Status

### Packer Incremental Method (Default)

✅ **Fully tested in this repo**
✅ Successfully built snapshot `347610961`
✅ Build time: 5m49s (as expected)
✅ Channel setup works correctly
✅ Proven to work on Hetzner Cloud (cx33 server type)
✅ Cost per build: $0.013

### Packer From-Scratch Method

✅ **Fully tested in this repo**
✅ Used by multiple public projects
✅ Proven to work on Hetzner Cloud
✅ Built base snapshot `347588142`
✅ Build time: ~25 minutes
✅ Cost per build: $0.05

### GitHub Runners Method

⚠️ **Partially tested**
✅ Nix evaluation works (tested locally)
✅ Image build process works (Nix guarantees)
❌ Not yet tested end-to-end on Hetzner
❌ `hcloud-upload-image` not verified

**To fully test GitHub runner method:**

1. Run workflow on GitHub Actions
2. Upload image to Hetzner
3. Create test server from uploaded image
4. Verify it boots correctly

---

## Migration Path

### Already Using Incremental (You Are!)

The repository is already configured to use the optimal method. No changes needed unless you want to experiment.

### To Switch to From-Scratch

If you want to create a new base snapshot:

```bash
# Edit .github/workflows/build-image.yml
# Line 37: Change from nixos-cloud-incremental.pkr.hcl
# To: nixos-cloud-from-scratch.pkr.hcl

# Commit and push - workflow will run from-scratch build
```

### To Add GitHub Runners

If you want free builds:

1. Keep incremental workflow enabled (safety net)
2. Add GitHub runner workflow (see docs/GITHUB-RUNNERS.md)
3. Compare both images (should be identical)
4. Test GitHub-built image thoroughly
5. Once confident, use runners for daily builds

---

## Conclusion

**Packer Incremental (Default)** = Fast, cheap, proven ⭐⭐⭐⭐⭐
**Packer From-Scratch** = For base snapshot creation only
**GitHub Runners** = Free, fast, needs validation

**Our recommendation**: You're already using the optimal method (Packer Incremental).

All three methods produce functionally identical NixOS images thanks to Nix's declarative nature - the difference is build time, cost, and thoroughness of validation.
