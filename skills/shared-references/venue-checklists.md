# Venue Checklists for ICLR, NeurIPS, ICML, CVPR, IEEE, and Robotics Venues

Use this reference near the end of `paper-plan` and during the final checks in `paper-write`.

## When to Read

- Read once when setting the target venue.
- Read again before locking the outline.
- Read again during final submission-readiness checks.

## Universal Requirements

Across these venues, the following are usually expected:

- anonymous submission unless preparing a camera-ready version,
- references and appendices outside the main page budget,
- enough experimental detail for reproduction,
- honest limitations and scope boundaries,
- clear mapping from claims to evidence.

## NeurIPS

Planning implications:

- The paper checklist is mandatory.
- Claims in the Abstract and Introduction must align with the actual evidence.
- The paper should discuss limitations honestly.
- Reproducibility details, hyperparameters, data access, and compute usage should be documented.
- Statistical reporting should specify error bars, number of runs, and how uncertainty is computed.

Final-check implications:

- Confirm the paper checklist is complete.
- Ensure limitations, reproducibility details, and compute reporting exist somewhere appropriate.
- Verify theory papers include assumptions and full proofs in the main paper or appendix.

## ICML

Planning implications:

- The paper must budget space for an ICML-style Broader Impact statement.
- Reproducibility expectations are strong: data splits, hyperparameters, search ranges, and compute should be documented.
- Statistical reporting should state whether uncertainty uses standard deviation, standard error, or confidence intervals.

Final-check implications:

- Ensure the Broader Impact statement is present in the expected location.
- Confirm anonymization is strict: no author names, acknowledgments, grant IDs, or self-identifying repository links.
- Verify experimental details are detailed enough for replication.

## ICLR

Planning implications:

- Reproducibility and ethics statements are often recommended even if not always mandatory.
- If LLMs materially contributed to ideation or writing to the point of authorship-like contribution, plan a disclosure section or appendix note.
- Keep the story front-loaded because ICLR reviewers often judge quickly from the early pages.

Final-check implications:

- Decide whether LLM disclosure is required for this project.
- Confirm the paper includes enough reproducibility guidance, code/data availability information, and limitations discussion.
- Check that the contribution is already clear by the end of the Introduction.

## IEEE Journal (Transactions / Letters)

Planning implications:

- IEEE journals are typically **not anonymous** — include full author names, affiliations, and IEEE membership status from submission.
- Use `\documentclass[journal]{IEEEtran}` with `\cite{}` (numeric citations via `cite` package). Do NOT use `natbib`.
- References **count toward the page limit**. IEEE Transactions typically allow 12-14 pages total; IEEE Letters (e.g., WCL, CL, SPL) typically allow 4-5 pages total. Check the specific journal's author guidelines.
- Include an `\begin{IEEEkeywords}` block immediately after the abstract.
- The bibliography style must be `IEEEtran.bst` (produces numeric `[1]` style citations).
- IEEE journals may require a biosketch (`\begin{IEEEbiography}`) for each author in the camera-ready version.
- Some IEEE journals require a cover letter addressing how the paper differs from conference versions (if applicable).

Final-check implications:

- Confirm author names and IEEE membership grades are correct (Member, Senior Member, Fellow).
- Verify the total page count including references is within the journal's limit.
- Check that all figures meet IEEE quality requirements: 300 dpi minimum, proper axis labels, readable when printed in grayscale.
- Ensure the paper uses two-column IEEE format throughout (the `[journal]` option handles this).
- Verify no `\citep` or `\citet` commands are present — IEEE uses `\cite{}` only.
- Check that `\bibliographystyle{IEEEtran}` is used.

## IEEE Conference (ICC, GLOBECOM, INFOCOM, ICASSP, etc.)

Planning implications:

- Most IEEE conferences are **not anonymous** (except some like IEEE S&P). Include full author information.
- Use `\documentclass[conference]{IEEEtran}` with `\cite{}` (numeric citations).
- References **count toward the page limit**. Typical limit: 5-6 pages (e.g., ICC, GLOBECOM), some allow up to 8 pages (e.g., INFOCOM). Extra pages may incur additional charges.
- Include `\begin{IEEEkeywords}` after the abstract.
- Conference papers do NOT include author biographies.
- Some IEEE conferences accept 2-page extended abstracts — confirm the paper category before planning.

