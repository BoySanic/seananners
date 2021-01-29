#include "lib/javarnd.h"
#include "lib/layers.h"
#include "lib/finders.h"
#include "lib/generator.h"
#include "lib/BoundingBox.h"
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
#include <pthread.h>

FILE *fp;   
uint64_t total = 0;
uint64_t current = 0;
pthread_mutex_t mutex1 = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t mutex2 = PTHREAD_MUTEX_INITIALIZER;
time_t start;
time_t temp;

void increment(){
        pthread_mutex_lock(&mutex1);
            current++;
        if(current % 10000000 == 0){
            temp = time(NULL);
            double timeElapsed = temp -  start;
            double structSeedsPerSecond = (double)(current/timeElapsed);
            double timeRemain = (((double)timeElapsed * (double)total)/(double)current) - timeElapsed;
            printf("Progress: %024d/%024d completed    Structure Seeds/Sec: %09.5f    Seconds Remaining:%013.5f\n", current, total, structSeedsPerSecond, timeRemain);
        }
        pthread_mutex_unlock(&mutex1);

}
std::vector<std::string> arr;
std::vector<std::string> outArr;
void output(std::string outputt){
        pthread_mutex_lock(&mutex2);
        outArr.push_back(outputt);
        pthread_mutex_unlock(&mutex2);
}
void threadWork(int threadNumber, uint64_t offset, uint64_t amount){
    uint64_t structureSeed;
    int ChunkX;
    int ChunkZ;
    for(uint64_t i = offset; i < offset + amount; i++){
        structureSeed = i;
        //std::cout << "Thread " << threadNumber << " Testing " << structureSeed << std::endl;
        int Zmax = 10;
        int Zmin = 9;
        int Xmin = 0;
        int Xmax = 24;
        int regX = 0;
        int regZ = 0;
        int* valid = (int*)malloc(sizeof(int));

        Pos basePos = getStructurePos(VILLAGE_CONFIG, structureSeed, regX, regZ, valid);

        if(*valid){
            Pos villageMin; 
            villageMin.x = basePos.x;
            villageMin.z = basePos.z;
            Pos villageMax;
            villageMax.x = basePos.x;
            villageMax.z = basePos.z;
            Pos guessMin;
            guessMin.x = Xmin;
            guessMin.z = Zmin;
            Pos guessMax;
            guessMax.x = Xmax;
            guessMax.z = Zmax;
            BoundingBox villageBox;
            BoundingBox* guessBox = (BoundingBox*)malloc(sizeof(BoundingBox));
            villageBox.start = villageMin;
            villageBox.end = villageMax;
            guessBox->start = guessMin;
            guessBox->end = guessMax;
            if(villageBox.intersectsWith(guessBox)){
                char out[100];
                snprintf(out, sizeof(out), "%lld %d %d\n", (structureSeed), ChunkX, ChunkZ);
                std::string strOut = out;
                output(strOut);
            }
            delete guessBox;
            guessBox = NULL;

        }
        increment();
        delete valid;
        valid = NULL;
    }
    std::cout << "Thread " << threadNumber << " closing" << std::endl;
}
int main(int argc, char **argv ){
    int threadCount = 24;
    char* filename;
    for (int i = 1; i < argc; i += 2) {
		const char *param = argv[i];
		if (strcmp(param, "-t") == 0 || strcmp(param, "--threads") == 0) {
			threadCount = atoi(argv[i + 1]);
		}
	    else {
			fprintf(stderr,"Unknown parameter: %s\n", param);
		}
	}
    fp = fopen("pano-114-out.txt", "w+");
    double seconds_per_structure_seed = 0.0;
    std::vector<std::thread> threads;
    std::cout << "Begin loading threads" << std::endl;  
    int thread = 0;
    int curr = 0;

    total = 281474976710656;
    uint64_t structureSeedsPerThread = total/threadCount;
    uint64_t remainder = total % threadCount;
    uint64_t amount = structureSeedsPerThread + remainder;
    std::vector<std::string> tArr;
    uint64_t offset = 0;

    start = time(NULL);
    for(int i = 0; i < threadCount; i++){
        std::cout << "Thread " << i << " started with " << amount << " seeds" << std::endl;
        threads.push_back(std::thread(threadWork, i, offset, amount));
        offset += amount;
        amount = structureSeedsPerThread;
    }
    for(int thNum = 0; thNum < threadCount; thNum++){
        threads[thNum].join();
    }   
    time_t end = time(NULL);
    printf("%d structure seeds to output\n", total);
    time_t startF = time(NULL);
    for(uint64_t i = 0; i < total; i++){
        time_t tempF = time(NULL);
        double timeSpent = (double)((double)tempF - (double)startF);
        double timeRemaining = (((double)timeSpent * ((double)outArr.size()/(double)i)) - timeSpent);
        if(i % 100000 == 0){
            printf("FilePrint: %d/%d    Time Spent: %05.3f    Time Remaining: %05.3f\n", i, outArr.size(),timeSpent, timeRemaining);
        }
        fprintf(fp, "%s", outArr[i].c_str());
        fflush(fp);
    }
    time_t endF = time(NULL);
    double timeSpent = (double)((double)endF - (double)startF);

    printf("File took %f seconds to complete.\n", (double)(((double)end - (double)start)));
    printf("Output took %f seconds to complete.\n", timeSpent);
    fclose(fp);
    return 0;
}