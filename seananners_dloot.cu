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
__device__ static inline void skip65(int64_t *seed){
    *seed = (*seed * 0xB4500F159B6D  + 0x5593A16ED14B ) & ((1LL << 48) - 1);
}
__device__ static inline void skip63(int64_t *seed){
    *seed = (*seed * 0x89A36E758065 + 0xD75D8F3C9E9 ) & ((1LL << 48) - 1);
}



#define BLOCK_SIZE (256)
#define WORK_SIZE_BITS 20
#define SEEDS_PER_CALL ((1ULL << (WORK_SIZE_BITS)) * (BLOCK_SIZE))

#define GPU_ASSERT(code) gpuAssert((code), __FILE__, __LINE__)
inline void gpuAssert(cudaError_t code, const char *file, int line) {
  if (code != cudaSuccess) {
    fprintf(stderr, "GPUassert: %s (code %d) %s %d\n", cudaGetErrorString(code), code, file, line);
    exit(code);
  }
}


enum Item{
    unset,
    saddle,
    ingotIron,
    bread,
    wheat,
    gunpowder,
    silk,
    bucketEmpty,
    appleGold,
    redstone,
    record
};
struct Pos
{
    int x, z;
};

struct ItemStack{
    Item id;
    int amount;
};
const __device__ ItemStack Chest1[27] = {
    {},
    {},
    {},
    {},
    {},
    {gunpowder, 1}, //5
    {}, //6
    {}, //7 
    {}, //8
    {}, //9
    {}, //10
    {}, //11
    {}, //12
    {}, //13
    {}, //14
    {}, //15
    {}, //16
    {}, //17
    {}, //18
    {}, //19
    {}, //20
    {silk, 1}, //21
    {gunpowder, 1}, //22
    {}, //23
    {}, //24
    {}, //25
    {saddle, 1}, //26
};
const __device__ ItemStack Chest2[27] = {
    {},
    {},
    {},
    {},
    {},
    {bucketEmpty, 1}, //5
    {}, //6
    {gunpowder, 1}, //7
    {saddle, 1}, //8
    {}, //9
    {}, //10
    {}, //11
    {}, //12
    {}, //13
    {wheat, 1}, //14
    {}, //15
    {}, //16
    {}, //17
    {gunpowder, 3}, //18
};
//__device__ ItemStack *Chest1;
//__device__ ItemStack *Chest2;
__device__ static void getItem(ItemStack* tempItem, int64_t* seed){

    int x = nextInt(seed, 11);
    if(x == 0){
        tempItem->id = saddle;
        tempItem->amount = 1;
    }
    if(x == 1){
        tempItem->id = ingotIron;
        tempItem->amount = nextInt(seed, 4) + 1;
    }
    if(x == 2){
        tempItem->id = bread;
        tempItem->amount = 1;
    }
    if(x == 3){
        tempItem->id = wheat;
        tempItem->amount = nextInt(seed, 4) + 1;
    }
    if(x == 4){
        tempItem->id = gunpowder;
        tempItem->amount = nextInt(seed, 4) + 1;
    }
    if(x == 5){
        tempItem->id = silk;
        tempItem->amount = nextInt(seed, 4) + 1;
    }
    if(x == 6){
        tempItem->id = bucketEmpty;
        tempItem->amount = 1;
    }
    if(x == 7 && nextInt(seed, 100) == 0){
        tempItem->id = appleGold;
    }
    if(x == 8 && nextInt(seed, 2) == 0){
        tempItem->id = redstone;
        tempItem->amount = nextInt(seed, 4) + 1;
    }
    if(x == 9 && nextInt(seed, 10) == 0){
        tempItem->id = record;
        tempItem->amount = 1;
        //We don't have one anyway so I'm unconcerned
    }
    if(x > 9){
        tempItem->id = unset;
        tempItem->amount = 1;
    }

}
__device__ static bool testSeed(int64_t seed){
    int64_t testSeed = seed;
    int64_t permutationSeed = testSeed;
    int chestCounter = 0;
    int curChest = 0;
    int itemCounter = 0;
    int firstChest = 0;
    ItemStack firstChestSim[27];
    ItemStack secondChestSim[27];
    for(int i = 0; i < 2; i++){
        for(int i2 = 0; i2 < 3; i2++){
            int curChest = 0;
            int locCounter = 0;
            /*
                int xChest = (x + random.nextInt(xWiggle * 2 + 1)) - xWiggle;
                int yChest = ySpawner;
                int zChest = (z + random.nextInt(zWiggle * 2 + 1)) - zWiggle;
            */
            int xChest = (nextInt(&permutationSeed, 7));
            int zChest = (nextInt(&permutationSeed, 5));
            if(xChest == 6 && zChest == 2)
                curChest = 2;
            else if(xChest == 4 && zChest == 4)
                curChest = 1;
            if(curChest == firstChest){
                return false;
            }
            if((xChest == 6 && zChest == 2) || xChest == 4 && zChest == 4){
                for(int i3 = 0; i3 <= 8; i3++){
                    ItemStack it;
                    getItem(&it, &permutationSeed);
                    if(it.id == saddle || it.id == gunpowder || it.id == wheat || it.id == bucketEmpty || it.id == silk){
                        int itemIndex = nextInt(&permutationSeed, 26);
                        if (Chest1[itemIndex].id == it.id && Chest1[itemIndex].amount > firstChestSim[itemIndex].amount && && firstChestSim[itemIndex].amount + it.amount <= Chest1[itemIndex].amount && curChest == 1){
                            firstChestSim[itemIndex].id = it.id;
                            firstChestsim[itemIndex].amount += it.amount;
                        }
                        if (Chest2[itemIndex].id == it.id && Chest2[itemIndex].amount > secondChestSim[itemIndex].amount && && secondChestSim[itemIndex].amount + it.amount <= Chest2[itemIndex].amount && curChest == 2){
                            secondChestSim[itemIndex].id = it.id;
                            secondChestSim[itemIndex].amount += it.amount;
                        }
                    }
                    else{
                        return false;
                    }
                }
                if(locCounter > 4 && curChest == 1 || locCounter > 5 && curChest == 2){
                    return false;
                }
                itemCounter += locCounter;
            }
            else{
                locCounter = 0;
            }
            if(firstChest == 0){
                firstChest = curChest;
            }
        }
    }
    if(itemCounter == 9){
        return true;
    }
    else{
        return false;
    }
}
__global__ __launch_bounds__(BLOCK_SIZE,2) static void threadWork(int64_t offset, uint32_t* counter, int64_t* buffer){
    uint64_t seed = (blockIdx.x * blockDim.x + threadIdx.x) + offset;
    int64_t structureSeed = seed;
    int count = 0;
    setSeed(&structureSeed);
    nextInt(&structureSeed, 16);
    nextInt(&structureSeed, 128);
    nextInt(&structureSeed, 16);
    int xWiggle = nextInt(&structureSeed, 2) + 2;
    int zWiggle = nextInt(&structureSeed, 2) + 2;
    if(xWiggle == 3 && zWiggle == 2){
        skip63(&structureSeed);
        if(testSeed(structureSeed)){
            buffer[atomicAdd(counter, 1)] = seed;
        }
    }
}
__device__ int64_t stonks[] = {3033227586,
    11299383782,
    19174124756,
    26213759191,
    30882125013,
    31573082574};
