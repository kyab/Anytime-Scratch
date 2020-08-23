//
//  soundutil.c
//  Anytime Scratch
//
//  Created by kyab on 2020/08/07.
//  Copyright © 2020 kyab. All rights reserved.
//

#include "soundutil.h"
#include <math.h>

float sinc(float x){
    float y;
    if (x == 0.0){
        y = 1.0;
    }else{
        y = sin(x)/x;
    }
    
    return y;
}

void hanning_window(float *w, int N){
    if ( N % 2 == 0){
        for (int n = 0; n < N; n++){
            w[n] = 0.5 - 0.5*cos(2.0 * M_PI * n / N);
        }
    }else{
        for (int n = 0; n < N; n++){
            w[n] = 0.5 - 0.5*cos(2.0 * M_PI * (n+0.5)/N);
        }
    }
}
