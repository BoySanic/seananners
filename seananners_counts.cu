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
	__device__ static BoundingBox getBoundingBox(int minx, int miny, int minz, int maxx, int maxy, int maxz) {
		BoundingBox box;
		box.start.x = minx;
		box.start.z = minz;
		box.end.x = maxx;
		box.end.z = maxz;
		return box;
	}
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
__device__ int64_t hardcoded = 8682522807148012L * 181783497276652981L;
typedef unsigned long long int uint64_cu;
__device__ static bool match(int64_t seed){
    BoundingBox spawnBox;
    Pos spawn;
    spawn.x = 0;
    spawn.z = 0;
    int count = 0;
    int64_t structureSeed = seed;
    setSeed(&structureSeed);
    nextInt(&structureSeed, 12000);
    for(spawn.z = 0; (!spawnBox.intersectsWith(guessBox) && count <= 150) && !(spawn.z >= guessBox.end.z || spawn.x >= guessBox.end.x); spawn.z += nextInt(&structureSeed, 64) - nextInt(&structureSeed, 64))
    {
        spawn.x += nextInt(&structureSeed, 64) - nextInt(&structureSeed, 64);
        spawnBox.start = spawn;
        spawnBox.end = spawn;
        count++;
    }
    if(spawnBox.intersectsWith(guessBox)){
        return true;
    }
    return false;
}
__global__ __launch_bounds__(BLOCK_SIZE,2) static void threadWork(uint64_t offset, uint64_cu* underCounter, uint64_cu* overCounter, int64_t* buffer){
    int64_t timeGuess = (blockIdx.x * blockDim.x + threadIdx.x) + offset;
    uint64_t seedIndex = (blockIdx.x * blockDim.x + threadIdx.x);
    int64_t seedGuess = hardcoded ^ timeGuess;
    int64_t structureSeed = seedGuess;
    BoundingBox spawnBox;
    Pos spawn;
    spawn.x = 0;
    spawn.z = 0;
    int count = 0;
    setSeed(&structureSeed);
    nextInt(&structureSeed, 12000);
    for(spawn.z = 0; (!spawnBox.intersectsWith(guessBox) && count <= 150); spawn.z += nextInt(&structureSeed, 64) - nextInt(&structureSeed, 64))
    {
        spawn.x += nextInt(&structureSeed, 64) - nextInt(&structureSeed, 64);
        spawnBox.start = spawn;
        spawnBox.end = spawn;
        count++;
    }
    if(spawn.z > guessBox.end.z || spawn.x > guessBox.end.x){
        atomicAdd(underCounter, 1);
        return;
    }
    if(spawn.z < guessBox.start.z || spawn.x < guessBox.start.x){
        atomicAdd(overCounter, 1);
        return;
    }
}
__global__ __launch_bounds__(1,1) static void setupGuessBox(Pos guessMin, Pos guessMax){
    guessBox.start = guessMin;
    guessBox.end = guessMax;
}
int64_t* buffer;
uint32_t* counter;
uint64_cu* underCounter;
uint64_cu* overCounter;
int main(int argc, char **argv ){
    int64_t startValue  = 1282521600000;
    int64_t total       = 1282780799000;
    time_t start = time(NULL);
    FILE* fp = fopen("seananners-middlestep.txt", "w+");
    double seconds_per_structure_seed = 0.0;
    int thread = 0;
    int curr = 0;

    uint64_t amount = total - startValue;
    int tmpCount = 0;
    GPU_ASSERT(cudaMallocManaged(&buffer, sizeof(int64_t) * SEEDS_PER_CALL));
    GPU_ASSERT(cudaPeekAtLastError());
    GPU_ASSERT(cudaDeviceSynchronize());
    GPU_ASSERT(cudaMallocManaged(&overCounter, sizeof(uint32_t)));
    GPU_ASSERT(cudaPeekAtLastError());
    GPU_ASSERT(cudaDeviceSynchronize());
    GPU_ASSERT(cudaMallocManaged(&underCounter, sizeof(uint32_t)));
    GPU_ASSERT(cudaPeekAtLastError());
    GPU_ASSERT(cudaDeviceSynchronize());
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
    //*counter = 0;
    uint64_t countOut = 0;
    uint64_t tempCount;
    for(int64_t offset = 0; offset < amount; offset += SEEDS_PER_CALL){
        int64_t value = startValue + offset;
        value *= 1000;
        threadWork<<<1ULL<<WORK_SIZE_BITS,BLOCK_SIZE>>>(value, underCounter, overCounter, buffer);
        GPU_ASSERT(cudaPeekAtLastError());
        GPU_ASSERT(cudaDeviceSynchronize());  
        /*for(int i = 0; i < *counter; i++){
            int64_t timeGuess = buffer[i];
            if(timeGuess == -1){
                *underCounter++;
            }
            if(timeGuess == 1){
                *overCounter++;
            }
        }*/
        if(countOut >= 1000000000){
            time_t tempTime = time(NULL);
            uint64_t tempDiff = tempTime - start;
            double sps = (double)offset/(double)tempDiff;
            double percent = ((double)offset/(double)amount) * 100.0;
            printf("Seeds Per Second: %f\tProgress: %f\n", sps, percent);
            countOut = 0;
        }
        //*counter = 0;
        countOut += SEEDS_PER_CALL;
    }
    time_t end = time(NULL);
    uint64_t diff = end - start;
    double seedsPerSec = (double)total/(double)diff;
    uint64_t tot = total - startValue;
    printf("Time taken: %lld\nSeeds per second: %15.9f\nUnderCounter: %lld\nOverCounter: %lld\nTotal: %lld", diff, seedsPerSec, *underCounter, *overCounter, tot);
    fclose(fp);
    return 0;
}