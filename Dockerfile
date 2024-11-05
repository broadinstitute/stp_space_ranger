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
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN curl -o spaceranger-3.1.1.tar.gz "https://cf.10xgenomics.com/releases/spatial-exp/spaceranger-3.1.1.tar.gz?Expires=1729669245&Key-Pair-Id=APKAI7S6A5RYOXBWRPDA&Signature=cbPPlaDwRCWYtJAmVNgqIf8Uq70PgSr7ndSi-3ATe~fbRZ766IFSjOaaCejEQOWyODDgiReR5sozhEeG1fwAUUkPdsyb-9W8Gzds2TPUR5QpcB86IAEjGuiZsV26gPPpTQSVLmbGsfNpbeCtUq0m5pQIkMQuTdpLomj1ZFTz5s5wnxjdDufP9ZT10TIJqU8SjuaGmi79nzh8AKVuCdJZXsth3xY11PAa6FXPh3VTlwAC8eBVLxicWnk87MbCh43W-e-HgXjriZ0ek4rG8X5nkoelUfsbAE8RJhuJy6JCxCNnIumI6cdpgdOMtw5pml70hk83wQhvUvhIbhTeyjXVSQ__"
RUN tar -zxvf spaceranger-3.1.1.tar.gz

ENV PATH="/spaceranger-3.1.1/:${PATH}"

RUN spaceranger --help

RUN pip install --upgrade pip
RUN pip install --verbose \
    cellpose==3.0.9 \
    scikit-image==0.23.2 \
    opencv-python==4.10.0.82 \
    matplotlib==3.9.0 \
    numpy==1.26.4

ENTRYPOINT ["/bin/bash", "-l", "-c", "/bin/bash"]