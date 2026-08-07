FROM python:3.10

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    tar \
    bzip2 \
    libssl-dev \
    libgl1 \
    libcurl4-openssl-dev \
    zlib1g-dev \
    xz-utils \
    apt-transport-https \
    ca-certificates \
    gnupg \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg

RUN apt-get update && \
    apt-get install -y google-cloud-sdk || (sleep 30 && apt-get install -y google-cloud-sdk) && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN gcloud --version && \
    gcloud info && \
    gcloud config list

RUN curl -o spaceranger-4.1.0.tar.gz "https://cf.10xgenomics.com/releases/spatial-exp/spaceranger-4.1.0.tar.gz?Expires=1786157446&Key-Pair-Id=APKAI7S6A5RYOXBWRPDA&Signature=KAnz0mT25267u9mj6wVB2ByMn1WoaS3jN-PEhGp4qqOih6XGCmsamsqia5AgqTpO2u1ZPo2HX6H19mLw-k~JSvok45FWlj2Sc9xt-5LfLMT0r2pm7~w1B78in6wamtiOGBnBN6YJ6cuRvARNTBpHIO-2ddrKfU-dHGWiWuUuTkPLZGi7nETozO8BuXjDoaNdZlvcQrXBT3NA8L1s3k~08OaWtRbjTH-~KpS7wE5ItXHsAW8drIQ1-y04pm-PAHdrGGhF5OejbZUD1zZXYzpTZnDYOwNPfttsGFxCsvbfgL1KCAsodtG6uv-rnGPI6LLSp-1iqoZxZuMFKjFtxnD3uw__" && \
    tar -zxvf spaceranger-4.1.0.tar.gz && \
    rm spaceranger-4.1.0.tar.gz

ENV PATH="/spaceranger-4.1.0/:${PATH}"

RUN spaceranger --help

ENTRYPOINT ["/bin/bash", "-l", "-c", "/bin/bash"]