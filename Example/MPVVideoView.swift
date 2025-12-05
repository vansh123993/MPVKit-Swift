import SwiftUI
import AppKit
import OpenGL.GL
import MPVKit
import Combine

// MARK: - SwiftUI View
struct MPVVideoView: NSViewControllerRepresentable {
    @ObservedObject var controller: MPVController
    
    func makeNSViewController(context: Context) -> MPVViewController {
        let mpv = MPVViewController()
        context.coordinator.player = mpv
        controller.playerView = mpv // Link controller to view
        mpv.delegate = controller // Link view to controller
        return mpv
    }
    
    func updateNSViewController(_ nsViewController: MPVViewController, context: Context) {
        // Updates handled via controller
    }
    
    static func dismantleNSViewController(_ nsViewController: MPVViewController, coordinator: Coordinator) {
        nsViewController.glView.cleanup()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: MPVVideoView
        weak var player: MPVViewController?
        
        init(_ parent: MPVVideoView) {
            self.parent = parent
        }
    }
}

// MARK: - Controller
class MPVController: ObservableObject {
    @Published var isPlaying = false
    @Published var progress: Double = 0.0
    @Published var duration: Double = 0.0
    @Published var timePos: Double = 0.0
    @Published var volume: Double = 1.0
    
    weak var playerView: MPVViewController?
    
    func play(url: URL) {
        playerView?.play(url)
        isPlaying = true
    }
    
    func play() {
        playerView?.resume()
        isPlaying = true
    }
    
    func pause() {
        playerView?.pause()
        isPlaying = false
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to value: Double) {
        playerView?.seek(to: value)
    }
    
    func setVolume(_ value: Double) {
        playerView?.setVolume(value)
        volume = value
    }
    
    func updateProgress(_ value: Double) {
        DispatchQueue.main.async {
            self.progress = value
        }
    }
    
    func handlePropertyChange(name: String, value: Any) {
        DispatchQueue.main.async {
            switch name {
            case "time-pos":
                if let time = value as? Double {
                    self.timePos = time
                    if self.duration > 0 {
                        self.progress = time / self.duration
                    }
                }
            case "duration":
                if let dur = value as? Double {
                    self.duration = dur
                }
            case "pause":
                if let paused = value as? Bool {
                    self.isPlaying = !paused
                }
            case "volume":
                if let vol = value as? Double {
                    self.volume = vol / 100.0
                }
            default:
                break
            }
        }
    }
}

// MARK: - View Controller
class MPVViewController: NSViewController {
    var glView: MPVOGLView!
    weak var delegate: MPVController?
    
    override func loadView() {
        self.view = NSView(frame: .init(x: 0, y: 0, width: 1280, height: 720))
        self.glView = MPVOGLView(frame: self.view.bounds)
        // self.glView.wantsLayer = true // CAUSES BLACK SCREEN WITH OPENGL
        self.glView.autoresizingMask = [.width, .height]
        self.view.addSubview(glView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.glView.setupContext()
        self.glView.setupMpv()
        
        self.glView.onPropertyChange = { [weak self] name, value in
            self?.delegate?.handlePropertyChange(name: name, value: value)
        }
    }
    
    func play(_ url: URL) {
        glView.loadFile(url)
    }
    
    func pause() {
        glView.setPause(true)
    }
    
    func resume() {
        glView.setPause(false)
    }
    
    func seek(to percent: Double) {
        glView.seek(to: percent)
    }
    
    func setVolume(_ value: Double) {
        glView.setVolume(value)
    }
}

// MARK: - OpenGL View & MPV Backend
// MARK: - OpenGL View & MPV Backend
// MARK: - OpenGL View & MPV Backend
// MARK: - OpenGL View & MPV Backend
final class MPVOGLView: NSOpenGLView {
    var mpv: OpaquePointer!
    var mpvGL: OpaquePointer!
    var queue = DispatchQueue(label: "mpv", qos: .userInteractive)
    private var defaultFBO: GLint = 0
    var onPropertyChange: ((String, Any) -> Void)?
    
