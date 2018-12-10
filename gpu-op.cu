/*********************************************************************************/
/* Matrix product program for a multi-core CPU and for a many-core GPU           */
/* S. Vialle - November 2016                                                     */
/*********************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <cuda.h>
#include <cuda_runtime.h>

#include "main.h"
#include "gpu-op.h"


/*-------------------------------------------------------------------------------*/
/* GPU symbols                                                                   */
/*-------------------------------------------------------------------------------*/
__device__ T_real GPU_A[SIZE][SIZE];
__device__ T_real GPU_B[SIZE][SIZE];
__device__ T_real GPU_C[SIZE][SIZE];


/*-------------------------------------------------------------------------------*/
/* Init and finalize the GPU device.                                             */
/*-------------------------------------------------------------------------------*/
void gpuInit(void)
{
  cuInit(0);
}


void gpuFinalize(void)
{

}


/*-------------------------------------------------------------------------------*/
/* Transfer of CPU input data into GPU symbols                                   */
/*-------------------------------------------------------------------------------*/
void gpuSetDataOnGPU(void)
{
  // Set GPU_A symbol
  CHECK_CUDA_SUCCESS(
   cudaMemcpyToSymbol(
     GPU_A,
     &A[0][0],
     (SIZE * SIZE) * sizeof(T_real),
     0,
     cudaMemcpyHostToDevice
   ),
   "Transfer A --> GPU_A"
  );

  // Set GPU_B symbol
  CHECK_CUDA_SUCCESS(
   cudaMemcpyToSymbol(
     GPU_B,
     &B[0][0],
     (SIZE * SIZE) * sizeof(T_real),
     0,
     cudaMemcpyHostToDevice
   ),
   "Transfer B --> GPU_B"
  );
}


/*-------------------------------------------------------------------------------*/
/* Transfer of GPU results into CPU array                                        */
/*-------------------------------------------------------------------------------*/
void gpuGetResultOnCPU(void)
{
  // Get GPU_C symbol
  CHECK_CUDA_SUCCESS(
    cudaMemcpyFromSymbol(
      &C[0][0],
      GPU_C,
      (SIZE * SIZE) * sizeof(T_real),
      0,
      cudaMemcpyDeviceToHost
    ),
    "Transfer GPU_C --> C"
  );
}


/*-------------------------------------------------------------------------------*/
/* Small matrix product on the local GPU.                                        */
/*-------------------------------------------------------------------------------*/
__global__ void MatrixProductKernel_v0(void)
{
  // Index computations
  int lig = blockIdx.y;
  int col = threadIdx.x + blockIdx.x * BLOCK_SIZE_X_K0;
  T_real res = 0.0;

  // Matrix product computation
  for (int i = 0; i < SIZE; i++) {
    res += GPU_A[lig][i] * GPU_B[i][col];
  }

  GPU_C[lig][col] = res;
}

__global__ void MatrixProductKernel_v1(void)
{
  // Index computations
  int lig = blockIdx.y;
  int col = threadIdx.x + blockIdx.x * BLOCK_SIZE_X_K0;
  T_real res = 0.0;

  // Matrix product computation
  if(col < SIZE) {
   for (int i = 0; i < SIZE; i++) {
     res += GPU_A[lig][i] * GPU_B[i][col];
   }

   GPU_C[lig][col] = res;
  }
}

__global__ void MatrixProductKernel_v2(void)
{
  // Index computations
  int lig = threadIdx.y + blockIdx.y * BLOCK_SIZE_Y_K1;
  int col = threadIdx.x + blockIdx.x * BLOCK_SIZE_X_K1;
  T_real res = 0.0;

  // Matrix product computation
  if(col < SIZE && lig < SIZE) {
   for (int i = 0; i < SIZE; i++) {
     res += GPU_A[lig][i] * GPU_B[i][col];
   }

   GPU_C[lig][col] = res;
  }
}

__global__ void MatrixProductKernel_v3(void)
{
  // Index computations
  int lig = threadIdx.y + blockIdx.y * BLOCK_SIZE_XY_K3;
  int col = threadIdx.x + blockIdx.x * BLOCK_SIZE_XY_K3;
  __shared__ T_real data_A[BLOCK_SIZE_XY_K3][BLOCK_SIZE_XY_K3];
  __shared__ T_real data_B[BLOCK_SIZE_XY_K3][BLOCK_SIZE_XY_K3];
  T_real res = .0;

  for (int e = 0; e < SIZE / BLOCK_SIZE_XY_K3; e++) {
    data_A[threadIdx.y][threadIdx.x] = GPU_A[lig][e * BLOCK_SIZE_XY_K3 + threadIdx.x];
    data_B[threadIdx.y][threadIdx.x] = GPU_B[e * BLOCK_SIZE_XY_K3 + threadIdx.y][col];
    __syncthreads();
    // Matrix product computation
    for (int i = 0; i < BLOCK_SIZE_XY_K3; i++) {
      res += data_A[threadIdx.y][i] * data_B[i][threadIdx.x];
    }
    __syncthreads();
  }

  GPU_C[lig][col] = res;
}

