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

## Minimal Submission Checklist

Before submission, verify:

- the venue-specific required sections are present,
- the page budget is satisfied for the main body,
- the contribution bullets do not overclaim,
- citations, figures, tables, and references are internally consistent,
- the PDF is anonymized and ready for reviewer consumption.