__global__ __launch_bounds__(1,1) static void testFunc(){
    for(int64_t i = 0; i < 6; i++){
        int64_t structureSeed = stonks[i];
        skip63(&structureSeed);
        if(testSeed(structureSeed)){
            printf("THIS SEED IS STONKS: %lld\n", stonks[i]);
        }
        else{
            printf("THIS SEED IS NOT STONKS: %lld\n", stonks[i]);
        }
    }
}

/*__global__ __launch_bounds__(1,1) static void setupChestTables(){
    Chest1 = (ItemStack*) malloc(sizeof(ItemStack) * 27);
    Chest2 = (ItemStack*) malloc(sizeof(ItemStack) * 27);

    Chest1[5].id = gunpowder;
    Chest1[5].amount = 1;
    Chest1[21].id = silk;
    Chest1[21].amount = 1;
    Chest1[22].id = gunpowder;
    Chest1[22].amount = 1;
    Chest1[26].id = saddle;
    Chest1[26].amount = 1;

    Chest2[5].id = bucketEmpty;
    Chest2[5].amount = 1;
    Chest2[7].id = gunpowder;
    Chest2[7].amount = 2;
    Chest2[8].id = saddle;
    Chest2[8].amount = 1;
    Chest2[14].id = wheat;
    Chest2[14].amount = 1;
    Chest2[18].id = gunpowder;
    Chest2[18].amount = 3;
}*/
int64_t* buffer;
uint32_t* counter;

std::vector<int64_t> structureSeeds;
int64_t* structSeedsArr;
int main(int argc, char **argv ){
    int64_t startValue  = 0;
    int64_t total       = 281474976710656; 
    time_t start = time(NULL);
    FILE* fp = fopen("seananners-dloot.txt", "w+");
    double seconds_per_structure_seed = 0.0;
    int thread = 0;
    int curr = 0;

    uint64_t amount = total - startValue;
    int tmpCount = 0;
    GPU_ASSERT(cudaMallocManaged(&buffer, sizeof(int64_t) * SEEDS_PER_CALL));
    GPU_ASSERT(cudaPeekAtLastError());
    GPU_ASSERT(cudaMallocManaged(&counter, sizeof(uint32_t)));
    GPU_ASSERT(cudaPeekAtLastError());

    //setupChestTables<<<1,1>>>();
    //printf("Chest tables set up\n");

    //testFunc<<<1,1>>>();
    for(int i = 0; i < 27; i++){
        printf("%d, %d index: %d\n", Chest1[i].id, Chest1[i].amount, i);
    }
    for(int i = 0; i < 27; i++){
        printf("%d, %d index: %d\n", Chest2[i].id, Chest2[i].amount, i);
    }
    GPU_ASSERT(cudaPeekAtLastError());
    GPU_ASSERT(cudaDeviceSynchronize());
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
        if(countOut >= 20000000000){
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