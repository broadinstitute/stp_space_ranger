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
    apt-get install -y google-cloud-sdk || (sleep 30 && apt-get install -y google-cloud-sdk) && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN gcloud --version && \
    gcloud info && \
    gcloud config list

RUN curl -o spaceranger-4.1.0.tar.gz "https://cf.10xgenomics.com/releases/spatial-exp/spaceranger-4.1.0.tar.gz?Expires=1784947156&Key-Pair-Id=APKAI7S6A5RYOXBWRPDA&Signature=LWG1KVk5Mg~Xc0LYxwSI8H3Us8uMSGXQg~wrO7Lo3CeEo4Uph8VbDxmYyU8cXasiajgysVy9WBop1HOwRXgrBZ27LmHbNUjDMbJtxrHX5WMIvMQL85XRvQJMAGRn6U9ZHs8p~JDU0UkGI6qfwr1K14gdfJ5CSuXcBOkotVkMePi-uBFdrIU4lnWsBvwJo1TZ18amUjIDySShbzqQesyhrrdBbSPHitF1b4mjSYYRc2mxm4Uvdq7u75xH2bmblh4ON-u6dICw8b2f4pX-Dr0Fy7ksCuMusvfar4~9MTefcNkKR0BmlEYBWjbxiMUYta-nsZUtoGaPTae3y9CGa0kJhA__" && \
    tar -zxvf spaceranger-4.1.0.tar.gz && \
    rm spaceranger-4.1.0.tar.gz

ENV PATH="/spaceranger-4.0.1/:${PATH}"

RUN spaceranger --help

ENTRYPOINT ["/bin/bash", "-l", "-c", "/bin/bash"]