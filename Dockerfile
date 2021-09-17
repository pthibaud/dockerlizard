FROM ubuntu:latest

LABEL maintainer="pascal.thibaudeau@cea.fr"
LABEL version="0.1"
LABEL description="Sparselizard on docker. See https://github.com/pthibaud/dockerlizard"

# Disable prompt during packages installation
ARG DEBIAN_FRONTEND=noninteractive

# Update ubuntu software repository
RUN apt-get update

# Install apt-utils
RUN apt-get install -y apt-utils

# Install common tools
RUN apt-get install -y software-properties-common

# Install additional repository
RUN add-apt-repository universe && \
    apt-get update && \
    apt-get -y upgrade && \
    apt-get -y dist-upgrade && \
    apt-get install -y sudo vim git cmake gmsh
    
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
RUN usermod -aG sudo ubuntu
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

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

# Install the library and headers
RUN cd /home/ubuntu/sparselizard/build && sudo make install
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
ENV OMPI_CXX=clang++-12

# Install the test directory
RUN mkdir -p /home/ubuntu/test && \
    cp /home/ubuntu/sparselizard/simulations/default/disk.* /home/ubuntu/test/ && \
    cp /home/ubuntu/sparselizard/simulations/default/main.cpp /home/ubuntu/test/

# Create a test Makefile
RUN echo 'CXX=mpic++ \n\
CXXFLAGS=-Ofast \n\
INCLUDE=-I/usr/local/include/sparselizard -I/usr/include/petsc \n\
LIBS=-L/usr/local/lib -lsparselizard \n\
main.x: main.o \n\
\t $(CXX) $(CXXFLAGS) -o main.x main.o $(LIBS) \n\
clean:\n\
\t @rm -f main.x main.o u.vtk \n\
.cpp.o: \n\
\t $(CXX) $(CXXFLAGS) $(INCLUDE) -c $<' > /home/ubuntu/test/Makefile

# clean the local git repo
RUN rm -fr /home/ubuntu/sparselizard
