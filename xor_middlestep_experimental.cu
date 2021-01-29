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
/*__global__ __launch_bounds__(BLOCK_SIZE,2) static void threadWork(int64_t* values, int size, uint64_t offset, uint32_t* counter, uint64_t* buffer){
    int64_t Time = (blockIdx.x * blockDim.x + threadIdx.x) + offset;
    int64_t scrambledTime = hardcoded ^ Time;
    if(binarySearch(values, scrambledTime, 0, size) != -1){
        buffer[atomicAdd(counter, 1)] = Time;
        return;
    }
}*/
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
__device__ uint64_t hardcoded = 8682522807148012UL * 181783497276652981UL;
__global__ __launch_bounds__(BLOCK_SIZE,2) static void threadWork(uint64_t baseValue, uint32_t* counter, uint64_t* buffer){
    int upperBits = (blockIdx.x * blockDim.x + threadIdx.x);
    if(upperBits > 65535){
        //printf("upperbits: %d", upperBits);
        return;
    }
    printf("%d\n", upperBits);
    int64_t seed = ( upperBits << 48) | baseValue;
    int64_t timeGuess = seed ^ hardcoded;
    //printf("test: %lld\n", timeGuess);
    if(((timeGuess ^ hardcoded) % (1LL << 48)) != baseValue){
        printf("What the frick\n");
    }
    if(timeGuess <= 1282780799000000000 && timeGuess >= 1280361600000000000)
        buffer[atomicAdd(counter, 1)] = timeGuess;
    //else
        //printf("Value: %lld\n", timeGuess);
    //if(timeGuess <= 2505600000000000)
      //  buffer[atomicAdd(counter, 1)] = timeGuess;
}
uint64_t* buffer;
uint32_t* counter;
std::vector<int64_t> structureSeeds;
int64_t* structSeedsArr;
int main(int argc, char **argv ){
    time_t start = time(NULL);
    FILE* fp = fopen("seananners-middlestep.txt", "w+");
    std::fstream infile;
    infile.open("seananners.txt", std::ios::in);
    std::string line;
    while(std::getline(infile, line)){
        int64_t structureSeed = 0;
        std::istringstream iss(line);
        if(!(iss >> structureSeed)){break;}
        structureSeeds.push_back(structureSeed);
    }
    infile.close();
    double seconds_per_structure_seed = 0.0;
    std::vector<std::thread> threads;
    int thread = 0;
    int curr = 0;
    uint64_t startValue = 0;
    uint64_t total = 281474976710656;
    int tmpCount = 0;
    int tmpSize = structureSeeds.size();
    GPU_ASSERT(cudaMallocManaged(&buffer, sizeof(uint64_t) * SEEDS_PER_CALL));
    GPU_ASSERT(cudaPeekAtLastError());
    GPU_ASSERT(cudaMallocManaged(&counter, sizeof(uint32_t)));
    GPU_ASSERT(cudaPeekAtLastError());
    GPU_ASSERT(cudaMallocManaged(&structSeedsArr, sizeof(uint64_t) * tmpSize));
    GPU_ASSERT(cudaPeekAtLastError());

    for(int i = 0; i <= structureSeeds.size(); i++){
        structSeedsArr[i] = structureSeeds[i];
    }

    cudaSetDevice(0);
    GPU_ASSERT(cudaPeekAtLastError());
    GPU_ASSERT(cudaDeviceSynchronize());
    uint64_t countOut = 0;
    uint64_t tempCount;
    for(uint64_t offset = 0; offset < tmpSize; offset++){
        uint64_t inputValue = structSeedsArr[offset];
        threadWork<<<1ULL<<WORK_SIZE_BITS,BLOCK_SIZE>>>(inputValue, counter, buffer);
        GPU_ASSERT(cudaPeekAtLastError());
        GPU_ASSERT(cudaDeviceSynchronize());  
        for(int i = 0; i < *counter; i++){
            int64_t timeGuess = buffer[i];
            if(timeGuess != 0)
                fprintf(fp, "%lld\n", timeGuess);
        }
        *counter = 0;
    }
    time_t end = time(NULL);
    uint64_t diff = end - start;
    double seedsPerSec = (double)total/(double)diff;
    printf("Time taken: %lld\nSeeds per second: %15.9f", diff, seedsPerSec);
    fclose(fp);
    return 0;
}