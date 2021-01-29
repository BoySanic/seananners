#include <iostream>
#include <math.h>
#include <vector>
#include <iomanip>
#include <sstream>
#include <string>
#include <fstream>
#include <thread>
#include <ctime>
#include <stdio.h>

#define BLOCK_SIZE (128)
#define WORK_SIZE_BITS 16
#define SEEDS_PER_CALL ((1ULL << (WORK_SIZE_BITS)) * (BLOCK_SIZE))

#define GPU_ASSERT(code) gpuAssert((code), __FILE__, __LINE__)
inline void gpuAssert(cudaError_t code, const char *file, int line) {
  if (code != cudaSuccess) {
    fprintf(stderr, "GPUassert: %s (code %d) %s %d\n", cudaGetErrorString(code), code, file, line);
    exit(code);
  }
}
__device__ static  int next(int64_t *seed, const int bits)
{
    *seed = (*seed * 0x5deece66d + 0xb) & ((1LL << 48) - 1);
    return (int) (*seed >> (48 - bits));
}

__device__ static  int nextInt(int64_t *seed, const int n)
{
    int bits, val;
    const int m = n - 1;

    if((m & n) == 0) return (int) ((n * (int64_t)next(seed, 31)) >> 31);

    do {
        bits = next(seed, 31);
        val = bits % n;
    }
    while (bits - val + m < 0);
    return val;
}
__global__ __launch_bounds__(BLOCK_SIZE,2) static void threadWork(int64_t offset, uint32_t* counter, int64_t* buffer){
    uint64_t worldSeed = (blockIdx.x * blockDim.x + threadIdx.x) + offset;
    int64_t seed = worldSeed;
    int64_t tempSeed = (seed * 21586261248413UL + 164331561754775UL) & 281474976710655UL; 
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
 
    tempSeed = (tempSeed * 25214903917UL + 11UL) & 281474976710655UL;
    tempSeed = (tempSeed * 25214903917UL + 11UL) & 281474976710655UL;
    tempSeed = (tempSeed * 25214903917UL + 11UL) & 281474976710655UL;

    int xWiggle = nextInt(&tempSeed, 2) + 2;
    int zWiggle = nextInt(&tempSeed, 2) + 2;
    if(!(xWiggle == 3 && zWiggle == 2))return;

    //0th
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    //first column
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    if(next(&seed, 2) == 0)return;
    if(next(&seed, 2) == 0)return;
    if(next(&seed, 2) == 0)return;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    //second column
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    if(next(&seed, 2) == 0)return;
    if(next(&seed, 2) == 0)return;
    if(next(&seed, 2) == 0)return;
    if(next(&seed, 2) == 0)return;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    //third column
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    if(next(&seed, 2) == 0)return;
    if(next(&seed, 2) != 0)return;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    //fourth column
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    if(next(&seed, 2) != 0)return;
    if(next(&seed, 2) != 0)return;
    if(next(&seed, 2) != 0)return;
    if(next(&seed, 2) == 0)return;
    if(next(&seed, 2) != 0)return;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    //fifth column
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    if(next(&seed, 2) != 0)return;
    if(next(&seed, 2) != 0)return;
    if(next(&seed, 2) == 0)return;
    if(next(&seed, 2) == 0)return;
    if(next(&seed, 2) != 0)return;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    //sixth column
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    if(next(&seed, 2) != 0)return;
    if(next(&seed, 2) != 0)return;
    if(next(&seed, 2) != 0)return;
    if(next(&seed, 2) != 0)return;
    if(next(&seed, 2) != 0)return;
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    //seventh column
    seed = (seed * 25214903917UL + 11UL) & 281474976710655UL;
    if(next(&seed, 2) == 0)return;
    if(next(&seed, 2) != 0)return;
    if(next(&seed, 2) == 0)return;
    if(next(&seed, 2) != 0)return;
    if(next(&seed, 2) == 0)return;
    buffer[atomicAdd(counter, 1)] = worldSeed;
}

int64_t* buffer;
uint32_t* counter;

int main(int argc, char **argv ){
    int64_t startValue  = 0;
    int64_t total       = 281474976710656; 
    time_t start = time(NULL);
    FILE* fp = fopen("seananners-dfloor.txt", "w+");
    double seconds_per_structure_seed = 0.0;
    int thread = 0;
    int curr = 0;

    uint64_t amount = total - startValue;
    int tmpCount = 0;
    GPU_ASSERT(cudaMallocManaged(&buffer, sizeof(int64_t) * SEEDS_PER_CALL));
    GPU_ASSERT(cudaPeekAtLastError());
    GPU_ASSERT(cudaMallocManaged(&counter, sizeof(uint32_t)));
    GPU_ASSERT(cudaPeekAtLastError());

    cudaSetDevice(0);
    GPU_ASSERT(cudaPeekAtLastError());
    GPU_ASSERT(cudaDeviceSynchronize());
    uint64_t countOut = 0;
    uint64_t tempCount;
    for(int64_t offset = 0; offset < amount; offset += SEEDS_PER_CALL){
        int64_t value = startValue + offset;
        threadWork<<<1ULL<<WORK_SIZE_BITS,BLOCK_SIZE>>>(value, counter, buffer);
        GPU_ASSERT(cudaPeekAtLastError());
        GPU_ASSERT(cudaDeviceSynchronize());  
        for(int i = 0; i < *counter; i++){
            int64_t timeGuess = buffer[i];
            fprintf(fp, "%lld\n", timeGuess);
        }
        if(countOut >= 100000000000){
            time_t tempTime = time(NULL);
            uint64_t tempDiff = tempTime - start;
            double sps = (double)offset/(double)tempDiff;
            double percent = ((double)offset/(double)amount) * 100.0;
            printf("Seeds Per Second: %f\tProgress: %f\n", sps, percent);
            countOut = 0;
        }
        *counter = 0;
        countOut += SEEDS_PER_CALL;
    }
    time_t end = time(NULL);
    uint64_t diff = end - start;
    double seedsPerSec = (double)total/(double)diff;
    printf("Time taken: %lld\nSeeds per second: %15.9f", diff, seedsPerSec);
    fclose(fp);
    return 0;
}