Final-check implications:

- Verify total page count including references fits within the conference limit.
- Check that figures are readable at the two-column conference format size.
- Ensure `\bibliographystyle{IEEEtran}` is used.
- Verify no `\citep` or `\citet` commands are present.
- Confirm the correct `\documentclass` option (`[conference]`, not `[journal]`).
- Some conferences require IEEE copyright notice — check submission portal for specific requirements.

## IEEE RA-L (Robotics and Automation Letters)

RA-L is a hybrid: journal quality, letter format, with optional ICRA/IROS presentation.

Planning implications:

- **Page limit**: 6-8 pages TOTAL (including references, figures, everything). Regular paper: 6 pages base + up to 2 extra pages with overlength charge.
- **NOT anonymous** — include full author names, affiliations, and IEEE membership status from submission.
- Use `\documentclass[journal]{IEEEtran}` with `\cite{}` (numeric citations via `cite` package). Do NOT use `natbib`.
- References **count toward the page limit**. Budget accordingly — typically 0.5-0.8 pages for references.
- Include `\begin{IEEEkeywords}` block immediately after the abstract.
- Bibliography style: `IEEEtran.bst` (numeric `[1]` style).
- Multimedia attachments (videos) are strongly encouraged, 10 MB limit. Reference in text: "The accompanying video demonstrates..."
- RA-L papers can opt-in for presentation at ICRA or IROS. Mention in cover letter, not in the paper itself.

Final-check implications:

- Technical quality and rigor are paramount — RA-L reviewers expect depth.
- Experimental validation: real-world experiments strongly preferred; simulation acceptable if well-justified.
- Quantitative comparison on standard benchmarks/datasets with recent baselines (within 2 years).
- Statistical analysis: mean ± std across multiple runs/sequences.
- Runtime/latency analysis if real-time claims are made.
- Ablation studies demonstrating the contribution of each component.
- Failure case analysis is expected by RA-L reviewers.
- Verify total page count including references is within 6-8 pages.
- Check that all figures meet IEEE quality requirements: 300 dpi minimum, readable in grayscale.
- Verify no `\citep` or `\citet` commands — IEEE uses `\cite{}` only.
- Author biography (`\begin{IEEEbiography}`) is optional but recommended for camera-ready.

## CVPR (also ICCV, ECCV)

Planning implications:

- Use the CVPR LaTeX template (`cvpr.sty`). Double-column, 10pt, letterpaper.
- **Double-blind review** — anonymous submission required. No author names, acknowledgments, project URLs, or funding identifiers.
- Main body: 8 pages maximum (excluding references). References do NOT count toward the page limit.
- CVPR reviewers weight **visual quality** heavily. Plan a strong Figure 1 (architecture or teaser results).
- **Novelty expectations are high** — "combining existing methods on a new dataset" is insufficient for acceptance.
- Quantitative comparison on **standard benchmarks** is mandatory, not optional.
- Ablation studies demonstrating each component's contribution are expected in all method papers.
- Include training cost (GPU-hours, hardware) in the experiments section.
- For generative/visual results: include **failure cases** alongside successes.

Final-check implications:

- Confirm strict anonymization: no author names, no GitHub links, no self-citing "our previous work [Author, Year]".
- Verify figure quality: 300 dpi minimum, vector graphics preferred, readable at two-column width.
- Supplementary material (if any) must also be anonymized.
- Comparison with state-of-the-art methods published within the last 2 years on standard benchmarks.
- Ablation studies present and each architectural choice justified.
- Statistical reporting: mean ± std across seeds, significance indicators for close comparisons.
- Reproducibility: hyperparameters, random seeds, compute details documented.

## IEEE TRO (Transactions on Robotics)

TRO is a premium IEEE journal for robotics. Longer format, higher rigor bar than conference papers.

Planning implications:

