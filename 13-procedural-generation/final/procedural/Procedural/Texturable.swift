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

protocol Texturable {}

extension Texturable {
  static func loadTexture(imageName: String) throws -> MTLTexture? {
    let textureLoader = MTKTextureLoader(device: Renderer.device)
    let textureLoaderOptions: [MTKTextureLoader.Option: Any] =
      [.origin: MTKTextureLoader.Origin.bottomLeft,
       .SRGB: false,
       .generateMipmaps: NSNumber(booleanLiteral: true)]
    let fileExtension =
      URL(fileURLWithPath: imageName).pathExtension.isEmpty ?
        "png" : nil
    guard let url = Bundle.main.url(forResource: imageName,
                                    withExtension: fileExtension)
      else {
        return try textureLoader.newTexture(name: imageName, scaleFactor: 1.0,
                                            bundle: Bundle.main, options: nil)
    }
    let texture = try textureLoader.newTexture(URL: url,
                                               options: textureLoaderOptions)
    return texture
  }
  
  static func loadCubeTexture(imageName: String) throws -> MTLTexture? {
    let textureLoader = MTKTextureLoader(device: Renderer.device)
    if let texture = MDLTexture(cubeWithImagesNamed: [imageName]) {
      let options: [MTKTextureLoader.Option: Any] =
        [.origin: MTKTextureLoader.Origin.topLeft,
         .SRGB: false,
         .generateMipmaps: NSNumber(booleanLiteral: false)]
      return try textureLoader.newTexture(texture: texture, options: options)
    }
    let texture = try textureLoader.newTexture(name: imageName, scaleFactor: 1.0,
                                               bundle: .main, options: nil)
    return texture
  }

  static func loadTextureArray(textureNames: [String]) -> MTLTexture? {
    var textures: [MTLTexture] = []
    for textureName in textureNames {
      do {
        if let texture = try Nature.loadTexture(imageName: textureName) {
          textures.append(texture)
        }
      }
      catch {
        fatalError(error.localizedDescription)
      }
    }
    guard textures.count > 0 else { return nil }
    
    let descriptor = MTLTextureDescriptor()
    descriptor.textureType = .type2DArray
    descriptor.pixelFormat = textures[0].pixelFormat
    descriptor.width = textures[0].width
    descriptor.height = textures[0].height
    descriptor.arrayLength = textures.count
    let arrayTexture = Renderer.device.makeTexture(descriptor: descriptor)!
    let commandBuffer = Renderer.commandQueue.makeCommandBuffer()!
    let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
    let origin = MTLOrigin(x: 0, y: 0, z: 0)
    let size = MTLSize(width: arrayTexture.width, height: arrayTexture.height, depth: 1)
    for (index, texture) in textures.enumerated() {
      blitEncoder.copy(from: texture, sourceSlice: 0, sourceLevel: 0,
                       sourceOrigin: origin, sourceSize: size,
                       to: arrayTexture, destinationSlice: index,
                       destinationLevel: 0, destinationOrigin: origin)
    }
    blitEncoder.endEncoding()
    commandBuffer.commit()
    return arrayTexture
  }
}
