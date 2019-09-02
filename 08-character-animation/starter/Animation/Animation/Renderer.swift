/**
 * Copyright (c) 2018 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import MetalKit

class Renderer: NSObject {
    
    static var device: MTLDevice!
    static var commandQueue: MTLCommandQueue!
    static var colorPixelFormat: MTLPixelFormat!
    static var library: MTLLibrary?
    var depthStencilState: MTLDepthStencilState!
    
    var uniforms = Uniforms()
    var currentTime: Float = 0
    var ballVelocity: Float = 0
    var maxVelocity: Float = 0
    
    lazy var camera: Camera = {
        let camera = Camera()
        camera.position = [0, 1, -3]
        return camera
    }()
    
    var models: [Renderable] = []
    
    init(metalView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("GPU not available")
        }
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.device = device
        Renderer.device = device
        Renderer.commandQueue = device.makeCommandQueue()!
        Renderer.colorPixelFormat = metalView.colorPixelFormat
        Renderer.library = device.makeDefaultLibrary()
        
        super.init()
        metalView.clearColor = MTLClearColor(red: 0.43, green: 0.47,
                                             blue: 0.5, alpha: 1)
        metalView.delegate = self
        mtkView(metalView, drawableSizeWillChange: metalView.bounds.size)
        
        // models
        let ground = Prop(name: "ground")
        ground.scale = [10, 10, 10]
        models.append(ground)
        
        buildDepthStencilState()
    }
    
    func buildDepthStencilState() {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = true
        depthStencilState =
            Renderer.device.makeDepthStencilState(descriptor: descriptor)
    }
}

extension Renderer: MTKViewDelegate {
    
//    func update(deltaTime: Float) {
//        let gravity: Float = 9.8 // meter / sec2
//        let mass: Float = 0.05
//        let acceleration = gravity / mass
//        let airFriction: Float = 0.2
//        let bounciness: Float = 0.9
//        let timeStep: Float = 1 / 600
//
//        currentTime += deltaTime * 4
//        let ball = models[0]
//        ballVelocity += (acceleration * timeStep) / airFriction
//        maxVelocity = max(maxVelocity, abs(ballVelocity))
//
//        ball.position.y -= ballVelocity * timeStep
//        if ball.position.y <= ball.size.y / 2 {
//            ball.position.y = ball.size.y / 2
//            ballVelocity = ballVelocity * -1 * bounciness
//            ball.scale.y = max(0.5, 1 - 0.8 * abs(ballVelocity) / maxVelocity)
//            ball.scale.z = 1 + (1 - ball.scale.y) / 2
//            ball.scale.x = ball.scale.z
//        }
//
//        if ball.scale.y < 1 {
//            let change: Float = 0.07
//            ball.scale.y += change
//            ball.scale.z -= change / 2
//            ball.scale.x = ball.scale.z
//            if ball.scale.y > 1 {
//                ball.scale = [1, 1, 1]
//            }
//        }
//    }
    
    func update(deltaTime: Float) {
        for model in models {
            model.update(deltaTime: deltaTime)
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        camera.aspect = Float(view.bounds.width)/Float(view.bounds.height)
    }
    
    func draw(in view: MTKView) {
        guard let descriptor = view.currentRenderPassDescriptor,
            let commandBuffer = Renderer.commandQueue.makeCommandBuffer(),
            let renderEncoder =
            commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                return
        }
        renderEncoder.setDepthStencilState(depthStencilState)
        
        uniforms.projectionMatrix = camera.projectionMatrix
        uniforms.viewMatrix = camera.viewMatrix
        
        let deltaTime = 1.0 / Float(view.preferredFramesPerSecond)
        update(deltaTime: deltaTime)
        
        for model in models {
            renderEncoder.pushDebugGroup(model.name)
            model.render(renderEncoder: renderEncoder, uniforms: uniforms)
            renderEncoder.popDebugGroup()
        }
        
        renderEncoder.endEncoding()
        guard let drawable = view.currentDrawable else {
            return
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}


