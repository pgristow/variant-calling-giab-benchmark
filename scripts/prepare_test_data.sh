#!/usr/bin/env bash
# PROVENANCE: how the small committed HG002 test inputs were created.
#
# Streams a 1 Mb chr20 region of the public, PGP-consented GIAB HG002 (NA24385)
# 300x Illumina BAM, downsamples to ~30x, and emits paired FASTQs + a
# region-restricted GIAB v4.2.1 truth VCF and high-confidence BED.
#
# HG002 is openly redistributable (PGP consent), so the small outputs are committed
# to the repo and the analysis itself needs NO large downloads. Re-run to regenerate.
#
# Requires: samtools, bcftools, bedtools, tabix (the `variant-call` conda env).
set -euo pipefail

REGION="${REGION:-chr20:2000000-3000000}"   # 1 Mb, variant-dense
REGION_TAG="${REGION_TAG:-chr20_2-3Mb}"
TARGET_COV="${TARGET_COV:-30}"
SRC_COV="${SRC_COV:-300}"
DATA_DIR="${DATA_DIR:-data}"
THREADS="${THREADS:-8}"

BAM_URL="https://ftp-trace.ncbi.nlm.nih.gov/giab/ftp/data/AshkenazimTrio/HG002_NA24385_son/NIST_HiSeq_HG002_Homogeneity-10953946/NHGRI_Illumina300X_AJtrio_novoalign_bams/HG002.GRCh38.300x.bam"
GIAB="https://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/giab/release/AshkenazimTrio/HG002_NA24385_son/NISTv4.2.1/GRCh38"
TRUTH_VCF_URL="${GIAB}/HG002_GRCh38_1_22_v4.2.1_benchmark.vcf.gz"
TRUTH_BED_URL="${GIAB}/HG002_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed"

mkdir -p "$DATA_DIR"

# 1. Stream region, subsample to ~target coverage, emit name-sorted paired FASTQs.
frac=$(awk "BEGIN{printf \"%.4f\", ${TARGET_COV}/${SRC_COV}}")
echo "[prep] Streaming ${REGION} and downsampling to ~${TARGET_COV}x (fraction ${frac})..."
samtools view -b -s "${frac}" "${BAM_URL}" "${REGION}" \
  | samtools sort -n -@ "${THREADS}" -o "${DATA_DIR}/_namesort.bam" -
samtools fastq -@ "${THREADS}" \
  -1 "${DATA_DIR}/HG002.${REGION_TAG}.R1.fastq.gz" \
  -2 "${DATA_DIR}/HG002.${REGION_TAG}.R2.fastq.gz" \
  -0 /dev/null -s /dev/null -n "${DATA_DIR}/_namesort.bam"
rm -f "${DATA_DIR}/_namesort.bam"

# 2. Region-restricted GIAB truth set (streamed via remote tabix index).
echo "[prep] Subsetting GIAB v4.2.1 truth to ${REGION}..."
bcftools view -r "${REGION}" "${TRUTH_VCF_URL}" -Oz -o "${DATA_DIR}/truth.${REGION_TAG}.vcf.gz"
tabix -p vcf "${DATA_DIR}/truth.${REGION_TAG}.vcf.gz"

RCHR="${REGION%%:*}"; RSTART="${REGION#*:}"; RSTART="${RSTART%%-*}"; REND="${REGION##*-}"
curl -fsSL "${TRUTH_BED_URL}" -o "${DATA_DIR}/_truth.bed"
printf "%s\t%s\t%s\n" "${RCHR}" "${RSTART}" "${REND}" > "${DATA_DIR}/_region.bed"
bedtools intersect -a "${DATA_DIR}/_truth.bed" -b "${DATA_DIR}/_region.bed" \
  > "${DATA_DIR}/confident.${REGION_TAG}.bed"
rm -f "${DATA_DIR}/_truth.bed" "${DATA_DIR}/_region.bed"

echo "[prep] Done. Committed inputs:"
ls -lh "${DATA_DIR}"
echo "[prep] Truth variants in region:"
bcftools view -H "${DATA_DIR}/truth.${REGION_TAG}.vcf.gz" | wc -l
