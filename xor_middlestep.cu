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
__device__ uint64_t hardcoded = 8682522807148012UL * 181783497276652981UL;
__device__ int binarySearch(int64_t* values, int64_t value, int start, int end){
    int low = 0;
    int high = end - 1;
    int mid = 0;
    if(high < value || low > value)
        return -1;
    while(low <= high){
        mid = low + ((high - low)/2);
        if(values[mid] > value) 
            high = mid - 1;
        else if((values[mid] < value))
            low = mid - 1;
        else
            return mid;
    }
    return -1;
}
/*__global__ __launch_bounds__(BLOCK_SIZE,2) static void threadWork(int64_t* values, int size, uint64_t offset, uint32_t* counter, uint64_t* buffer){
    int64_t Time = (blockIdx.x * blockDim.x + threadIdx.x) + offset;
    int64_t scrambledTime = hardcoded ^ Time;
    if(binarySearch(values, scrambledTime, 0, size) != -1){
        buffer[atomicAdd(counter, 1)] = Time;
        return;
    }
}*/
__global__ __launch_bounds__(BLOCK_SIZE,2) static void threadWork(int64_t* values, int size, uint64_t offset, uint32_t* counter, uint64_t* buffer){
    int64_t Time = (blockIdx.x * blockDim.x + threadIdx.x) + offset;
    int64_t scrambledTime = hardcoded ^ Time;
    if(binarySearch(values, scrambledTime, 0, size) != -1){
        buffer[atomicAdd(counter, 1)] = Time;
        return;
    }
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
    printf("test1\n");
    for(int i = 0; i <= structureSeeds.size(); i++){
        structSeedsArr[i] = structureSeeds[i];
    }
    printf("test2\n");

    printf("test3\n");
    cudaSetDevice(0);
    GPU_ASSERT(cudaPeekAtLastError());
    GPU_ASSERT(cudaDeviceSynchronize());
    uint64_t countOut = 0;
    uint64_t tempCount;
    printf("test4\n");
    for(uint64_t offset = startValue; offset <= total; offset += SEEDS_PER_CALL){
            threadWork<<<1ULL<<WORK_SIZE_BITS,BLOCK_SIZE>>>(structSeedsArr, tmpSize, offset, counter, buffer);
            GPU_ASSERT(cudaPeekAtLastError());
            GPU_ASSERT(cudaDeviceSynchronize());  
            for(int i = 0; i < *counter; i++){
                uint64_t seed = buffer[i];
                if(seed != 0)
                    fprintf(fp, "%lld\n", seed);
            }
            *counter = 0;
            if(countOut >= 100000000000){
                time_t tempTime = time(NULL);
                uint64_t tempDiff = tempTime - start;
                uint64_t sps = (uint64_t)(offset - startValue)/tempDiff;
                double percent = ((double)offset/(double)total) * 100.0;
                printf("Seeds Per Second: %lld\tProgress: %f\n", sps, percent);
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