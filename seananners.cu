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
FILE *fp;   
uint64_t total = 0;
uint64_t current = 0;

__device__ BoundingBox guessBox;

uint64_t* buffer;
uint32_t* counter;
//__device__ uint64_t hardcoded = 8682522807148012UL * 181783497276652981UL;

__global__ __launch_bounds__(BLOCK_SIZE,2) static void threadWork(uint64_t offset, uint32_t* counter, uint64_t* buffer){
    uint64_t seed = (blockIdx.x * blockDim.x + threadIdx.x) + offset;
    //int64_t structureSeed = hardcoded ^ seed;
    int64_t structureSeed = seed;
    BoundingBox spawnBox;
    Pos spawn;
    spawn.x = 0;
    spawn.z = 0;
    int count = 0;
    setSeed(&structureSeed);
    nextInt(&structureSeed, 12000);
    for(spawn.z = 0; !spawnBox.intersectsWith(guessBox) && count <= 150; spawn.z += nextInt(&structureSeed, 64) - nextInt(&structureSeed, 64))
    {
        spawn.x += nextInt(&structureSeed, 64) - nextInt(&structureSeed, 64);
        spawnBox.start = spawn;
        spawnBox.end = spawn;
        count++;
    }
    if(spawnBox.intersectsWith(guessBox)){
        buffer[atomicAdd(counter, 1)] = seed;
    }
}
__global__ __launch_bounds__(1,1) static void setupGuessBox(Pos guessMin, Pos guessMax){
    guessBox.start = guessMin;
    guessBox.end = guessMax;
}
int main(int argc, char **argv ){
    time_t start = time(NULL);
    fp = fopen("seananners.txt", "w+");
    double seconds_per_structure_seed = 0.0;
    std::vector<std::thread> threads;
    std::cout << "Begin loading threads" << std::endl;  
    int thread = 0;
    int curr = 0;
    uint64_t startValue = 0;
    total = 100000000000;
    std::vector<std::string> tArr;
    int tmpCount = 0;
    GPU_ASSERT(cudaMallocManaged(&buffer, sizeof(uint64_t) * SEEDS_PER_CALL));
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
    std::vector<uint64_t> results;
    uint64_t countOut = 0;
    uint64_t tempCount;
    for(uint64_t offset = startValue; offset <= total; offset += SEEDS_PER_CALL){
            threadWork<<<1ULL<<WORK_SIZE_BITS,BLOCK_SIZE>>>(offset, counter, buffer);
            GPU_ASSERT(cudaPeekAtLastError());
            GPU_ASSERT(cudaDeviceSynchronize());  
            for(int i = 0; i < *counter; i++){
                uint64_t seed = buffer[i];
                if(seed != 0)
                    fprintf(fp, "%lld\n", seed);
            }
            *counter = 0;
            if(countOut >= 5000000000){
                time_t tempTime = time(NULL);
                uint64_t tempDiff = tempTime - start;
                double sps = (double)(offset - startValue)/tempDiff;
                double percent = ((double)offset/(double)total) * 100.0;
                printf("Seeds Per Second: %f\tProgress: %f\n", sps, percent);
                countOut = 0;
            }
        countOut += SEEDS_PER_CALL;
    }

    time_t end = time(NULL);
    uint64_t diff = end - start;
    double seedsPerSec = (double)total/(double)diff;
    printf("Time taken: %lld\nSeeds per second: %15.9f", diff, seedsPerSec);
    fclose(fp);
    return 0;
}