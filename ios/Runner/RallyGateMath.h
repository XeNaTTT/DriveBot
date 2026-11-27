#pragma once
#include <stdbool.h>
#include <math.h>

// Endpoints in gate-local coordinates. Only the intersection with the open
// disk counts, in either direction, regardless of the length of the step.
static inline float rrGateFraction(float depthA, float depthB, float xA, float xB,
                                 float yA, float yB, float radius) {
    if (depthA == depthB || depthA * depthB > 0 || !(radius > 0)) return -1;
    float t = depthA / (depthA - depthB);
    float x = xA + t * (xB - xA);
    float y = yA + t * (yB - yA);
    return x*x + y*y <= radius*radius ? t : -1;
}
