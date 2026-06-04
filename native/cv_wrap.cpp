// cv_wrap.cpp — OpenCV camera capture wrapper for LuaJIT FFI
// Provides a minimal C API over OpenCV's C++ VideoCapture

#include <opencv2/core.hpp>
#include <opencv2/videoio.hpp>
#include <opencv2/imgproc.hpp>
#include <cstdint>
#include <cstdlib>
#include <cstring>

struct CameraState {
    cv::VideoCapture cap;
    cv::Mat frame;
    cv::Mat rgba;
    cv::Mat prevGray;
    cv::Mat diffSmall;
};

extern "C" {

// Open camera device. Returns opaque handle, or NULL on failure.
void* cvw_open(int device_id) {
    try {
        auto* state = new CameraState();
        state->cap.open(device_id, cv::CAP_V4L2);
        if (!state->cap.isOpened()) {
            state->cap.open(device_id);
        }
        if (!state->cap.isOpened()) {
            delete state;
            return nullptr;
        }
        state->cap.set(cv::CAP_PROP_FRAME_WIDTH, 640);
        state->cap.set(cv::CAP_PROP_FRAME_HEIGHT, 480);
        state->cap.set(cv::CAP_PROP_FPS, 30);
        return state;
    } catch (...) {
        return nullptr;
    }
}

// Read one frame. Returns 1 on success, 0 on failure.
int cvw_read(void* handle, uint8_t** out_data, int* out_w, int* out_h, int* out_stride) {
    if (!handle || !out_data || !out_w || !out_h || !out_stride) return 0;
    try {
        auto* state = static_cast<CameraState*>(handle);
        if (!state->cap.read(state->frame) || state->frame.empty()) {
            return 0;
        }

        cv::cvtColor(state->frame, state->rgba, cv::COLOR_BGR2RGBA);

        int w = state->rgba.cols;
        int h = state->rgba.rows;
        int stride = static_cast<int>(state->rgba.step[0]);
        size_t size = static_cast<size_t>(stride) * h;

        uint8_t* buf = static_cast<uint8_t*>(malloc(size));
        if (!buf) return 0;
        memcpy(buf, state->rgba.data, size);

        *out_data = buf;
        *out_w = w;
        *out_h = h;
        *out_stride = stride;
        return 1;
    } catch (...) {
        return 0;
    }
}

// Free a frame buffer returned by cvw_read.
void cvw_free_frame(uint8_t* data) {
    if (data) free(data);
}

// Compute motion between current and previous frame.
// Returns 0.0 (still) to 1.0 (fast motion). -1.0 if unavailable.
float cvw_motion(void* handle) {
    if (!handle) return -1.0f;
    try {
        auto* state = static_cast<CameraState*>(handle);
        if (state->frame.empty()) return -1.0f;

        cv::Mat small;
        cv::resize(state->frame, small, cv::Size(160, 120), 0, 0, cv::INTER_AREA);

        cv::Mat gray;
        cv::cvtColor(small, gray, cv::COLOR_BGR2GRAY);

        if (state->prevGray.empty()) {
            gray.copyTo(state->prevGray);
            return 0.0f;
        }

        cv::absdiff(gray, state->prevGray, state->diffSmall);
        cv::Scalar mean = cv::mean(state->diffSmall);
        gray.copyTo(state->prevGray);

        float raw = static_cast<float>(mean[0]) / 255.0f;
        float motion = raw * 8.0f;
        return motion > 1.0f ? 1.0f : motion;
    } catch (...) {
        return -1.0f;
    }
}

// Close camera and release all resources.
void cvw_close(void* handle) {
    try {
        if (handle) {
            delete static_cast<CameraState*>(handle);
        }
    } catch (...) {}
}

} // extern "C"
