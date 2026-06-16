# Germline variant calling — and *proof* it's correct

[![Reproduce](https://github.com/pgristow/variant-calling-giab-benchmark/actions/workflows/publish.yml/badge.svg)](https://github.com/pgristow/variant-calling-giab-benchmark/actions/workflows/publish.yml)
[![Live report](https://img.shields.io/badge/live%20report-GitHub%20Pages-2e7d32)](https://pgristow.github.io/variant-calling-giab-benchmark/)
[![Benchmarked vs GIAB](https://img.shields.io/badge/benchmarked-GIAB%20v4.2.1-8e44ad)](https://www.nist.gov/programs-projects/genome-bottle)

> **Roche Principal Scientist (NGS) & PhD — I turn sequencing data into clean, reproducible answers.**

Anyone can produce a VCF. This repo answers the question a client actually has — **can I trust these
calls?** — by calling germline variants two ways (bcftools and GATK) on the Genome-in-a-Bottle
sample **HG002** and **benchmarking both against the GIAB gold-standard truth set**: precision,
recall and F1, for SNPs and indels separately. *Most freelancers never benchmark at all.*

### 👉 [**See the live report**](https://pgristow.github.io/variant-calling-giab-benchmark/) — including the accuracy scoreboard
### 📄 [**Sample one-page deliverable (PDF)**](https://pgristow.github.io/variant-calling-giab-benchmark/deliverable.pdf) — what lands in your inbox

---

## The question
*Can these variant calls be trusted?* — answered with hard numbers against a known truth.

## The data
**HG002 / NA24385**, the Genome-in-a-Bottle Ashkenazi son — the community benchmarking standard,
**openly redistributable (PGP consent)** with an authoritative v4.2.1 truth set. A 1 Mb chr20 region
at ~30× keeps the whole pipeline running in minutes. The small read subset + region truth set are
committed (provenance in [`scripts/prepare_test_data.sh`](scripts/prepare_test_data.sh)); only the
chr20 reference is downloaded at run time.

## Key decisions (and why)
- **HG002, not NA12878** — NA12878 (HapMap) lacks commercial-redistribution consent; HG002 is the
  correct, defensible choice for a commercial portfolio (see [`assets/LICENCES.md`](assets/LICENCES.md)).
- **Two callers, one truth set** — bcftools *and* GATK, scored identically, so the choice is
  evidence-based, not dogma.
- **`rtg vcfeval`** — haplotype-aware comparison (the GA4GH-recommended engine), with SNPs and
  indels reported **separately** because indels are harder and a single number hides that.

## The result
A **benchmark scoreboard** (precision / recall / F1 per caller per variant type vs GIAB truth) — the
flagship figure — plus a precision–recall comparison, caller concordance, and an honest
interpretation of where and why accuracy degrades.

## What you get if you hire me for this
| Deliverable | Included |
|---|---|
| Aligned, deduplicated BAM | ✅ |
| Variant calls (bcftools **and** GATK), normalised | ✅ |
| **Accuracy benchmark vs truth set** (precision/recall/F1) | ✅ |
| SNP / indel stratified metrics | ✅ |
| Caller comparison + concordance | ✅ |
| Reproducible report (code folded) + interpretation | ✅ |

## Reproduce it
```bash
git clone https://github.com/pgristow/variant-calling-giab-benchmark
cd variant-calling-giab-benchmark
conda env create -f environment.yml && conda activate variant-call
make all     # align → call (bcftools + GATK) → benchmark vs GIAB → render
```
Or with Docker: `docker build -t variantcall . && docker run --rm -v "$PWD":/work variantcall`.

## Note on scope
A **reproducible demonstration on public data**. Production engagements use a private, hardened
pipeline (BQSR, joint genotyping, region-stratified benchmarking, clinical-grade filtering) on
**your** data under NDA. The demo sells the *service*; the engine stays private.

## Licence & attribution
Code: MIT (see `LICENSE`). Data & tools: see [`assets/LICENCES.md`](assets/LICENCES.md) (all permit
commercial use). Benchmarking against [GIAB](https://www.nist.gov/programs-projects/genome-bottle)
v4.2.1 with [RTG Tools](https://github.com/RealTimeGenomics/rtg-tools) `vcfeval`.