- **NOT anonymous** — include full author names, affiliations, IEEE membership.
- Use `\documentclass[journal]{IEEEtran}` with `\cite{}` (numeric, via `cite` package).
- Typical length: 12-16 pages including references. No strict page limit, but reviewers expect concise writing.
- References count toward the total length.
- TRO **requires real-world experiments** or extremely strong justification for simulation-only work.
- Quantitative comparison against state-of-the-art on standard benchmarks with full statistical reporting (mean ± std, number of trials).
- Include **runtime/computational complexity analysis**.
- Cover letter should position the contribution relative to any prior conference version.

Final-check implications:

- Verify real-world experiments are present or the simulation gap is explicitly addressed.
- Statistical reporting: mean ± std across multiple trials, significance tests for close comparisons.
- Ablation studies for each novel component.
- **Failure case analysis** is expected — show where the method breaks and discuss why.
- Runtime analysis must be present if any efficiency claims are made.
- Figures meet IEEE quality: 300 dpi, readable in grayscale, vector graphics preferred.
- Verify `\bibliographystyle{IEEEtran}` and no `\citep`/`\citet` commands.
- Include multimedia/video reference if applicable.
- Author biographies (`\begin{IEEEbiography}`) required for camera-ready.

## ICRA (Standalone Submission)

ICRA is a top robotics conference with its own review process separate from RA-L.

Planning implications:

- **Double-blind review** for ICRA standalone papers (unlike RA-L which is NOT anonymous).
- Use `\documentclass[conference]{IEEEtran}` with `\cite{}` (numeric).
- Page limit: 6 pages of technical content + 1 page for references only. Total 7 pages maximum.
- References are on a separate (7th) page and do NOT count toward the 6-page technical limit.
- ICRA reviewers value: (1) real-robot validation, (2) clear system description, (3) fair baselines, (4) reproducibility.
- Plan a system overview figure early (architecture, pipeline, or robot setup).
- Include video supplementary — virtually expected for manipulation, locomotion, and navigation papers.

Final-check implications:

- Confirm anonymization: no author names, no lab identifiers, no self-citing "our robot" or "our lab".
- Verify technical content fits in 6 pages. References on page 7 only.
- Experiments include real-world validation or strong sim-to-real transfer analysis.
- Statistical reporting: mean ± std across trials, number of trials stated.
- **Failure case analysis** strengthens the paper significantly.
- Comparison with recent baselines (within 2 years) on recognized benchmarks.
- Verify `\bibliographystyle{IEEEtran}` and correct `[conference]` document class.

## Theory Venues (SODA, STOC, FOCS, ICALP, SPAA, PODC)

Planning implications:

- **Full proofs are mandatory**, not optional — every theorem must have a complete proof in the main paper OR a complete proof in the appendix that reviewers will read.
- Most theory venues use **single-column** layout (LNCS, LIPIcs, ACM single-column) rather than two-column.
- Correctness and tightness of bounds dominate; empirical validation is secondary or absent entirely.
- Novelty is measured in terms of **new techniques, tighter bounds, or improved dependencies** — not engineering artifacts.
- Anonymous submission for SODA/STOC/FOCS/SPAA/PODC; ICALP historically non-anonymous (check CFP).
- Artifact evaluation is optional at most theory venues (ICALP Track A accepts but does not require).

Final-check implications:

- Every `\begin{theorem}` / `\begin{lemma}` / `\begin{proposition}` has a proof (main text or appendix) with all assumptions listed.
- Parameter dependencies are uniform (e.g. "O(n)" must not secretly scale with log d or 1/ε).
- `/proof-checker` audit verdict is PASS, not BYPASSED.
- `/complexity-claim-audit` (v2.2+) verdict is PASS: every `\mathcal{O}` / `\Theta` / `\Omega` matches a proof.
- Empirical tables, if present, list all input sizes, hardware, and implementation language; they are never the load-bearing evidence.
- Title and abstract mention the improved bound explicitly (e.g. "O(n log² n) → O(n log n)").

## Programming Languages Venues (PLDI, OOPSLA, POPL, CGO, ICFP)

