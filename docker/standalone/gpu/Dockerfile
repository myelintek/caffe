FROM nvidia/cuda:9.0-cudnn7-devel-ubuntu16.04
MAINTAINER simon.s.chuang@gmail.com

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        cython \
        doxygen \
        easydict \
        g++ \
        git \
        wget \
        libatlas-base-dev \
        libboost-all-dev \
        libgflags-dev \
        libgoogle-glog-dev \
        libhdf5-serial-dev \
        libleveldb-dev \
        liblmdb-dev \
        libopencv-dev \
        libsnappy-dev \
        libtool \
        make \
        python-dev \
        python-opencv \
        python-pip \
        python-scipy \
        unzip \
        vim && \
    rm -rf /var/lib/apt/lists/*

ENV CAFFE_ROOT=/opt/caffe
WORKDIR $CAFFE_ROOT

# FIXME: clone a specific git tag and use ARG instead of ENV once DockerHub supports this.
ARG CAFFE_VERSION=v0.16.4
ENV CAFFE_VERSION=${CAFFE_VERSION}

ENV NCCL_DEBUG=VERSION

RUN wget -O /opt/libnccl2.deb https://www.dropbox.com/s/n1vx60mqj8hi2ij/libnccl2.deb?dl=0 && \
    wget -O /opt/libnccl-dev.deb https://www.dropbox.com/s/lkh26o02vq6802y/libnccl-dev.deb?dl=0 && \
    dpkg -i /opt/libnccl2.deb && \
    dpkg -i /opt/libnccl-dev.deb

RUN wget -O /opt/protobuf-python-3.2.0.tar.gz https://github.com/google/protobuf/releases/download/v3.2.0/protobuf-python-3.2.0.tar.gz && \
    tar -zxvf /opt/protobuf-python-3.2.0.tar.gz -C /opt/ && \
    cd /opt/protobuf-3.2.0 && \
    ./configure && \
    make -j"$(nproc)" && \
    make check && \
    make install && \
    ldconfig

RUN git clone -b ${CAFFE_VERSION} --depth 1 https://github.com/myelintek/caffe.git . && \
    pip install --upgrade pip && \
    for req in setuptools easydict $(cat python/requirements.txt) pydot; do pip install $req; done && \
    mkdir build && cd build && \
    cmake -DUSE_CUDNN=1 -DUSE_NCCL=1 .. && \
    make -j"$(nproc)"

ENV PYCAFFE_ROOT $CAFFE_ROOT/python
ENV PYTHONPATH $PYCAFFE_ROOT:$PYTHONPATH
ENV PATH $CAFFE_ROOT/build/tools:$PYCAFFE_ROOT:$PATH
RUN echo "$CAFFE_ROOT/build/lib" >> /etc/ld.so.conf.d/caffe.conf && ldconfig

WORKDIR /workspace
