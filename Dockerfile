# Reproducible variant-calling environment. Build: docker build -t variantcall .
# Run:   docker run --rm -v "$PWD":/work variantcall make all
FROM condaforge/miniforge3:latest

WORKDIR /work
COPY environment.yml /tmp/environment.yml
RUN mamba env update -n base -f /tmp/environment.yml && mamba clean -afy

ENV XDG_CACHE_HOME=/tmp/.cache HOME=/tmp

COPY . /work
CMD ["make", "all"]
