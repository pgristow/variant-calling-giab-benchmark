#!/usr/bin/env bash
# Germline variant-calling pipeline + GIAB benchmark.
#
#   committed FASTQs --> bwa-mem2 --> sort + markdup --> {bcftools, GATK} calls
#                    --> rtg vcfeval vs GIAB v4.2.1 truth --> precision/recall/F1
#
# Reference (chr20) is downloaded here (not committed); everything else runs from the
# small committed HG002 inputs in data/. Writes metrics to results/benchmark_metrics.csv.
set -euo pipefail

REGION_TAG="${REGION_TAG:-chr20_2-3Mb}"
REGION="${REGION:-chr20:2000000-3000000}"
THREADS="${THREADS:-8}"
DATA_DIR="${DATA_DIR:-data}"
REF_DIR="${REF_DIR:-reference}"
WORK="${WORK:-work}"
RES="${RES:-results}"
mkdir -p "$REF_DIR" "$WORK" "$RES"

R1="${DATA_DIR}/HG002.${REGION_TAG}.R1.fastq.gz"
R2="${DATA_DIR}/HG002.${REGION_TAG}.R2.fastq.gz"
TRUTH="${DATA_DIR}/truth.${REGION_TAG}.vcf.gz"
CONF="${DATA_DIR}/confident.${REGION_TAG}.bed"
REF="${REF_DIR}/chr20.fa"

# ---- 0. Reference (chr20 only; UCSC hg38 naming matches GIAB GRCh38) ----
if [ ! -f "$REF" ]; then
  echo "[ref] Downloading chr20..."
  curl -fsSL https://hgdownload.soe.ucsc.edu/goldenPath/hg38/chromosomes/chr20.fa.gz \
    | gunzip > "$REF"
fi
[ -f "${REF}.fai" ] || samtools faidx "$REF"
[ -f "${REF_DIR}/chr20.dict" ] || gatk CreateSequenceDictionary -R "$REF" -O "${REF_DIR}/chr20.dict" 2>/dev/null
[ -d "${REF_DIR}/chr20.sdf" ] || rtg format -o "${REF_DIR}/chr20.sdf" "$REF"
[ -f "${REF}.bwt.2bit.64" ] || bwa-mem2 index "$REF"

# ---- 1. Align, sort, mark duplicates (fixmate -> coord sort -> markdup) ----
RG='@RG\tID:HG002\tSM:HG002\tPL:ILLUMINA\tLB:lib1'
echo "[align] bwa-mem2..."
bwa-mem2 mem -t "$THREADS" -R "$RG" "$REF" "$R1" "$R2" 2>/dev/null \
  | samtools sort -n -@ "$THREADS" -o "${WORK}/aln.namesort.bam" -
samtools fixmate -m -@ "$THREADS" "${WORK}/aln.namesort.bam" "${WORK}/aln.fixmate.bam"
samtools sort -@ "$THREADS" -o "${WORK}/aln.sorted.bam" "${WORK}/aln.fixmate.bam"
samtools markdup -@ "$THREADS" "${WORK}/aln.sorted.bam" "${WORK}/aln.markdup.bam"
samtools index "${WORK}/aln.markdup.bam"
rm -f "${WORK}/aln.namesort.bam" "${WORK}/aln.fixmate.bam"

# ---- 2a. bcftools calls ----
echo "[call] bcftools..."
bcftools mpileup -f "$REF" -r "$REGION" "${WORK}/aln.markdup.bam" -Ou 2>/dev/null \
  | bcftools call -mv -Oz -o "${WORK}/bcftools.raw.vcf.gz"
bcftools norm -f "$REF" -m -any "${WORK}/bcftools.raw.vcf.gz" -Oz -o "${WORK}/bcftools.vcf.gz" 2>/dev/null
tabix -f -p vcf "${WORK}/bcftools.vcf.gz"

