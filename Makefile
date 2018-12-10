#####################################################################################
## CUDA + OpenMP Matrix product lab
## Makefile by S. Vialle, december 2018
#####################################################################################

CXX=g++-6
GPUCXX=nvcc --compiler-bindir /usr/bin/$(CXX)

CXXFLAGS = -O3 #-DDP 
CXXFLAGS += -DKERNELBLAS
CXXFLAGS += -I/opt/cuda/include/  #-I/usr/local/cuda/include
CC_CXXFLAGS = -Wall -fopenmp
CUDA_CXXFLAGS = #-arch=sm_61  #-arch=sm_20

CC_LDFLAGS =  -fopenmp
CUDA_LDFLAGS = -L/opt/cuda/lib64/  #-L/usr/local/cuda/lib64

CC_LIBS = -lopenblas
CUDA_LIBS = -lcudart -lcuda -lcublas

CC_SOURCES =  main.cc init.cc
CUDA_SOURCES = gpu-op.cu
CC_OBJECTS = $(CC_SOURCES:%.cc=%.o)
CUDA_OBJECTS = $(CUDA_SOURCES:%.cu=%.o)

EXECNAME = MatrixProduct


all:
	$(CXX) -c $(CC_SOURCES) $(CXXFLAGS) $(CC_CXXFLAGS)
	$(GPUCXX) -c $(CUDA_SOURCES) $(CXXFLAGS) $(CUDA_CXXFLAGS)
	$(CXX) -o $(EXECNAME) $(CC_LDFLAGS) $(CUDA_LDFLAGS) $(CC_OBJECTS) $(CUDA_OBJECTS) $(CUDA_LIBS) $(CC_LIBS)


clean:
	rm -f *.o $(EXECNAME) *.linkinfo *~ *.bak .depend


#Regles automatiques pour les objets
#%.o:  %.cc
#	$(CPUCC)  -c  $(CXXFLAGS) $(CC_CXXFLAGS) $<
#
#%.o:  %.cu
#	$(GPUCC)  -c  $(CXXFLAGS) $(CUDA_CXXFLAGS) $<
