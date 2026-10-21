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

RUN curl -o spaceranger-4.1.0.tar.gz "https://cf.10xgenomics.com/releases/spatial-exp/spaceranger-4.1.0.tar.gz?Expires=1792635409&Key-Pair-Id=APKAI7S6A5RYOXBWRPDA&Signature=emYRQcN5bUCkc1hTJz4Rkbxj7aMuCYRcUixViOjrqjj6shIoZBnBm4ZhGJia6ACGmXzIlgaQKVQ5HfScUdFyXewt~cPvQBZ8xXLpZ1moQZ85OJX8aK4gBYyOWk1G7xD52HCpQgpyP~sxEdOQ7b14HTtJ2-~jilFKPWN43bpVZ99K056HUlncI6rDX030E2dVN5mOUGiTa6v0CCKbU8UJ5OpDlkivOjc0loVDulMLxg2vhdeggPtMmW5EPzzj-sla4WkEwUkCplykVKpOYjOgLGyMB22v0TOZmsNNtcXzRLlkiifQ~wxA1jBWPFLkPbUH-Gfr2xOhGGjAb3ZoF9iQew__" && \
    tar -zxvf spaceranger-4.1.0.tar.gz && \
    rm spaceranger-4.1.0.tar.gz

ENV PATH="/spaceranger-4.1.0/:${PATH}"

RUN spaceranger --help

ENTRYPOINT ["/bin/bash", "-l", "-c", "/bin/bash"]