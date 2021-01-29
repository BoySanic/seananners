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
__device__ static inline void setSeed(int64_t *seed)
{
    *seed = (*seed ^ 0x5deece66d) & ((1LL << 48) - 1);
}

__device__ static inline int next(int64_t *seed, const int bits)
{
    *seed = (*seed * 0x5deece66d + 0xb) & ((1LL << 48) - 1);
    return (int) (*seed >> (48 - bits));
}

__device__ static inline int nextInt(int64_t *seed, const int n)
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

struct Pos
{
    int x, z;
};

__device__  class BoundingBox {
public:
	Pos start;
	Pos end;
	__device__ bool intersectsWith(BoundingBox box)
	{
		return this->end.x >= box.start.x && this->start.x <= box.end.x && this->end.z >= box.start.z && this->start.z <= box.end.z;
	}
};
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

/*
Originally 64-bit seed value.
Mod 48 bit to get the 48 bit value.
Time could be any 64-bit value that when mod 48 gives the structure seed value.
We have the 48 bit post-mod 48 value
((8682522807148012UL * 181783497276652981UL)^x)%(1LL << 48) = someSeed


Take 48 bit seed value
Loop upper bits
Xor (8682522807148012UL * 181783497276652981UL) with upperBits Seed
Find seed that matches
*/
__device__ BoundingBox guessBox;
__device__ int64_t startCurrent = 8682522807148012L;
__device__ int64_t hardcoded = 181783497276652981L;
__device__ int64_t current;

__global__ __launch_bounds__(BLOCK_SIZE,2) static void threadWork(uint64_t offset, uint32_t* counter, int64_t* buffer){
    int64_t timeGuess = (blockIdx.x * blockDim.x + threadIdx.x) + offset;
    timeGuess *= 1000;
    int64_t seedGuess = current ^ timeGuess;
    nextInt(&seedGuess, 203);
    if(nextInt(&seedGuess, 203) == 103){
        buffer[atomicAdd(counter, 1)] = timeGuess;
    }
}
__global__ __launch_bounds__(1,1) static void setupGuessBox(Pos guessMin, Pos guessMax){
    current = startCurrent*hardcoded*hardcoded*hardcoded*hardcoded*hardcoded*hardcoded*hardcoded*hardcoded*hardcoded*hardcoded*hardcoded*hardcoded*hardcoded;
    guessBox.start = guessMin;
    guessBox.end = guessMax;
}
int64_t* buffer;
uint32_t* counter;
std::vector<int64_t> structureSeeds;
int64_t* structSeedsArr;

int main(int argc, char **argv ){
    int64_t startValue  = 1282613228000000;
    int64_t total       = 1282706397225000;
    time_t start = time(NULL);
    FILE* fp = fopen("seananners-middlestep.txt", "w+");
    double seconds_per_structure_seed = 0.0;
    int thread = 0;
    int curr = 0;

    uint64_t amount = total - startValue;
    int tmpCount = 0;
    GPU_ASSERT(cudaMallocManaged(&buffer, sizeof(int64_t) * SEEDS_PER_CALL));
    GPU_ASSERT(cudaPeekAtLastError());
    GPU_ASSERT(cudaMallocManaged(&counter, sizeof(uint32_t)));
    GPU_ASSERT(cudaPeekAtLastError());
    Pos guessMin;
    Pos guessMax;
    guessMin.x = 1710;
    guessMin.z = 276;
    guessMax.x = 1734;
    guessMax.z = 348;
    setupGuessBox<<<1,1>>>(guessMin, guessMax);
    cudaSetDevice(0);
    GPU_ASSERT(cudaPeekAtLastError());
    GPU_ASSERT(cudaDeviceSynchronize());
    uint64_t countOut = 0;
    uint64_t tempCount;
    for(int64_t offset = 0; offset < amount; offset += SEEDS_PER_CALL){

        if(offset > amount){
            break;
        }
        int64_t value = startValue + offset;
        threadWork<<<1ULL<<WORK_SIZE_BITS,BLOCK_SIZE>>>(value, counter, buffer);
        GPU_ASSERT(cudaPeekAtLastError());
        GPU_ASSERT(cudaDeviceSynchronize());  
        for(int i = 0; i < *counter; i++){
            int64_t timeGuess = buffer[i];
            fprintf(fp, "%lld\n", timeGuess);
        }
        if(countOut >= 1000000000){
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