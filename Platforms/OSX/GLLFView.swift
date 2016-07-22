import GLUT
import OpenGL.GL3
import Foundation
import AVFoundation

public class GLLFView: NSOpenGLView {
    static let pixelFormatAttributes: [NSOpenGLPixelFormatAttribute] = [
        UInt32(NSOpenGLPFAAccelerated),
        UInt32(NSOpenGLPFANoRecovery),
        UInt32(NSOpenGLPFAColorSize), UInt32(32),
        UInt32(NSOpenGLPFAAllowOfflineRenderers),
        UInt32(0)
    ]

    override public class func defaultPixelFormat() -> NSOpenGLPixelFormat {
        guard let pixelFormat:NSOpenGLPixelFormat = NSOpenGLPixelFormat(attributes: GLLFView.pixelFormatAttributes) else {
            return NSOpenGLPixelFormat()
        }
        return pixelFormat
    }

    public var videoGravity:String! = AVLayerVideoGravityResizeAspect
    var orientation:AVCaptureVideoOrientation = .Portrait
    var position:AVCaptureDevicePosition = .Front
    private var displayImage:CIImage!
    private var ciContext:CIContext!
    private weak var currentStream:Stream?

    public override func prepareOpenGL() {
        if let openGLContext:NSOpenGLContext = openGLContext {
            ciContext = CIContext(
                CGLContext: openGLContext.CGLContextObj,
                pixelFormat: openGLContext.pixelFormat.CGLPixelFormatObj,
                colorSpace: nil,
                options: nil
            )
        }
        var param:GLint = 1
        openGLContext?.setValues(&param, forParameter: .GLCPSwapInterval)
        glDisable(GLenum(GL_ALPHA_TEST))
        glDisable(GLenum(GL_DEPTH_TEST))
        glDisable(GLenum(GL_SCISSOR_TEST))
        glDisable(GLenum(GL_BLEND))
        glDisable(GLenum(GL_DITHER))
        glDisable(GLenum(GL_CULL_FACE))
        glColorMask(GLboolean(GL_TRUE), GLboolean(GL_TRUE), GLboolean(GL_TRUE), GLboolean(GL_TRUE))
        glDepthMask(GLboolean(GL_FALSE))
        glStencilMask(0)
        glClearColor(0.0, 0.0, 0.0, 1.0)
        glHint(GLenum(GL_TRANSFORM_HINT_APPLE), GLenum(GL_FASTEST))
    }

    public override func drawRect(dirtyRect: NSRect) {
        guard let
            image:CIImage = displayImage,
            glContext:NSOpenGLContext = openGLContext else {
            return
        }

        let integral:CGRect = CGRectIntegral(dirtyRect)
        var inRect:CGRect = CGRectIntersection(CGRectInset(integral, -1.0, -1.0), frame)
        var fromRect:CGRect = image.extent

        glContext.makeCurrentContext()
        glClear(GLenum(GL_COLOR_BUFFER_BIT))

        glScissor(GLint(integral.origin.x), GLint(integral.origin.y), GLint(integral.size.width), GLint(integral.size.height))
        glBlendFunc(GLenum(GL_SRC_ALPHA), GLenum(GL_ONE_MINUS_SRC_ALPHA))
        glEnable(GLenum(GL_BLEND))
        VideoGravityUtil.calclute(videoGravity, inRect: &inRect, fromRect: &fromRect)
        ciContext.drawImage(image, inRect: inRect, fromRect: fromRect)
        glDisable(GLenum(GL_BLEND))

        glFlush()
    }

    override public func reshape() {
        let rect:CGRect = self.frame
        glViewport(0, 0, Int32(rect.width), Int32(rect.height))
        glMatrixMode(GLenum(GL_PROJECTION))
        glLoadIdentity()
        glOrtho(0, GLdouble(rect.size.width), 0, GLdouble(rect.size.height), -1, 1)
        glMatrixMode(GLenum(GL_MODELVIEW))
        glLoadIdentity()
    }

    public func attachStream(stream: Stream?) {
        if let currentStream:Stream = currentStream {
            currentStream.mixer.videoIO.drawable = nil
        }
        if let stream:Stream = stream {
            stream.mixer.videoIO.drawable = self
        }
        currentStream = stream
    }
}

// MARK: - StreamDrawable
extension GLLFView: StreamDrawable {
    func render(image: CIImage, toCVPixelBuffer: CVPixelBuffer) {
        ciContext.render(image, toCVPixelBuffer: toCVPixelBuffer)
    }

    func drawImage(image:CIImage) {
        displayImage = image
        dispatch_async(dispatch_get_main_queue()) {
            self.needsDisplay = true
        }
    }
}
