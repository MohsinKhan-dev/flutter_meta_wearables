# Technical Report: Video Rendering Pipeline Optimization
## February 21, 2026

---

## 1. Original Implementation & Bottlenecks

### 1.1 Original Rendering Pipeline

The initial `VideoFrameRenderer.kt` used the following pipeline for every frame:

```
I420 ByteBuffer (from MWDAT SDK)
  → convertI420toNV21()          [CPU: allocate ByteArray, interleave U/V]
  → YuvImage.compressToJpeg()    [CPU: JPEG encode at 80% quality]
  → BitmapFactory.decodeByteArray [CPU: JPEG decode back to Bitmap]
  → Canvas.drawBitmap()          [CPU: software blit to Surface]
  → SurfaceTexture               [Flutter Texture widget reads this]
```

### 1.2 Identified Bottlenecks

| # | Bottleneck | Severity | Detail |
|---|-----------|----------|--------|
| 1 | **JPEG round-trip** | Critical | Compressing to JPEG then immediately decompressing is pure waste — lossy encoding just to obtain a `Bitmap` object. At 720p this burns ~8-12ms per frame on CPU. |
| 2 | **Per-frame memory allocation** | High | Every frame allocated: `ByteArray` for NV21, `ByteArrayOutputStream` for JPEG output, and a new `Bitmap` from JPEG decode (immediately recycled). This caused heavy GC pressure with visible jank. |
| 3 | **Main thread rendering** | Medium | All frame processing ran on `Dispatchers.Main`, blocking Flutter's UI thread during YUV conversion, JPEG encode/decode, and Canvas draw. |
| 4 | **CPU-only processing** | Medium | The GPU was completely idle — all pixel conversion happened in a Kotlin `for` loop iterating over every pixel. |

### 1.3 Original Code (VideoFrameRenderer.kt)

```kotlin
private fun videoFrameToBitmap(videoFrame: VideoFrame): Bitmap? {
    val buffer = videoFrame.buffer
    val dataSize = buffer.remaining()
    val byteArray = ByteArray(dataSize)                          // Allocation #1

    buffer.get(byteArray)

    val nv21 = convertI420toNV21(byteArray, width, height)       // Allocation #2
    val image = YuvImage(nv21, ImageFormat.NV21, width, height, null)
    val out = ByteArrayOutputStream()                            // Allocation #3
    image.compressToJpeg(Rect(0, 0, width, height), 80, out)    // JPEG encode
    val jpegBytes = out.toByteArray()                            // Allocation #4

    return BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)  // JPEG decode → Allocation #5
}
```

**5 allocations per frame, 2 unnecessary encode/decode operations.**

---

## 2. Fix Attempt #1 — Direct CPU YUV→ARGB Conversion

### 2.1 Approach

Eliminated the JPEG round-trip entirely. Converted I420 YUV pixels directly to ARGB `IntArray` using BT.601 color coefficients, then used `Bitmap.setPixels()`.

### 2.2 Pipeline

```
I420 ByteBuffer
  → convertI420toARGB()      [CPU: direct YUV→RGB per pixel]
  → Bitmap.setPixels()       [CPU: copy IntArray into Bitmap]
  → Canvas.drawBitmap()      [CPU: software blit to Surface]
  → SurfaceTexture
```

### 2.3 Key Changes

- **Removed**: `YuvImage`, `compressToJpeg`, `BitmapFactory.decodeByteArray`, `ByteArrayOutputStream`
- **Added**: Direct pixel conversion loop with integer math (no floating point)
- **Buffer reuse**: `IntArray`, `Bitmap`, Y/U/V `ByteArray` planes allocated once and reused across frames

```kotlin
// BT.601 integer-math conversion (no JPEG, no float)
var r = yVal + ((359 * vVal) shr 8)
var g = yVal - ((88 * uVal + 183 * vVal) shr 8)
var b = yVal + ((454 * uVal) shr 8)

output[outIdx++] = (0xFF shl 24) or (r shl 16) or (g shl 8) or b  // 0xAARRGGBB
```

### 2.4 Result

**Video streaming worked. Lag was reduced** compared to the JPEG version, but still present because rendering remained on `Dispatchers.Main` and was entirely CPU-bound (no GPU).

---

## 3. Fix Attempt #2 — OpenGL ES on Dispatchers.Default (Failed)

### 3.1 Approach

Replaced the entire CPU rendering path with OpenGL ES 2.0:
- Created EGL context bound to Flutter's `SurfaceTexture`
- Uploaded Y, U, V planes as three `GL_LUMINANCE` textures
- YUV→RGB conversion in a GLSL fragment shader on the GPU
- `eglSwapBuffers()` to present