__global__ void MatrixProductKernel_v4(void)
{
  int lig = threadIdx.y + blockIdx.y * BLOCK_SIZE_XY_K3;
  int col = threadIdx.x + blockIdx.x * BLOCK_SIZE_XY_K3;
  __shared__ T_real data_A[BLOCK_SIZE_XY_K3][BLOCK_SIZE_XY_K3];
  __shared__ T_real data_B[BLOCK_SIZE_XY_K3][BLOCK_SIZE_XY_K3];
  T_real res = .0;
  int limit = (SIZE % BLOCK_SIZE_XY_K3) ? SIZE / BLOCK_SIZE_XY_K3 + 1 : SIZE / BLOCK_SIZE_XY_K3;

  for (int e = 0; e < limit; e++) {
    if (lig < SIZE && e * BLOCK_SIZE_XY_K3 + threadIdx.x < SIZE) 
      data_A[threadIdx.y][threadIdx.x] = GPU_A[lig][e * BLOCK_SIZE_XY_K3 + threadIdx.x];
    else
      data_A[threadIdx.y][threadIdx.x] = .0; 
   
    if (col < SIZE && e * BLOCK_SIZE_XY_K3 + threadIdx.y < SIZE) 
      data_B[threadIdx.y][threadIdx.x] = GPU_B[e * BLOCK_SIZE_XY_K3 + threadIdx.y][col];
    else
      data_B[threadIdx.y][threadIdx.x] = .0;
      
    __syncthreads();
    if (lig < SIZE && col < SIZE)
      for (int i = 0; i < BLOCK_SIZE_XY_K3; i++) 
        res += data_A[threadIdx.y][i] * data_B[i][threadIdx.x];
        
    __syncthreads();
  }
  
  if (lig < SIZE && col < SIZE)
    GPU_C[lig][col] = res;
}



/*-------------------------------------------------------------------------------*/
/* Small matrix product on the local GPU.                                        */
/*-------------------------------------------------------------------------------*/
void gpuProduct(gkid_t kid)
{
 dim3 Dg, Db;

 switch(kid) {

 case GK0 : // Kernel v0 - using only global memory (with coalescent data accesses)
   Db.x = BLOCK_SIZE_X_K0;
   Db.y = 1;
   Db.z = 1;
   Dg.x = SIZE / BLOCK_SIZE_X_K0;
   Dg.y = SIZE;
   Dg.z = 1;
   // - run the Grid of Blocs of threads
   MatrixProductKernel_v0<<<Dg,Db>>>();
   break;

 case GK1 :
   // - init the grid of blocs
   Db.x = BLOCK_SIZE_X_K0;
   Db.y = 1;
   Db.z = 1;
   Dg.x = !(SIZE % BLOCK_SIZE_X_K0) ? SIZE / BLOCK_SIZE_X_K0 : SIZE / BLOCK_SIZE_X_K0 + 1;
   Dg.y = SIZE;
   Dg.z = 1;
   // - run the Grid of Blocs of threads
   MatrixProductKernel_v1<<<Dg,Db>>>();
   break;

 case GK2 :
   // - init the grid of blocs
   Db.x = BLOCK_SIZE_X_K1;
   Db.y = BLOCK_SIZE_Y_K1;
   Db.z = 1;
   Dg.x = !(SIZE % BLOCK_SIZE_X_K1) ? SIZE / BLOCK_SIZE_X_K1 : SIZE / BLOCK_SIZE_X_K1 + 1;
   Dg.y = !(SIZE % BLOCK_SIZE_Y_K1) ? SIZE / BLOCK_SIZE_Y_K1 : SIZE / BLOCK_SIZE_Y_K1 + 1;
   Dg.z = 1;
   // - run the Grid of Blocs of threads
   MatrixProductKernel_v2<<<Dg,Db>>>();
   break;

 case GK3 :
   // - init the grid of blocs
   Db.x = BLOCK_SIZE_XY_K3;
   Db.y = BLOCK_SIZE_XY_K3;
   Db.z = 1;
   Dg.x = SIZE / BLOCK_SIZE_XY_K3; 
   Dg.y = SIZE / BLOCK_SIZE_XY_K3;
   Dg.z = 1;
   // - run the Grid of Blocs of threads
   MatrixProductKernel_v3<<<Dg,Db>>>();
   break;

 case GK4 :
// - init the grid of blocs
   Db.x = BLOCK_SIZE_XY_K3;
   Db.y = BLOCK_SIZE_XY_K3;
   Db.z = 1;
   Dg.x = !(SIZE % BLOCK_SIZE_XY_K3) ? SIZE / BLOCK_SIZE_XY_K3 : SIZE / BLOCK_SIZE_XY_K3 + 1;
   Dg.y = !(SIZE % BLOCK_SIZE_XY_K3) ? SIZE / BLOCK_SIZE_XY_K3 : SIZE / BLOCK_SIZE_XY_K3 + 1;
   Dg.z = 1;
   // - run the Grid of Blocs of threads
   MatrixProductKernel_v4<<<Dg,Db>>>();

  break;

 case GK5 :
  break;

 default :
   fprintf(stderr,"Unknown GPU kernel!");
   exit(EXIT_FAILURE);
 }
}
