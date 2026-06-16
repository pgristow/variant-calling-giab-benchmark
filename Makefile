.PHONY: all pipeline report data clean

# `make all` runs the calling + benchmarking pipeline then renders the report.
all: report

# Regenerate the small committed inputs from the public GIAB HG002 BAM (rarely needed).
data:
	bash scripts/prepare_test_data.sh

pipeline:
	bash scripts/run_pipeline.sh

report: pipeline
	quarto render

clean:
	rm -rf work reference docs .quarto _freeze results/*.bam results/*.bai results/*.vcf.gz*
