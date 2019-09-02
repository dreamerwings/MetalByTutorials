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
    
    var depthStencilState: MTLDepthStencilState
    
    var uniforms = Uniforms()
    
    var fragmentUniforms = FragmentUniforms()
    
    // Camera holds view and projection matrices
    lazy var camera: Camera = {
        let camera = Camera()
        camera.position = [0, 0.5, -3]
        return camera
    }()
    
    // Array of Models allows for rendering multiple models
    var models: [Model] = []
    
    var lights = [Light]()
    
    lazy var sunlight: Light = {
        var light = buildDefaultLight()
        light.position = [0, 5, -10]
        return light
    }()
    
    lazy var ambientlight: Light = {
        var light = buildDefaultLight()
        light.color = [1.0, 0, 0]
        light.intensity = 0.3
        light.type = Ambientlight
        return light
    }()
    
    lazy var greenLight: Light = {
       var light = buildDefaultLight()
        light.color = [0.0, 1.0, 0.0]
        light.position = [0, 0.5, -0.5]
        light.attenuation = [1.0, 3, 4]
        light.type = Pointlight
        return light
    }()
    
    lazy var spotLight: Light = {
        var light = buildDefaultLight()
        light.position = [0.4, 0.8, 1]
        light.color = [1, 0, 1]
        light.attenuation = float3(1, 0.5, 0)
        light.type = Spotlight
        light.coneAngle = radians(fromDegrees: 40)
        light.coneDirection = [-2, 0, -1.5]
        light.coneAttenuation = 12
        return light
    }()
    
    // Debug drawing of lights
    lazy var lightPipelineState: MTLRenderPipelineState = {
        return buildLightPipelineState()
    }()
    
    init(metalView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("GPU not available")
        }
        metalView.device = device
        metalView.depthStencilPixelFormat = .depth32Float
        
        Renderer.device = device
        Renderer.commandQueue = device.makeCommandQueue()!
        Renderer.colorPixelFormat = metalView.colorPixelFormat
        Renderer.library = device.makeDefaultLibrary()
        
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = true
        depthStencilState = device.makeDepthStencilState(descriptor: descriptor)!
        
        super.init()
        metalView.clearColor = MTLClearColor(red: 0.2, green: 0.2,
                                             blue: 0.3, alpha: 1)
        metalView.delegate = self
        mtkView(metalView, drawableSizeWillChange: metalView.bounds.size)
        
        // add model to the scene
        let train = Model(name: "train")
        train.position = [0, 0, 0]
        models.append(train)
        
        let tree = Model(name: "treefir")
        tree.position = [1.4, 0, 0]
        models.append(tree)
        
        lights.append(sunlight)
        lights.append(ambientlight)
        lights.append(greenLight)
        lights.append(spotLight)
        fragmentUniforms.lightCount = UInt32(lights.count)
    }
    
    func buildDefaultLight() -> Light {
        var light = Light()
        light.position = [0, 0, 0]
        light.color = [1, 1, 1]
        light.specularColor = [0.6, 0.6, 0.6]
        light.intensity = 1
        light.attenuation = float3(1, 0, 0)
        light.type = Sunlight
        return light
    }
    
    func changeSpotlight() {
        
        struct ModeParams {
            var attenuation: Float
            var coneAngle: Float
            var color: float3
        }
        
        let mode1 = ModeParams(attenuation: 12, coneAngle: 45, color: [0.9, 1.0, 0.0])
        let mode2 = ModeParams(attenuation: 1, coneAngle: 20, color: [0.0, 1.0, 1.0])
        let mode3 = ModeParams(attenuation: 1000, coneAngle: 10, color: [1.0, 0.0, 0.0])
        let mode4 = ModeParams(attenuation: 1, coneAngle: 45, color: [0, 0.5, 0.8])
        let mode5 = ModeParams(attenuation: Float(arc4random() % 500), coneAngle: Float(arc4random() % 120), color: [Float(arc4random() % 255) / 255.0, Float(arc4random() % 255) / 255.0, Float(arc4random() % 255) / 255.0])
        let modes = [mode1, mode2, mode3, mode4, mode5]
        let mode = modes[Int(arc4random()) % modes.count]
        spotLight.coneAttenuation = mode.attenuation
        spotLight.color = mode.color
        spotLight.coneAngle = radians(fromDegrees: mode.coneAngle)
        lights[lights.count - 1] = spotLight
    }
}

extension Renderer: MTKViewDelegate {
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
        
        view.depthStencilPixelFormat = .depth32Float
        
        uniforms.projectionMatrix = camera.projectionMatrix
        uniforms.viewMatrix = camera.viewMatrix
        fragmentUniforms.cameraPosition = camera.position
        
        renderEncoder.setDepthStencilState(depthStencilState)
        
        renderEncoder.setFragmentBytes(&lights, length: MemoryLayout<Light>.stride * lights.count, index: 0)
        renderEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout<FragmentUniforms>.stride, index: 1)
        
        // render all the models in the array
        for model in models {
            // model matrix now comes from the Model's superclass: Node
            uniforms.modelMatrix = model.modelMatrix
            uniforms.normalMatrix = float3x3(normalFrom4x4: model.modelMatrix)
            
            renderEncoder.setVertexBytes(&uniforms,
                                         length: MemoryLayout<Uniforms>.stride, index: 1)
            
            renderEncoder.setRenderPipelineState(model.pipelineState)
            renderEncoder.setVertexBuffer(model.vertexBuffer, offset: 0, index: 0)
            for submesh in model.mesh.submeshes {
                renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                    indexCount: submesh.indexCount,
                                                    indexType: submesh.indexType,
                                                    indexBuffer: submesh.indexBuffer.buffer,
                                                    indexBufferOffset: submesh.indexBuffer.offset)
            }
        }
        
//        debugLights(renderEncoder: renderEncoder, lightType: Sunlight)
//        debugLights(renderEncoder: renderEncoder, lightType: Ambientlight)
        debugLights(renderEncoder: renderEncoder, lightType: Spotlight)
        debugLights(renderEncoder: renderEncoder, lightType: Pointlight)
        
        renderEncoder.endEncoding()
        guard let drawable = view.currentDrawable else {
            return
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}