    override class func defaultPixelFormat() -> NSOpenGLPixelFormat {
        let attributes: [NSOpenGLPixelFormatAttribute] = [
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAOpenGLProfile),
            NSOpenGLPixelFormatAttribute(NSOpenGLProfileVersion4_1Core), // Request Core 4.1
            NSOpenGLPixelFormatAttribute(NSOpenGLPFADoubleBuffer),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFAColorSize), NSOpenGLPixelFormatAttribute(32),
            NSOpenGLPixelFormatAttribute(NSOpenGLPFADepthSize), NSOpenGLPixelFormatAttribute(24),
            NSOpenGLPixelFormatAttribute(0)
        ]
        return NSOpenGLPixelFormat(attributes: attributes)!
    }
    
    override func reshape() {
        super.reshape()
        let size = self.bounds.size
        // Ensure we update the viewport and render when resized
        renderFrame()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        renderFrame()
    }
    
    func setupContext() {
        self.openGLContext = NSOpenGLContext(format: MPVOGLView.defaultPixelFormat(), share: nil)
        self.openGLContext?.view = self
        self.openGLContext?.makeCurrentContext()
    }
    
    func setupMpv() {
        mpv = mpv_create()
        if mpv == nil {
            print("failed creating context")
            return
        }
        
        // Force libmpv to use the render API and not create its own window
        let vo = "libmpv"
        if mpv_set_option_string(mpv, "vo", vo) < 0 {
            print("Failed to set vo=libmpv")
        }
        
        // Force window creation immediately
        mpv_set_option_string(mpv, "force-window", "immediate")
        
        // High Quality Rendering (IINA-like)
        mpv_set_option_string(mpv, "profile", "gpu-hq")
        mpv_set_option_string(mpv, "scale", "ewa_lanczossharp")
        mpv_set_option_string(mpv, "cscale", "ewa_lanczossharp")
        
        // Smooth Motion (Interpolation)
        mpv_set_option_string(mpv, "video-sync", "display-resample")
        mpv_set_option_string(mpv, "interpolation", "yes")
        mpv_set_option_string(mpv, "tscale", "oversample")
        
        // Color Management
        mpv_set_option_string(mpv, "target-prim", "auto")
        mpv_set_option_string(mpv, "target-trc", "auto")
        mpv_set_option_string(mpv, "icc-profile-auto", "yes")
        
        // Enable hardware decoding
        let hwdec = "auto-safe"
        if mpv_set_option_string(mpv, "hwdec", hwdec) < 0 {
            print("Failed to set hwdec=auto-safe")
        }
        
        // Enable verbose logging
        let msgLevel = "all=warn"
        mpv_set_option_string(mpv, "msg-level", msgLevel)
        
        // Enable terminal output
        mpv_set_option_string(mpv, "terminal", "yes")
        
        // Optimize cache for streaming
        mpv_set_option_string(mpv, "cache", "yes")
        mpv_set_option_string(mpv, "demuxer-max-bytes", "128MiB")
        mpv_set_option_string(mpv, "demuxer-max-back-bytes", "50MiB")
        mpv_set_option_string(mpv, "demuxer-readahead-secs", "5.0")
        
        // Observe properties
        mpv_observe_property(mpv, 0, "time-pos", MPV_FORMAT_DOUBLE)
        mpv_observe_property(mpv, 0, "duration", MPV_FORMAT_DOUBLE)
        mpv_observe_property(mpv, 0, "pause", MPV_FORMAT_FLAG)
        mpv_observe_property(mpv, 0, "volume", MPV_FORMAT_DOUBLE)
        
        if mpv_initialize(mpv) < 0 {
            print("mpv init failed")
            return
        }
        
        // Use a global function or a closure with correct signature
        let getProcAddress: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?) -> UnsafeMutableRawPointer? = { ctx, name in
            guard let name = name else { return nil }
            let symbolName = CFStringCreateWithCString(kCFAllocatorDefault, name, CFStringBuiltInEncodings.ASCII.rawValue)
            let identifier = CFBundleGetBundleWithIdentifier("com.apple.opengl" as CFString)
            let ptr = CFBundleGetFunctionPointerForName(identifier, symbolName)
            // print("getProcAddress: \(String(cString: name)) -> \(String(describing: ptr))")
            return ptr
        }
        
        var initParams = mpv_opengl_init_params(
            get_proc_address: getProcAddress,
            get_proc_address_ctx: nil
        )
        
        "opengl".withCString { api in
            withUnsafeMutablePointer(to: &initParams) { initParamsPtr in
                var params = [
                    mpv_render_param(type: MPV_RENDER_PARAM_API_TYPE, data: UnsafeMutableRawPointer(mutating: api)),
                    mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, data: initParamsPtr),
                    mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil)
                ]
                
                if mpv_render_context_create(&mpvGL, mpv, &params) < 0 {
                    print("failed to initialize mpv GL context")
                    return
                }
            }
        }
        
        mpv_render_context_set_update_callback(
            mpvGL,
            mpvGLUpdate,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )
        
        mpv_set_wakeup_callback(self.mpv, mpvWakeUp, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
    }
    
    func loadFile(_ url: URL) {
        let path = url.absoluteString
        withCStrings(["loadfile", path]) { args in
            var mutableArgs = args
            mutableArgs.withUnsafeMutableBufferPointer { buffer in
                _ = mpv_command(mpv, buffer.baseAddress)
            }
        }
    }
    
    func setPause(_ paused: Bool) {
        let value = paused ? "yes" : "no"
        mpv_set_property_string(mpv, "pause", value)
    }
    
    func seek(to percent: Double) {
        let percentString = String(format: "%.0f", percent * 100)
        withCStrings(["seek", percentString, "absolute-percent"]) { args in
            var mutableArgs = args
            mutableArgs.withUnsafeMutableBufferPointer { buffer in
                _ = mpv_command(mpv, buffer.baseAddress)
            }
        }
    }
    
    func setVolume(_ value: Double) {
        let vol = value * 100
        var doubleVal = vol
        mpv_set_property(mpv, "volume", MPV_FORMAT_DOUBLE, &doubleVal)
    }
    
    func readEvents() {
        queue.async {
            while self.mpv != nil {
                let event = mpv_wait_event(self.mpv, 0)
                if event!.pointee.event_id == MPV_EVENT_NONE {
                    break
                }
                
                if event!.pointee.event_id == MPV_EVENT_PROPERTY_CHANGE {
                    let prop = event!.pointee.data.assumingMemoryBound(to: mpv_event_property.self)
                    let name = String(cString: prop.pointee.name)
                    
                    if prop.pointee.format == MPV_FORMAT_DOUBLE {
                        let value = prop.pointee.data.assumingMemoryBound(to: Double.self).pointee
                        self.onPropertyChange?(name, value)
                    } else if prop.pointee.format == MPV_FORMAT_FLAG {
                        let value = prop.pointee.data.assumingMemoryBound(to: Int32.self).pointee != 0
                        self.onPropertyChange?(name, value)
                    }
                }
            }
        }
    }
    
    func renderFrame() {
        guard let ctx = self.openGLContext else { return }
        guard mpvGL != nil else { return }
        
        ctx.makeCurrentContext()
        
        // Explicitly set viewport to backing size
        let backingRect = self.convertToBacking(self.bounds)
        let width = GLsizei(backingRect.width)
        let height = GLsizei(backingRect.height)
        glViewport(0, 0, width, height)
        
        var flipY: Int32 = 1 // Flip Y for OpenGL
        
        // Correctly construct mpv_opengl_fbo struct
        // fbo: 0 (default), w: width, h: height, internal_format: 0 (unknown/default)
        var fbo = mpv_opengl_fbo(fbo: 0, w: Int32(width), h: Int32(height), internal_format: 0)
        
        withUnsafeMutablePointer(to: &fbo) { fboPtr in
            withUnsafeMutablePointer(to: &flipY) { flipPtr in
                var params = [
                    mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_FBO, data: fboPtr),
                    mpv_render_param(type: MPV_RENDER_PARAM_FLIP_Y, data: flipPtr),
                    mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil)
                ]
                
                mpv_render_context_render(mpvGL, &params)
            }
        }
        ctx.flushBuffer()
    }
    
    func cleanup() {
        if mpvGL != nil {
            mpv_render_context_free(mpvGL)
            mpvGL = nil
        }
        if mpv != nil {
            mpv_terminate_destroy(mpv)
            mpv = nil
        }
    }
    
    deinit {
        cleanup()
    }
    
    // Helper to convert [String] to [UnsafePointer<CChar>?]
    private func withCStrings(_ strings: [String], block: ([UnsafePointer<CChar>?]) -> Void) {
        var cStrings: [UnsafePointer<CChar>?] = []
        var keepAlive: [Any] = [] 
        
        for string in strings {
            let utf8 = string.utf8CString
            let count = utf8.count
            let ptrCopy = UnsafeMutablePointer<CChar>.allocate(capacity: count)
            
            // Correctly access the buffer of the ContiguousArray
            utf8.withUnsafeBufferPointer { buffer in
                if let base = buffer.baseAddress {
                    ptrCopy.initialize(from: base, count: count)
                }
            }
            
            cStrings.append(UnsafePointer(ptrCopy))
            keepAlive.append(ptrCopy)
        }
        cStrings.append(nil) // Null terminator
        
        block(cStrings)
        
        // Cleanup
        for case let ptr as UnsafeMutablePointer<CChar> in keepAlive {
            ptr.deallocate()
        }
    }
}

func mpvGLUpdate(_ ctx: UnsafeMutableRawPointer?) {
    let glView = unsafeBitCast(ctx, to: MPVOGLView.self)
    DispatchQueue.main.async {
        glView.renderFrame()
    }
}

func mpvWakeUp(_ ctx: UnsafeMutableRawPointer?) {
    let glView = unsafeBitCast(ctx, to: MPVOGLView.self)
    glView.readEvents()
}