Planning implications:

- **Artifact evaluation is mandatory** at PLDI/OOPSLA/POPL (Reusable / Available / Functional badges). Plan from day-1 a Docker/VM image that reproduces every claim.
- Anonymized artifact repos (e.g. Zenodo with redacted metadata) during the review phase.
- Reproducibility expectations are high: exact compiler versions, OS versions, and benchmark inputs must be documented.
- Empirical claims require statistical rigor — report geomean + per-benchmark variance, not just aggregates.
- POPL weights formal (proofs, Coq/Agda/Lean mechanizations) heavily; OOPSLA balances empirical + formal; PLDI/CGO weight empirical heavily.
- Novelty bar is high — compiler optimizations or type-system extensions must be evaluated on multiple real workloads.

Final-check implications:

- Artifact repo passes Functional on a clean machine in under 30 minutes.
- Every `Table X` result is reproducible with a single `make <table-x>` command.
- Benchmark suite includes both stressors (unit tests) and real workloads (full programs).
- If sanitizers or static analysis are claimed: SANITIZER_AUDIT.json / static-analysis report included.
- For formal claims: mechanized proofs type-check (Coq `coqc`, Agda `agda`, Lean `lean`).

## Systems Venues (OSDI, SOSP, NSDI, EuroSys, ASPLOS, SC, HPCA)

Planning implications:

- **Microbenchmark vs macro-workload discipline** — single-component microbenchmarks don't settle systems claims; end-to-end workloads (e.g., YCSB, SPEC, application traces) are required.
- Hardware disclosure is mandatory: CPU/GPU model, memory bandwidth, NIC specs, storage hierarchy.
- Cluster-scale reproducibility: if the paper claims scaling to N nodes, the artifact must demonstrate at least one non-trivial cluster run.
- Baseline comparison must include the **strongest prior system** in the category — "we beat a straw-man" is rejected.
- Double-blind for most, but SOSP rolls artifact review after accept (different timeline).

Final-check implications:

- Every perf claim has a comparison with at least one prior system + a well-motivated baseline.
- Error bars or confidence intervals on all comparison figures (not just means).
- Sensitivity analysis to workload parameters (at minimum: skew, scale, concurrency).
- Complete hardware + software stack table (kernel version, driver version, compiler flags).
- If GPU-centric: CUDA version, GPU model with compute capability, memory size disclosed.

## Database Venues (VLDB, SIGMOD, ICDE, CIDR)

Planning implications:

- **TPC workloads** (TPC-H, TPC-DS, TPC-C) or recognized traces (e.g., Wikipedia, Twitter) are the standard — custom workloads need strong justification.
- Query plans, index structures, and buffer-pool state must be reproducible.
- PVLDB is **rolling-submission** with a 1-month cycle — plan for revision rounds.
- SIGMOD/ICDE are annual with specific submission deadlines; CIDR is workshop-style with emphasis on vision papers.
- Fairness: comparison baselines must use the **same data loader and same caching state** unless the contribution is explicitly about data loading.

Final-check implications:

- Queries used are listed verbatim in the appendix or linked artifact.
- Scale factor (SF) is disclosed for every TPC experiment.
- Hardware identical across baseline and method comparisons.
- If concurrency claims: transaction conflict rate, abort rate, and throughput-vs-latency curves disclosed.

## Graphics Venues (SIGGRAPH, EG, HPG, I3D)

Planning implications:

- **Visual-quality metrics** are first-class: PSNR, SSIM, LPIPS, FLIP for rendering papers; FID, inception score, user study for generative.
- Supplementary **video** is near-mandatory for dynamic content (animation, rendering, simulation).
- Rendering-performance plots: FPS vs scene complexity, memory consumption, convergence speed (for Monte Carlo).
- SIGGRAPH (Journal track) is rolling-submission via ACM TOG; EG is annual; HPG focuses on high-performance.
- Failure cases and visual comparisons on challenging scenes strengthen the paper.

Final-check implications:

