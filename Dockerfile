FROM ubuntu:rolling

LABEL maintainer="pascal.thibaudeau@cea.fr"
LABEL version="0.2"
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
WORKDIR /home/ubuntu
RUN mkdir -p sparselizard

# Clone git sparselizard repository
RUN git clone https://github.com/araven/sparselizard.git

# Prepare compilation environment
RUN mkdir -p ./sparselizard/build
WORKDIR ./sparselizard/build
RUN sed -i 's/-no-pie//g' ../src/CMakeLists.txt
RUN CXX=clang++-12 cmake ..

# Run the compilation process
RUN make -j $(getconf _NPROCESSORS_ONLN)

# Install the library and headers; Put the env variables
RUN sudo make install
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
ENV OMPI_CXX=clang++-12

# Install the test directory
WORKDIR /home/ubuntu
RUN mkdir -p test && \
    cp ./sparselizard/simulations/default/disk.* ./test/ && \
    cp ./sparselizard/simulations/default/main.cpp ./test/

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
\t $(CXX) $(CXXFLAGS) $(INCLUDE) -c $<' > ./test/Makefile

# clean the local git repo
RUN rm -fr ./sparselizard