FROM ubuntu:latest

LABEL maintainer="pascal.thibaudeau@cea.fr"
LABEL version="0.1"
LABEL description="Sparselizard on docker. See https://github.com/pthibaud/dockerlizard"

# Disable prompt during packages installation
ARG DEBIAN_FRONTEND=noninteractive

# Update ubuntu software repository
RUN apt-get update

# Install common tools
RUN apt-get install -y software-properties-common

# Install additional repository
RUN add-apt-repository universe && \
    apt-get update && \
    apt-get -y upgrade && \
    apt-get -y dist-upgrade && \
    apt-get install -y vim git cmake gmsh
    
# Install clang compiler
RUN apt-get install -y clang-12

# Install mandatory tools from ubuntu repository
RUN apt-get install -y \
    libopenblas-dev \
    libopenmpi-dev \
    libmumps-dev \
    libmetis-dev \
    petsc-dev \
    slepc-dev \
    libgmsh-dev

# Clean the installation
RUN apt-get clean

# Prepare users
RUN useradd -ms /bin/bash ubuntu

# Set permissions
RUN chown -R ubuntu:ubuntu /home/ubuntu && chmod +rwx /home/ubuntu

# switch to ubuntu user
USER ubuntu

# Prepare the code folder
RUN mkdir -p /home/ubuntu/sparselizard

# Clone git sparselizard repository
RUN git clone https://github.com/araven/sparselizard.git /home/ubuntu/sparselizard

# Prepare compilation environment
RUN mkdir -p /home/ubuntu/sparselizard/build
RUN cd /home/ubuntu/sparselizard/build && CXX=clang++-12 cmake ..

# Run the compilation process
RUN cd /home/ubuntu/sparselizard/build && make -j $(getconf _NPROCESSORS_ONLN)