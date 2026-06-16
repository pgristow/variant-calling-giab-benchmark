# Data & tool licences / attribution

## Sequencing sample — HG002 / NA24385 (Genome in a Bottle)
- Source: NIST Genome in a Bottle (GIAB), Ashkenazi trio son.
- Consent: HG002 is a **Personal Genome Project (PGP)** participant, openly consented for
  unrestricted public use **including commercial redistribution**. This is why HG002 (not the
  HapMap sample NA12878, which lacks commercial-redistribution consent) is used here.
- The small chr20 read subset committed in `data/` is derived from the public GIAB
  `HG002.GRCh38.300x.bam` (see `scripts/prepare_test_data.sh` for exact provenance).
- Please cite: Zook et al., *Sci Data* (2016); GIAB/NIST.

## Truth set — GIAB v4.2.1 small-variant benchmark (GRCh38)
- Source: NIST GIAB release `NISTv4.2.1`. Public, citation-requested.
- Files in `data/` are the region-restricted truth VCF and high-confidence BED.

## Reference genome — GRCh38 (chr20)
- Source: UCSC hg38 `chr20.fa.gz`. GRCh38 assembly is open for any use.

## Tools
| Tool | Licence | Commercial use |
|------|---------|----------------|
| GATK4 | BSD-3-Clause | ✅ |
| bcftools / samtools / htslib | MIT/Expat | ✅ |
| bwa-mem2 | MIT | ✅ |
| RTG Tools (vcfeval) | BSD-2-Clause (released by Real Time Genomics) | ✅ |
| bedtools | MIT | ✅ |
| igv-reports | MIT | ✅ |

All tools permit commercial use. This repository's own code is MIT-licensed (see `LICENSE`).
