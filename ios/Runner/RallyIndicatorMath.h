#ifndef RALLY_INDICATOR_MATH_H
#define RALLY_INDICATOR_MATH_H
#include <math.h>
#include <stdbool.h>

typedef struct { double x, y; } RRPoint;
typedef struct { double left, top, right, bottom; } RRRect;
typedef struct { bool visible; double angle; RRPoint edge; } RRIndicator;

static inline bool rrTrackWalker(bool driving, bool exists, bool enabled) {
    return !driving && exists && enabled;
}

// Clip X/Y are already oriented by ARKit. Positive W is forward. The two
// extents are sphere supports along the side planes in clip coordinates.
static inline RRIndicator rrIndicator(double x, double y, double w, double extentX,
    double extentY, double radius, double width, double height, RRRect rim,
    bool previouslyShown) {
    RRIndicator result = {0};
    if (!isfinite(x) || !isfinite(y) || !isfinite(w) || !isfinite(extentX) ||
        !isfinite(extentY) || !(width > 0 && height > 0) ||
        !(rim.right > rim.left && rim.bottom > rim.top)) return result;
    double margin = previouslyShown ? 0.96 : 1.02;
    if (w + radius > 0 && fabs(x) <= w * margin + extentX &&
        fabs(y) <= w * margin + extentY) return result;
    // Dividing by signed W would flip the arrow for points behind the camera.
    double dx = x * width, dy = -y * height;
    if (hypot(dx, dy) < 1e-8) dx = 1;
    double cx = fmin(rim.right, fmax(rim.left, width / 2));
    double cy = fmin(rim.bottom, fmax(rim.top, height / 2));
    double tx = dx == 0 ? INFINITY : ((dx > 0 ? rim.right : rim.left) - cx) / dx;
    double ty = dy == 0 ? INFINITY : ((dy > 0 ? rim.bottom : rim.top) - cy) / dy;
    double scale = fmin(tx, ty);
    result.visible = true;
    result.angle = atan2(dy, dx);
    result.edge = (RRPoint){tx <= ty ? (dx > 0 ? rim.right : rim.left) : cx + dx * scale,
                            ty <= tx ? (dy > 0 ? rim.bottom : rim.top) : cy + dy * scale};
    return result;
}

static inline bool rrClear(RRPoint p, const RRRect *blocked, int count) {
    for (int i = 0; i < count; ++i) {
        RRRect b = blocked[i];
        if (p.x >= b.left && p.x <= b.right && p.y >= b.top && p.y <= b.bottom) return false;
    }
    return true;
}

// Search only when the ideal point is occupied. Retain the true bearing.
static inline bool rrFreeEdge(RRPoint ideal, RRRect rim, const RRRect *blocked,
                              int count, RRPoint *out) {
    if (rrClear(ideal, blocked, count)) { *out = ideal; return true; }
    double best = INFINITY;
    for (int side = 0; side < 4; ++side) {
        bool vertical = side < 2;
        double start = vertical ? rim.top : rim.left;
        double end = vertical ? rim.bottom : rim.right;
        for (double v = start; v < end + 4; v += 4) {
            RRPoint p = vertical ? (RRPoint){side == 0 ? rim.left : rim.right, fmin(v,end)}
                                 : (RRPoint){fmin(v,end), side == 2 ? rim.top : rim.bottom};
            double distance = hypot(p.x - ideal.x,p.y - ideal.y);
            if (distance < best && rrClear(p,blocked,count)) { best = distance; *out = p; }
        }
    }
    return isfinite(best);
}
#endif