- Supplementary video linked from paper (anonymous hosting for double-blind venues).
- Visual-quality table has at least 3 perceptual metrics + 1 structural metric.
- Hardware GPU model and driver version disclosed.
- For real-time claims: min FPS (not just mean) and frame-time distribution reported.

## HPC Venues (SC, PPoPP, IPDPS)

Planning implications:

- **Strong and weak scaling plots** are expected — missing either raises red flags.
- I/O discipline: for storage-intensive claims, disclose PFS (Lustre / GPFS), striping config, aggregate I/O bandwidth.
- GPU/CPU architecture: full disclosure (e.g., "NVIDIA A100 80GB, compute 8.0, CUDA 12.4, driver 550.x").
- Reproducibility appendix (SC has explicit reproducibility initiative — SC-RI).
- Artifact evaluation increasingly common, track-dependent.

Final-check implications:

- Strong-scaling plot up to at least 4× the smallest scale, weak-scaling with efficiency > 70% marked.
- Roofline model placement (where possible) for kernel-level claims.
- GPU occupancy / warp efficiency reported if CUDA/HIP claims are made (`/cuda-profile` produces this).
- Communication-computation ratio disclosed for parallel algorithms.

## Robotics Venues (ICRA, IROS, RSS, RA-L, T-RO, HRI, CoRL)

Planning implications (general — see IEEE RA-L / IEEE TRO / ICRA sections above for per-venue format details):

- **Hardware-platform disclosure** is mandatory: robot model, sensors (LiDAR, cameras, IMU with specs), controller spec, actuators.
- **Sim-to-real gap** reporting is expected when sim is used — quantify the gap on real-world trials, not just claim transferability.
- **Rosbag artifacts + launch files** strengthen reproducibility. For ROS2-based work, include `colcon.meta` + `package.xml` in the artifact.
- Real-time deadline discipline: if the paper claims 100 Hz control, benchmarks must show p99 latency < 10 ms (not just mean).
- Failure-mode video supplementary: reviewers expect to see not just success but edge-case behavior.
- RSS: annual single-track, higher selectivity; CoRL: learning-focused subset of robotics; HRI: human-subject studies (IRB disclosure).

Final-check implications:

- Robot name + sensor suite + compute platform (onboard vs offboard) listed in a setup table.
- If ROS2 used: distro (Humble / Iron / Jazzy), QoS profiles on critical topics, TF tree root node specified.
- `/ros2-realtime-audit` (v2.2+) verdict is PASS on any real-time claim.
- `/ros2-launch-test` (v2.2+) verdict is PASS — node discovery, QoS match, TF completeness validated.
- For sim-to-real: both sim-only and real numbers in the results table, with the transfer gap explicit.
- Video supplementary referenced in the paper body with a deterministic timestamp / URL.

## GPU / Accelerator Venues (overlap with HPC + Systems, amplifies specific checks)

When the paper's primary contribution is a GPU kernel or accelerator-specific system (typical for CUDA research):

Planning implications:

- Disclose CUDA version (runtime + driver), GPU model + compute capability, and any GPU-specific optimizations (tensor cores, asynchronous copies, cooperative groups).
- Kernel-level metrics: occupancy, warp execution efficiency, memory throughput, DRAM/HBM utilization, L2 hit rate.
- Profiling tool disclosure: Nsight Compute / Nsight Systems / nvprof — specify version.

Final-check implications:

- `/cuda-profile` report (Nsight Compute JSON) included in artifact — not just summary plots.
- `/cuda-sanitizer` audit clean (no racecheck / memcheck / initcheck violations) on benchmark runs.
- `/cuda-correctness-audit` clean (numerical equivalence vs CPU reference within ulp tolerance).
- For tensor-core claims: show both dense and sparse-pattern benchmarks; flag FP16/BF16/INT8 precision used.
- Binary size / register pressure / shared-memory usage reported (from `ptxas -v` or Nsight Compute).

## Minimal Submission Checklist

Before submission, verify:

- the venue-specific required sections are present,
- the page budget is satisfied for the main body,
- the contribution bullets do not overclaim,
- citations, figures, tables, and references are internally consistent,
- the PDF is anonymized and ready for reviewer consumption.
