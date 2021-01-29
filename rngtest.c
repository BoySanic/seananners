#include <stdio.h>
#include <stdint.h>

static inline void setSeed(int64_t *seed)
{
    *seed = (*seed ^ 0x5deece66d) & ((1LL << 48) - 1);
}

static inline int next(int64_t *seed, const int bits)
{
    *seed = (*seed * 0x5deece66d + 0xb) & ((1LL << 48) - 1);
    return (int) (*seed >> (48 - bits));
}
static inline int skip65(int64_t *seed){
    *seed = (*seed * 0xB4500F159B6D  + 0x5593A16ED14B ) & ((1LL << 48) - 1);
}
static inline int skip63(int64_t *seed){
    *seed = (*seed * 0x89A36E758065 + 0xD75D8F3C9E9 ) & ((1LL << 48) - 1);
}

int main(){
    long seed = 1;
    long seed2 = 1;
    setSeed(&seed);
    setSeed(&seed2);
    for(int i =0; i < 63; i++){
        next(&seed, 48);
    }
    skip63(&seed2);


    printf("Expected: %lld\tActual: %lld", seed, seed2);
}