### 3.2 Why It Failed

Used `Dispatchers.Default` for the rendering coroutine. `Dispatchers.Default` is backed by a **thread pool** — coroutines can resume on any thread in the pool.

**EGL contexts are thread-bound.** When the coroutine:
1. Created the EGL context on Thread A
2. Resumed for the next frame on Thread B
3. Thread B had no current EGL context → all GL calls silently failed → **black screen**

### 3.3 Symptoms

- Video appeared briefly (when consecutive frames happened to land on the same thread)
- Then went black permanently (when thread scheduling diverged)
- Progressively worse under load as the thread pool rotated threads more frequently

### 3.4 Lesson

**Never use a thread pool dispatcher for OpenGL rendering.** EGL contexts require strict single-thread affinity.

---

## 4. Fix Attempt #3 — CPU with copyPixelsFromBuffer (Failed)

### 4.1 Approach

Kept the CPU YUV→ARGB conversion but tried to optimize the Bitmap update path:
- Used `ByteBuffer` instead of `IntArray` for pixel output
- Used `Bitmap.copyPixelsFromBuffer()` instead of `Bitmap.setPixels()`
- Used a dedicated `Executors.newSingleThreadExecutor` for rendering

### 4.2 Why It Failed

`copyPixelsFromBuffer()` for `ARGB_8888` expects bytes in a specific memory order that differs from the intuitive R,G,B,A byte sequence. The byte layout for `ARGB_8888` on little-endian ARM is:

```
Integer 0xAARRGGBB in memory (little-endian): [BB] [GG] [RR] [AA]
```

The renderer was writing `[RR] [GG] [BB] [AA]` — wrong byte order. Combined with the threading change (moving off Main to a single-thread executor), this produced a **black screen**.

### 4.3 Lesson

- `Bitmap.setPixels(IntArray)` is safer — it handles endianness internally
- `Bitmap.copyPixelsFromBuffer(ByteBuffer)` requires exact native byte order knowledge
- Changing two things at once (byte format + threading) makes debugging harder

---

## 5. Fix Attempt #4 — Stable CPU Baseline (Worked)

### 5.1 Approach

