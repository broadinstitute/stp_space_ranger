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

RUN curl -O https://storage.googleapis.com/pub/gsutil.tar.gz && \
tar -xzf gsutil.tar.gz -C /usr/local && \
rm gsutil.tar.gz

ENV PATH="/usr/local/gsutil:$PATH"

RUN gsutil version

RUN curl -o spaceranger-3.1.1.tar.gz "https://cf.10xgenomics.com/releases/spatial-exp/spaceranger-3.1.1.tar.gz?Expires=1730539568&Key-Pair-Id=APKAI7S6A5RYOXBWRPDA&Signature=Hjs4oehw6hzhqXrjymuWjBmyiq7YizZj-TUPh96lHA2RQn62k3kHEQuLPYVeZ40R6F77lCMddXoKKJ7~cAuO1JLiKYPTwuMB2BTSjSgvG2I3NV8~gXseFUahaG~Nz2IJfqMmeJrds82Mk7pnykUk2wYI2N5FJ36ALq7s9WV9B2TzOiRGoLQijGRvuLyJ4A~I6NMH1miJsPfrfkrXbDVqUePWutpR8TEw-VGHj8LrZNuFJDggh~qr~I8s2JIdTLvDgvfxiSa7~CEGz4k~81mYPD65CpYTYbvG-YM67XOWJyDZDQZOhStASLWYHxy9b6PPZccY1peisG9MmAVmxkO0wA__"
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
