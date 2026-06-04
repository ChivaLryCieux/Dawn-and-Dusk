#!/usr/bin/env python3
"""Hand gesture + motion + camera detector using MediaPipe GestureRecognizer."""
import sys, os, time, struct
import cv2
import numpy as np
import mediapipe as mp
from mediapipe.tasks.python import vision
from mediapipe.tasks.python.vision import RunningMode

SHARED_FILE = "/tmp/blue_hours_hand.txt"
FRAME_FILE = "/tmp/blue_hours_frame.bin"
MODEL_PATH = os.path.join(os.path.dirname(__file__), "models", "gesture_recognizer.task")

def is_fist(lm):
    w = lm[0]
    for tip, pip in [(4,3),(8,6),(12,10),(16,14),(20,18)]:
        td = (lm[tip]['x']-w['x'])**2 + (lm[tip]['y']-w['y'])**2
        pd = (lm[pip]['x']-w['x'])**2 + (lm[pip]['y']-w['y'])**2
        if td > pd:
            return False
    return True

def write_result(fist, gesture_name, motion, landmarks):
    tmp = SHARED_FILE + ".tmp"
    with open(tmp, 'w') as f:
        f.write("1\n" if fist else "0\n")
        f.write(gesture_name + "\n")
        f.write(f"{motion:.6f}\n")
        if landmarks:
            for i, lm in enumerate(landmarks):
                f.write(f"{i} {lm['x']:.6f} {lm['y']:.6f} {lm['z']:.6f}\n")
    os.replace(tmp, SHARED_FILE)

def write_frame(rgba):
    """Write raw RGBA frame as binary: [w:u32][h:u32][stride:u32][pixels...]"""
    h, w = rgba.shape[:2]
    stride = rgba.strides[0]
    tmp = FRAME_FILE + ".tmp"
    with open(tmp, 'wb') as f:
        f.write(struct.pack('<III', w, h, stride))
        f.write(rgba.tobytes())
    os.replace(tmp, FRAME_FILE)

def main():
    cap = cv2.VideoCapture(0, cv2.CAP_V4L2)
    if not cap.isOpened():
        cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        write_result(False, "none", 0.0, None)
        print("no camera", file=sys.stderr, flush=True)
        sys.exit(1)

    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    cap.set(cv2.CAP_PROP_FPS, 30)

    options = vision.GestureRecognizerOptions(
        base_options=mp.tasks.BaseOptions(model_asset_path=MODEL_PATH),
        running_mode=RunningMode.IMAGE,
        num_hands=1,
        min_hand_detection_confidence=0.5,
        min_hand_presence_confidence=0.5
    )
    recognizer = vision.GestureRecognizer.create_from_options(options)

    write_result(False, "none", 0.0, None)
    print("ok", flush=True)

    prev_gray = None

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                time.sleep(0.03)
                continue

            # Motion detection (downsampled grayscale diff)
            small = cv2.resize(frame, (160, 120), interpolation=cv2.INTER_AREA)
            gray = cv2.cvtColor(small, cv2.COLOR_BGR2GRAY)
            motion_val = 0.0
            if prev_gray is not None:
                diff = cv2.absdiff(gray, prev_gray)
                raw = float(np.mean(diff)) / 255.0
                motion_val = min(raw * 8.0, 1.0)
            prev_gray = gray

            # Gesture recognition
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
            result = recognizer.recognize(mp_image)

            landmarks = None
            fist = False
            gesture_name = "none"

            if result.gestures and result.hand_landmarks:
                gesture = result.gestures[0][0]
                gesture_name = gesture.category_name
                fist = (gesture_name == "Closed_Fist") or is_fist(
                    [{'x': lm.x, 'y': lm.y, 'z': lm.z} for lm in result.hand_landmarks[0]])
                landmarks = [{'x': lm.x, 'y': lm.y, 'z': lm.z}
                             for lm in result.hand_landmarks[0]]

            write_result(fist, gesture_name, motion_val, landmarks)

            # Write camera frame as raw RGBA
            rgba = cv2.cvtColor(frame, cv2.COLOR_BGR2RGBA)
            write_frame(rgba)

    except KeyboardInterrupt:
        pass
    finally:
        cap.release()
        recognizer.close()

if __name__ == "__main__":
    main()