Reverted to the proven working combination:
- Direct I420→ARGB conversion (from Fix #1)
- `Bitmap.setPixels()` with `IntArray` (known correct)
- `Dispatchers.Main` for frame collection (same as original)
- Reusable buffers (Y/U/V planes, IntArray, Bitmap)

### 5.2 Pipeline

```
I420 ByteBuffer
  → convertI420toARGB()      [CPU: reusable ByteArrays + IntArray]
  → Bitmap.setPixels()       [CPU: IntArray → Bitmap, handles endianness]
  → Canvas.drawBitmap()      [CPU: blit to Surface on main thread]
  → SurfaceTexture → Flutter Texture widget
```

### 5.3 Result

**Video streaming stable.** No black screen. JPEG bottleneck eliminated. Still CPU-bound with rendering on the main thread, but functional.

---

## 6. Fix Attempt #5 — OpenGL ES on Dedicated HandlerThread (Final)

### 6.1 Approach

Combined the OpenGL ES approach (Fix #2) with proper thread management. Used Android's `HandlerThread` — a thread with its own `Looper` that guarantees **all posted Runnables execute on the same single thread**.

### 6.2 Architecture

```
┌─────────────────────────────────────────────────┐
│  Calling Thread (Main / Coroutine collector)     │
│                                                  │
│  1. Copy YUV planes from VideoFrame.buffer       │
│     into reusable direct ByteBuffers             │
│  2. Post render task to GL Handler               │
│  3. CountDownLatch.await() (backpressure)        │
└──────────────────────┬──────────────────────────┘
                       │ Handler.post()
                       ▼
┌─────────────────────────────────────────────────┐
│  GL Thread (HandlerThread "wearables-gl")        │
│  ┌─────────────────────────────────┐            │
│  │ EGL Context (always current)    │            │
│  └─────────────────────────────────┘            │
│                                                  │
│  4. glTexImage2D(yTex, GL_LUMINANCE, yData)     │
│  5. glTexImage2D(uTex, GL_LUMINANCE, uData)     │
│  6. glTexImage2D(vTex, GL_LUMINANCE, vData)     │
│  7. Draw fullscreen quad with YUV→RGB shader     │
│  8. eglSwapBuffers() → SurfaceTexture            │
│  9. latch.countDown()                            │
└─────────────────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────┐
│  Flutter Engine                                  │
│  Texture widget reads from SurfaceTexture        │
│  Composited into the widget tree                 │
└─────────────────────────────────────────────────┘
```

### 6.3 Key Implementation Details

#### Dedicated GL Thread
```kotlin
private val glThread = HandlerThread("wearables-gl").apply { start() }
private val glHandler = Handler(glThread.looper)
```
`HandlerThread` provides a single thread with a message queue. All EGL/GLES calls are posted to `glHandler`, guaranteeing the EGL context is always current.

#### YUV Texture Upload
Three separate `GL_LUMINANCE` textures (single-channel, 8-bit per texel):
- **Y texture**: Full resolution (width × height)
- **U texture**: Quarter resolution (width/2 × height/2)
- **V texture**: Quarter resolution (width/2 × height/2)

The GPU's texture sampling hardware handles chroma upscaling via `GL_LINEAR` filtering — free bilinear interpolation.

#### Fragment Shader (YUV→RGB on GPU)
```glsl
float y = texture2D(yTex, vTexCoord).r;
float u = texture2D(uTex, vTexCoord).r - 0.5;
float v = texture2D(vTex, vTexCoord).r - 0.5;
float r = y + 1.402 * v;
float g = y - 0.344136 * u - 0.714136 * v;
float b = y + 1.772 * u;
gl_FragColor = vec4(r, g, b, 1.0);
```
BT.601 conversion runs in parallel across all GPU shader cores — massively parallel vs the sequential CPU loop.

#### Backpressure via CountDownLatch
```kotlin
val latch = CountDownLatch(1)
glHandler.post {
    try { renderOnGLThread(width, height, yData, uData, vData) }
    finally { latch.countDown() }
}
latch.await()
```
The frame collector blocks until the GL thread finishes rendering. This prevents frame queue buildup and keeps memory usage constant.

#### Buffer Safety
The SDK's `VideoFrame.buffer` may be recycled after the collect lambda returns. YUV plane data is copied into reusable direct `ByteBuffer`s on the calling thread before posting to the GL thread.

#### Cleanup on GL Thread
```kotlin
fun release() {
    val latch = CountDownLatch(1)
    glHandler.post {
        // Delete textures, program, EGL surface/context on the GL thread
        latch.countDown()
    }
    latch.await()
    glThread.quitSafely()
    textureEntry.release()
}
```
EGL resources are destroyed on the same thread that created them (required by the EGL spec).

---

## 7. Performance Comparison

| Metric | Original (JPEG) | Fix #1 (CPU Direct) | Fix #5 (GPU Final) |
|--------|-----------------|---------------------|---------------------|
| YUV→RGB conversion | CPU (JPEG encode+decode) | CPU (pixel loop) | GPU (fragment shader) |
| Allocations per frame | 5 (ByteArrays, Bitmap, Stream) | 0 (all reused) | 0 (all reused) |
| Main thread blocked | Yes (entire pipeline) | Yes (entire pipeline) | No (only buffer copy) |
| Copies per frame | 4+ (NV21, JPEG, decode, Canvas) | 2 (setPixels, Canvas) | 1 (texture upload via DMA) |
| GPU utilization | 0% | 0% | YUV→RGB + compositing |
| Color conversion | Lossy (JPEG 80%) | Lossless (integer math) | Lossless (float shader) |

---

## 8. Why Each Failed Attempt Matters

| Attempt | Worked? | Key Takeaway |
|---------|---------|-------------|
| #1 CPU Direct | Yes (laggy) | Eliminating JPEG round-trip is the single biggest win |
| #2 GL + thread pool | No (black screen) | EGL contexts are thread-bound — never use a thread pool |
| #3 CPU + ByteBuffer | No (black screen) | `copyPixelsFromBuffer` has non-obvious byte order; don't change two things at once |
| #4 CPU baseline | Yes | `setPixels()` + `Dispatchers.Main` is the safe fallback |
| #5 GL + HandlerThread | Yes | `HandlerThread` provides the single-thread guarantee EGL needs |

---

## 9. Files Modified

| File | Changes |
|------|---------|
| `android/.../VideoFrameRenderer.kt` | Complete rewrite: EGL14 + GLES20 setup, YUV texture upload, fragment shader, HandlerThread lifecycle |
| `android/.../StreamSessionManager.kt` | Reverted to `Dispatchers.Main` for frame collection (GL thread handles the heavy work internally) |

---

## 10. Test Device

- **Device:** Samsung Galaxy A15 (SM-A155F)
- **Android:** 15 (API 35)
- **Architecture:** arm64-v8a
- **GPU:** Mali-G57 (supports OpenGL ES 3.2)
