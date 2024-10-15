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

RUN curl -o spaceranger-3.1.1.tar.gz "https://cf.10xgenomics.com/releases/spatial-exp/spaceranger-3.1.1.tar.gz?Expires=1727507164&Key-Pair-Id=APKAI7S6A5RYOXBWRPDA&Signature=Jh2IA~hMlpPleI0nJA-OdMnihmUvPfOSwaTmLkuvClmKUgG0C97k3GMnI47ORDRj~p6HKYwNL6P0vTYnydMctlFMbr7a5DI1ZbhkfLasA7QcNXAoen7IQatm6QKtLPyvruP3JCe2lBInjeDniHOAZmSn8bsJw8yUWCTOMMGiTQy1B0ctQpnEEOEZ6003xj4aMTVBtAup3nUJ-9RNRzan6jTdAYhhAr7DtYtez8GgxzrQJ4bltNwXn8G7hOKCHytG-bvbSdLI8y4pyC8SHGumtab7hdLEZXg2QuYOWee1FdoyZ9WJdLPLF-6~oLgs5SHh2HS6sSz5vNKNy6oFYoZCFg__"
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