# ---- 2b. GATK HaplotypeCaller ----
echo "[call] GATK HaplotypeCaller..."
gatk --java-options "-Xmx6g" HaplotypeCaller -R "$REF" -I "${WORK}/aln.markdup.bam" \
  -L "$REGION" -O "${WORK}/gatk.raw.vcf.gz" 2>/dev/null
bcftools norm -f "$REF" -m -any "${WORK}/gatk.raw.vcf.gz" -Oz -o "${WORK}/gatk.vcf.gz" 2>/dev/null
tabix -f -p vcf "${WORK}/gatk.vcf.gz"

# ---- 3. Benchmark each caller vs GIAB truth, split by variant type ----
echo "caller,var_type,precision,recall,f1,tp,fp,fn" > "${RES}/benchmark_metrics.csv"

bench () {                       # bench <caller> <calls.vcf.gz>
  local caller="$1" calls="$2" vtype label out line tp fp fn prec sens fmeas
  for vtype in snps indels; do
    label="SNP"; [ "$vtype" = "indels" ] && label="INDEL"
    bcftools view -v "$vtype" "$calls" -Oz -o "${WORK}/${caller}.${vtype}.vcf.gz" 2>/dev/null
    tabix -fp vcf "${WORK}/${caller}.${vtype}.vcf.gz"
    bcftools view -v "$vtype" "$TRUTH" -Oz -o "${WORK}/truth.${vtype}.vcf.gz" 2>/dev/null
    tabix -fp vcf "${WORK}/truth.${vtype}.vcf.gz"
    out="${WORK}/eval_${caller}_${vtype}"; rm -rf "$out"
    rtg vcfeval -b "${WORK}/truth.${vtype}.vcf.gz" -c "${WORK}/${caller}.${vtype}.vcf.gz" \
      -e "$CONF" -t "${REF_DIR}/chr20.sdf" -o "$out" >/dev/null 2>&1 || true
    # summary.txt data row is indented and labelled "None"; cols: thr tp_base tp_call fp fn prec sens fmeas
    if [ -f "${out}/summary.txt" ]; then
      line=$(awk '$1=="None"{print; exit}' "${out}/summary.txt")
      tp=$(echo "$line" | awk '{print $2}'); fp=$(echo "$line" | awk '{print $4}')
      fn=$(echo "$line" | awk '{print $5}'); prec=$(echo "$line" | awk '{print $6}')
      sens=$(echo "$line" | awk '{print $7}'); fmeas=$(echo "$line" | awk '{print $8}')
    else
      tp=NA; fp=NA; fn=NA; prec=NA; sens=NA; fmeas=NA
    fi
    echo "${caller},${label},${prec},${sens},${fmeas},${tp},${fp},${fn}" >> "${RES}/benchmark_metrics.csv"
  done
}

bench bcftools "${WORK}/bcftools.vcf.gz"
bench gatk     "${WORK}/gatk.vcf.gz"

# ---- 4. Concordance: variants called by each / both (for the UpSet-style breakdown) ----
bcftools isec -p "${WORK}/isec" "${WORK}/bcftools.vcf.gz" "${WORK}/gatk.vcf.gz" >/dev/null 2>&1 || true
{
  echo "set,n"
  echo "bcftools_only,$(grep -vc '^#' ${WORK}/isec/0000.vcf 2>/dev/null || echo 0)"
  echo "gatk_only,$(grep -vc '^#' ${WORK}/isec/0001.vcf 2>/dev/null || echo 0)"
  echo "shared,$(grep -vc '^#' ${WORK}/isec/0002.vcf 2>/dev/null || echo 0)"
} > "${RES}/caller_concordance.csv"

# Keep a copy of the GATK calls as the delivered VCF for the IGV view.
cp "${WORK}/gatk.vcf.gz" "${RES}/HG002.${REGION_TAG}.gatk.vcf.gz"
cp "${WORK}/aln.markdup.bam" "${RES}/HG002.${REGION_TAG}.bam" 2>/dev/null || true
samtools index "${RES}/HG002.${REGION_TAG}.bam" 2>/dev/null || true

echo "[done] Metrics:"; cat "${RES}/benchmark_metrics.csv"
