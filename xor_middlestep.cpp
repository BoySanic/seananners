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
int total = 0;
int64_t current = 0;

pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;

time_t start;
time_t temp;
void increment(){
        pthread_mutex_lock(&mutex);
            current++;
        if(current % 10 == 0){
            temp = time(NULL);
            double timeElapsed = temp -  start;
            double seedsPerSec = (double)(current * 65536L)/timeElapsed;
            double structSeedsPerSecond = (double)(current/timeElapsed);
            double timeRemain = (((double)timeElapsed * (double)total)/(double)current) - timeElapsed;
            printf("Progress: %08d/%08d completed    World Seeds/Sec: %013.5f    Structure Seeds/Sec: %09.5f    Seconds Remaining:%013.5f\n", current, total, seedsPerSec, structSeedsPerSecond, timeRemain);
        }
        pthread_mutex_unlock(&mutex);

}
std::vector<int64_t> arr;
int64_t* values;
uint64_t hardcoded = 8682522807148012UL * 181783497276652981UL;
int binarySearch(int64_t value, int start, int size){
    int low = 0;
    int high = size - 1;
    int mid = 0;
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

void threadWork(int threadNumber, int offset, int amount){
    for(int i = offset; i < offset + amount; i++){
        int64_t scrambledTime = hardcoded ^ i;
        if(binarySearch(scrambledTime, 0, arr.size()) != -1){
            fprintf(fp, "%lld\n", i);
            fflush(fp);
        }
        increment();
    }
    std::cout << "Thread " << threadNumber << " closing" << std::endl;
}
int main(int argc, char **argv ){
    int threadCount = 24;
    fp = fopen("middlesstep-out.txt", "w+");
    std::string line;
    std::fstream infile;
    infile.open("seananners.txt", std::ios::in);
    double seconds_per_structure_seed = 0.0;
    std::vector<std::thread> threads;
    std::cout << "Begin loading file" << std::endl;  
    int thread = 0;
    int curr = 0;
    while(std::getline(infile, line)){
        int64_t structureSeed = 0;
        std::istringstream iss(line);
        if(!(iss >> structureSeed)){break;}
            arr.push_back(structureSeed);
    }
    infile.close();
    values = (int64_t*)malloc(sizeof(int64_t) * arr.size());
    for(int i = 0; i <= arr.size(); i++){
        values[i] = arr[i];
    }
    total = 1000000000;
    start = time(NULL);
    printf("Begin loading %d structure seeds into %d threads\n", total, threadCount);
    int structureSeedsPerThread = total/threadCount;
    int remainder = total % threadCount;
    int amount;
    if(remainder){
        amount = structureSeedsPerThread + 1;
        remainder--;
    }
    else{
        amount = structureSeedsPerThread;
    }
    std::vector<std::string> tArr;
    int offset = 0;
    for(int i = 0; i < threadCount; i++){
        std::cout << "Thread " << i << " started with " << amount << " seeds" << std::endl;
        curr = 0;
        threads.push_back(std::thread(threadWork, i, offset, amount));
        offset += amount;
        amount = structureSeedsPerThread;
        if(remainder){
            amount++;
            remainder--;
        }
    }
    for(int thNum = 0; thNum < threadCount; thNum++){
        threads[thNum].join();
    }   
    fclose(fp);
    time_t end = time(NULL);
    printf("File took %f seconds to complete.\n", (double)(((double)end - (double)start)));
    return 0;
}