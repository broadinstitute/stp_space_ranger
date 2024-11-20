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

RUN curl -o spaceranger-3.1.2.tar.gz "https://cf.10xgenomics.com/releases/spatial-exp/spaceranger-3.1.2.tar.gz?Expires=1732075508&Key-Pair-Id=APKAI7S6A5RYOXBWRPDA&Signature=fKe88PwTIgXvgoDlLqDtdyrgKUNM1d43uqWLWFbVOHS9ffWg1-HgBkrYtBejT3TfU8H571rJFFApLoBv7k7-Mmcb0AB17adofe-UT-y5ZPn5wwpHUV8nLh2SuHDo-Hnd~qamBWxAs1xsxETUkV72Ajck1DFMfra1HE2QA6yfBMLDrSfpW9xSCeP45jXfSnNbbSnoCM3yerVflqPf3FrjmocRQglUn~jJaumAVWm0z3LL8MVFpxhSgel8W~lbLtpmIilv620Yza5avDLdnDii9EnmmSQ9F~z~KJeelIjTXBeSlv2yZa7yGXn4ANR-4waiqUzEej758zcyecAwWog21g__" && \
    tar -zxvf spaceranger-3.1.2.tar.gz && \
    rm spaceranger-3.1.2.tar.gz

ENV PATH="/spaceranger-3.1.2/:${PATH}"

RUN spaceranger --help

ENTRYPOINT ["/bin/bash", "-l", "-c", "/bin/bash"]