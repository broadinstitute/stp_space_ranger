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

RUN curl -o spaceranger-4.0.1.tar.gz "https://cf.10xgenomics.com/releases/spatial-exp/spaceranger-4.0.1.tar.gz?Expires=1750126894&Key-Pair-Id=APKAI7S6A5RYOXBWRPDA&Signature=g94ZC60nRB5N0b6mMeK5RzpjXWVW1BLRCWYS33hvZWU3Wxsd56kB1MoS1QSUrilJdvCMYVLc7ZcsA3UNi47O86cmI9263Pj-pHA54NiGbmxqE9C~PnxpCHTTe7N7pjskInODAKp5eF9ztO6-WK4vHZrjT2rg1u-0NozlZLFv4OqZ25IJkp7p3oq3boxqb6rhcxlu48SK93arQSOwtnCtB62U45Ae8eiPK1pdfQEEdkksFUdavx6B7tbxISlYAcCsi~HoqMIj-llWfaNnB7ugB6NEdzsM-xMPa-GrDZoZQy-0-P3lrKmLM2EEM4dPSrLHmNoBGwsgzb-P5f7F0m-NCA__" && \
    tar -zxvf spaceranger-4.0.1.tar.gz && \
    rm spaceranger-4.0.1.tar.gz

ENV PATH="/spaceranger-4.0.1/:${PATH}"

RUN spaceranger --help

ENTRYPOINT ["/bin/bash", "-l", "-c", "/bin/bash"]