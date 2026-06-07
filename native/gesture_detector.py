#!/usr/bin/env python3
"""Hand gesture + motion + camera detector using MediaPipe GestureRecognizer."""
import sys, os, time, struct, tempfile, traceback
import cv2
import numpy as np
import mediapipe as mp
from mediapipe.tasks.python import vision
from mediapipe.tasks.python.vision import RunningMode

# Early stdout unbuffering + UTF-8 safety for non-ASCII Windows consoles
sys.stdout.reconfigure(encoding='utf-8', errors='replace') if hasattr(sys.stdout, 'reconfigure') else None
sys.stderr.reconfigure(encoding='utf-8', errors='replace') if hasattr(sys.stderr, 'reconfigure') else None

TMP_DIR = tempfile.gettempdir()
SHARED_FILE = os.path.join(TMP_DIR, "blue_hours_hand.txt")
FRAME_FILE = os.path.join(TMP_DIR, "blue_hours_frame.bin")
MODEL_PATH = os.path.join(os.path.dirname(__file__), "models", "gesture_recognizer.task")

def is_fist(lm):
    w = lm[0]
    for tip, pip in [(4,3),(8,6),(12,10),(16,14),(20,18)]:
        td = (lm[tip]['x']-w['x'])**2 + (lm[tip]['y']-w['y'])**2
        pd = (lm[pip]['x']-w['x'])**2 + (lm[pip]['y']-w['y'])**2
        if td > pd:
            return False
    return True

def _atomic_replace(src, dst):
    """Like os.replace() but retries on Windows file-lock errors.
    Love2D may have the file open for reading; on Windows that blocks
    the replace.  We retry with exponential backoff and, as a last
    resort, fall back to a plain overwrite."""
    for attempt in range(6):
        try:
            os.replace(src, dst)
            return True
        except OSError as e:
            # WinError 5 = Access denied, WinError 32 = file in use
            if e.errno == 13 or (hasattr(e, 'winerror') and e.winerror in (5, 32)):
                time.sleep(0.005 * (2 ** attempt))  # 5, 10, 20, 40, 80 ms
                continue
            # Any other OSError: try plain write as fallback
            break
        except Exception:
            break
    # Fallback: try a plain copy/write instead of atomic replace
    try:
        with open(src, 'rb') as sf:
            data = sf.read()
        with open(dst, 'wb') as df:
            df.write(data)
        try:
            os.remove(src)
        except OSError:
            pass
        return True
    except Exception:
        return False


def write_result(fist, gesture_name, motion, landmarks):
    # Guard: ensure gesture_name is a valid string (never Python None)
    if gesture_name is None or not isinstance(gesture_name, str):
        gesture_name = "none"
    tmp = SHARED_FILE + ".tmp"
    try:
        with open(tmp, 'w') as f:
            f.write("1\n" if fist else "0\n")
            f.write(gesture_name + "\n")
            f.write(f"{motion:.6f}\n")
            if landmarks:
                for i, lm in enumerate(landmarks):
                    f.write(f"{i} {lm['x']:.6f} {lm['y']:.6f} {lm['z']:.6f}\n")
        _atomic_replace(tmp, SHARED_FILE)
    except Exception:
        pass


def write_frame(rgba):
    """Write raw RGBA frame as binary: [w:u32][h:u32][stride:u32][pixels...]"""
    h, w = rgba.shape[:2]
    stride = rgba.strides[0]
    tmp = FRAME_FILE + ".tmp"
    try:
        with open(tmp, 'wb') as f:
            f.write(struct.pack('<III', w, h, stride))
            f.write(rgba.tobytes())
        _atomic_replace(tmp, FRAME_FILE)
    except Exception:
        pass

def _open_camera():
    """Cross-platform camera open.  Tries Windows (DSHOW/MSMF) first on
    Windows, V4L2 first on Linux, then falls back to any-other-index/backend."""
    is_windows = sys.platform.startswith("win")
    attempts = []
    if is_windows:
        for idx in (0, 1, 2):
            attempts.append((idx, cv2.CAP_DSHOW))
        for idx in (0, 1, 2):
            attempts.append((idx, cv2.CAP_MSMF))
        attempts.append((0, None))
    else:
        for idx in (0, 1, 2):
            attempts.append((idx, cv2.CAP_V4L2))
        attempts.append((0, None))

    for idx, backend in attempts:
        try:
            if backend is not None:
                cap = cv2.VideoCapture(idx, backend)
            else:
                cap = cv2.VideoCapture(idx)
            if cap.isOpened():
                ret, test = cap.read()
                if ret and test is not None:
                    backend_name = {cv2.CAP_DSHOW: "DSHOW",
                                    cv2.CAP_MSMF: "MSMF",
                                    cv2.CAP_V4L2: "V4L2",
                                    None: "DEFAULT"}.get(backend, "AUTO")
                    print(f"camera ok: idx={idx} backend={backend_name} shape={test.shape}",
                          flush=True)
                    return cap
                cap.release()
            else:
                cap.release()
        except Exception as e:
            print(f"  try idx={idx} backend={backend}: exception: {e}", flush=True)
            continue
    if sys.platform.startswith("win"):
        print("  all camera attempts failed — check Windows camera privacy settings",
              flush=True)
    else:
        print("  all camera attempts failed — check /dev/video0 permissions or install v4l2",
              flush=True)
    return None


STATUS_FILE = os.path.join(TMP_DIR, "blue_hours_status.txt")


