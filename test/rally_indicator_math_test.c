#include "../ios/Runner/RallyIndicatorMath.h"
#include "../ios/Runner/RallyGateMath.h"
#include <assert.h>
#include <stdio.h>

static const RRRect rim = {28, 24, 704, 328};
static RRIndicator project(double x, double y, double depth, bool shown) {
    return rrIndicator(x, y, depth, .02, .02, .015, 740, 350, rim, shown);
}

int main(void) {
    assert(rrGateFraction(-.5f,.5f,0,0,-.074f,-.074f,.085f) == .5f);
    assert(rrGateFraction(.5f,-.5f,0,0,-.074f,-.074f,.085f) == .5f);
    assert(rrGateFraction(-.5f,-.1f,0,0,0,0,.085f) < 0);
    assert(rrGateFraction(-.5f,.5f,.09f,.09f,0,0,.085f) < 0);
    assert(rrGateFraction(0,0,0,0,0,0,.085f) < 0);
    assert(rrGateFraction(NAN,.5f,0,0,0,0,.085f) < 0);
    assert(!project(0,0,1,false).visible);
    assert(!project(NAN,0,1,false).visible);
    // Horizontal and vertical clip coordinates produced by the oriented camera.
    // Rotating the phone 180 degrees reverses both viewport axes.
    for (int orientation = -1; orientation <= 1; orientation += 2) {
        RRIndicator right = project(2*orientation,0,1,false);
        RRIndicator up = project(0,2*orientation,1,false);
        assert(right.visible && right.edge.x == (orientation > 0 ? rim.right : rim.left));
        assert(up.visible && up.edge.y == (orientation > 0 ? rim.top : rim.bottom));
        RRIndicator diagonal = project(2*orientation,2*orientation,1,false);
        assert(diagonal.visible && cos(diagonal.angle)*orientation > 0 &&
               sin(diagonal.angle)*orientation < 0);
        RRIndicator rear = project(orientation,.2,-1,false);
        assert(rear.visible && cos(rear.angle)*orientation > 0);
    }
    assert(project(0,0,-1,false).edge.x == rim.right);
    assert(!project(1.03,0,1,false).visible); // partially visible, including model radius
    assert(project(1.05,0,1,false).visible);
    assert(project(1.00,0,1,true).visible);
    assert(!project(.97,0,1,true).visible);

    RRPoint ideal = project(2,0,1,false).edge, car, walker;
    RRRect blocks[2] = {{rim.right-30,ideal.y-24,rim.right+30,ideal.y+24}};
    assert(rrFreeEdge(ideal,rim,blocks,1,&car));
    blocks[1] = (RRRect){car.x-42,car.y-42,car.x+42,car.y+42};
    assert(rrFreeEdge(ideal,rim,blocks,2,&walker));
    assert(hypot(walker.x-car.x,walker.y-car.y)>42);
    assert(!rrTrackWalker(true,true,true));
    assert(rrTrackWalker(false,true,true));
    assert(!rrTrackWalker(false,false,true));
    assert(!rrTrackWalker(false,true,false));
    puts("Directional indicator checks passed");
}
