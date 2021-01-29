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
#include <algorithm>

int unique = 1;
int64_t startCurrent = 8682522807148012L;
int64_t hardcoded = 181783497276652981L;
int64_t current = startCurrent;
int64_t testNanotime = 1282613228000000;
std::vector<int64_t> values;
std::vector<int64_t> seedValues;
int main(int argc, char **argv ){
    time_t start = time(NULL);
    FILE* fp = fopen("seananners-unquifier.txt", "w+");
    double seconds_per_structure_seed = 0.0;
    values.push_back(current);
    int i = 0;
    while(i < 250000){
        current *= hardcoded;
        if(!(std::find(values.begin(), values.end(), current) != values.end())){
            values.push_back(current);
        }
        else{
            printf("Duplicate found at %d iterations!\n", i);
        }
        if(i % 1000 == 0){
            printf("Unique values: %d\n", values.size());
        }
        i++;
    }
    printf("Testing values against seeds...\n");
    for(int j = 0; j < 250000; j++){
        current = values[j];
        int64_t testSeed = current ^ testNanotime;
        if(!(std::find(seedValues.begin(), seedValues.end(), testSeed) != seedValues.end())){
            seedValues.push_back(testSeed);
        }
        else{
            printf("Duplicate found at %d iterations!\n", j);
            break;
        }
        if(j % 1000 == 0){
            printf("Unique values: %d\n", seedValues.size());
        }
    }
    time_t end = time(NULL);
    uint64_t diff = end - start;
    printf("Time taken: %lld\n", diff);
    fclose(fp);
    return 0;
}