def _write_status(phase, message=""):
    """Write a tiny status file so Lua can check if Python is alive and what
    phase it's in (init|camera_ok|mediapipe_ok|running|error)."""
    try:
        tmp = STATUS_FILE + ".tmp"
        with open(tmp, 'w') as f:
            f.write(f"phase: {phase}\n")
            f.write(f"time: {time.time():.3f}\n")
            f.write(f"msg: {message}\n")
        _atomic_replace(tmp, STATUS_FILE)
    except Exception:
        pass


def _try_create_recognizer():
    """Try to create the MediaPipe gesture recognizer.  Returns (recognizer,
    gesture_available_bool, error_message).  Never crashes - if anything
    fails we return (None, False, "reason") so the camera loop can still
    run in degraded mode."""
    if not os.path.isfile(MODEL_PATH):
        return None, False, f"model missing: {MODEL_PATH}"
    try:
        options = vision.GestureRecognizerOptions(
            base_options=mp.tasks.BaseOptions(model_asset_path=MODEL_PATH),
            running_mode=RunningMode.IMAGE,
            num_hands=1,
            min_hand_detection_confidence=0.5,
            min_hand_presence_confidence=0.5
        )
        recognizer = vision.GestureRecognizer.create_from_options(options)
        return recognizer, True, ""
    except Exception as e:
        return None, False, f"mediapipe init failed: {e}"


def main():
    os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'
    os.environ['GLOG_minloglevel'] = '2'

    print(f"starting gesture_detector (python {sys.version.split()[0]})", flush=True)
    _write_status("init", "starting")

    cap = _open_camera()
    if cap is None:
        write_result(False, "none", 0.0, None)
        _write_status("error", "no camera available")
        print("no camera available (tried DSHOW/MSMF/DEFAULT on indexes 0-2)",
              file=sys.stderr, flush=True)
        sys.exit(1)

    _write_status("camera_ok", "camera opened")

    try:
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        cap.set(cv2.CAP_PROP_FPS, 30)
    except Exception:
        pass

    # --- MediaPipe init (fail gracefully, don't kill the camera loop) ---
    recognizer, mp_ok, mp_msg = _try_create_recognizer()
    if mp_ok:
        _write_status("mediapipe_ok", "gesture model loaded")
    else:
        _write_status("camera_only", mp_msg)
        print(f"[warn] gesture recognition disabled: {mp_msg}", flush=True)

    write_result(False, "none", 0.0, None)
    print("ok", flush=True)

    prev_gray = None
    frame_count = 0
    cached_gesture = "none"
    cached_fist = False
    cached_landmarks = None

    # Initialization done.  Now suppress the noisy C-level stderr chatter
    # from mediapipe / tensorflow lite so Lua's pipe reader only sees our
    # own stdout messages.  Camera/gesture errors go to STATUS_FILE instead.
    try:
        _stderr_fd = sys.stderr.fileno()
        _null = open(os.devnull, 'w')
        os.dup2(_null.fileno(), _stderr_fd)
    except Exception:
        pass

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                time.sleep(0.03)
                continue

            frame_count += 1

            # Motion detection: every frame (cheap)
            try:
                small = cv2.resize(frame, (160, 120), interpolation=cv2.INTER_AREA)
                gray = cv2.cvtColor(small, cv2.COLOR_BGR2GRAY)
                motion_val = 0.0
                if prev_gray is not None:
                    diff = cv2.absdiff(gray, prev_gray)
                    raw = float(np.mean(diff)) / 255.0
                    motion_val = min(raw * 8.0, 1.0)
                prev_gray = gray
            except Exception:
                motion_val = 0.0

            # Gesture recognition: every 2nd frame (only if mediapipe is up)
            if mp_ok and frame_count % 2 == 0:
                try:
                    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
                    result = recognizer.recognize(mp_image)

                    if result.gestures and result.hand_landmarks:
                        gesture = result.gestures[0][0]
                        cached_gesture = gesture.category_name
                        cached_fist = (cached_gesture == "Closed_Fist") or is_fist(
                            [{'x': lm.x, 'y': lm.y, 'z': lm.z}
                             for lm in result.hand_landmarks[0]])
                        cached_landmarks = [{'x': lm.x, 'y': lm.y, 'z': lm.z}
                                            for lm in result.hand_landmarks[0]]
                    else:
                        cached_gesture = "none"
                        cached_fist = False
                        cached_landmarks = None
                except Exception as e:
                    mp_ok = False
                    cached_gesture = "none"
                    cached_landmarks = None
                    _write_status("camera_only", f"mp runtime err: {e}")

            write_result(cached_fist, cached_gesture, motion_val, cached_landmarks)

            # Write camera frame: every frame
            try:
                rgba = cv2.cvtColor(frame, cv2.COLOR_BGR2RGBA)
                write_frame(rgba)
            except Exception:
                pass

            # Heartbeat every 30 frames so Lua can verify we're alive
            if frame_count % 15 == 0:
                phase = "running" if mp_ok else "camera_only"
                _write_status(phase, f"frame={frame_count}")

    except KeyboardInterrupt:
        pass
    except Exception as e:
        _write_status("error", f"main loop: {e}")
    finally:
        try:
            cap.release()
        except Exception:
            pass
        if recognizer is not None:
            try:
                recognizer.close()
            except Exception:
                pass

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"FATAL: unhandled exception: {e}", flush=True)
        print("--- traceback ---", flush=True)
        tb = traceback.format_exc()
        # Sanitize: replace any non-ASCII with '?' for safety
        tb_clean = ''.join(c if ord(c) < 128 else '?' for c in tb)
        print(tb_clean, flush=True)
        try:
            _write_status("error", f"crash: {e}")
        except Exception:
            pass
        sys.exit(1)
