FROM python:3.10

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    tar \
    bzip2 \
    libssl-dev \
    libgl1-mesa-glx \
    libcurl4-openssl-dev \
    zlib1g-dev \
    xz-utils \
    apt-transport-https \
    ca-certificates \
    gnupg \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -

RUN apt-get update && \
    apt-get install -y google-cloud-sdk && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN gcloud --version && \
    gcloud info && \
    gcloud config list

RUN curl -o spaceranger-3.1.1.tar.gz "https://cf.10xgenomics.com/releases/spatial-exp/spaceranger-3.1.1.tar.gz?Expires=1731124249&Key-Pair-Id=APKAI7S6A5RYOXBWRPDA&Signature=LgOfBdPz5ZMiaabgULkJOMKmr9o1jSJZC5ieHWdZQo3jbpDVi4IZDdgtkt5BbxRAV9ANaipHxVVeRdBreXR1qRsIBnoM8MxFqhtcEDuKPef7mqV4VlkIuUNjhDPfZfYdeBkIaF3liznWUK1ak3bQyw-s9bxUYWsQxfK5VCJ602beUulMA0JntUF6u-aQyzgZNSiP2D0xWQM8EMkP-v7MHv91Bc9EtPgPRhiZ4O5ewu-Xo~Zpe-BvFWOznJIeH4de4bvNp1YC9T0mGb-l302zxYyDCvaDbXRZZWwvCtU8NQKdydDikDwWrUlAL9eCka4QU5TkCILUd0iM4dwQb2fzbw__" && \
    tar -zxvf spaceranger-3.1.1.tar.gz && \
    rm spaceranger-3.1.1.tar.gz

ENV PATH="/spaceranger-3.1.1/:${PATH}"

RUN spaceranger --help

ENTRYPOINT ["/bin/bash", "-l", "-c", "/bin/bash"]