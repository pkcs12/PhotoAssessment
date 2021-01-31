//
//  Utils.swift
//  PhotoAssessment
//
//  Created by 杨萧玉 on 2018/11/18.
//  Copyright © 2018 杨萧玉. All rights reserved.
//
#if os(iOS) || os(watchOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import Cocoa
#endif
import Metal

open class HSBColor: NSObject, NSCoding {
    
    @objc public let hue: Double
    @objc public let saturation: Double
    @objc public let brightness: Double
    
    init(hue: Double, saturation: Double, brightness: Double) {
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
    }
    
    public required init?(coder aDecoder: NSCoder) {
        self.hue = aDecoder.decodeDouble(forKey: "hue")
        self.saturation = aDecoder.decodeDouble(forKey: "saturation")
        self.brightness = aDecoder.decodeDouble(forKey: "brightness")
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.hue, forKey: "hue")
        aCoder.encode(self.saturation, forKey: "saturation")
        aCoder.encode(self.brightness, forKey: "brightness")
    }
}

open class Utils: NSObject {
    
    /// Fingerprint for image
    ///
    /// - Parameters:
    ///   - imagePixels: image pixels with rgba8 format
    ///   - width: image width
    ///   - height: image height
    /// - Returns: feature vector
    @objc public class func fingerprint(ofImagePixels imagePixels: [UInt32], width: Int, height: Int) -> [UInt32: Double] {
        
        func downsample(component: UInt8) -> UInt32 {
            return UInt32(component / 32)
        }
        
        func downsample(x: Int, y: Int) -> UInt32 {
            let rowCount: Int = min(2, height)
            let countPerRow: Int = min(2, width)
            let hStep = width / countPerRow
            let vStep = height / rowCount
            let row = y / vStep
            let col = x / hStep
            return UInt32(row * countPerRow + col);
        }
        
        var bucket = [UInt32: UInt]()
        
        for j in 0 ..< height {
            for i in 0 ..< width {
                let color = imagePixels[width * j + i]
                // |-3bit-|-3bit-|-3bit-|-2bit-|
                let r = downsample(component: color.r()) << 8
                let g = downsample(component: color.g()) << 5
                let b = downsample(component: color.b()) << 2
                let location = downsample(x: i, y: j)
                let fingerprint = r | g | b | location
                bucket[fingerprint] = (bucket[fingerprint] ?? 0) + 1
            }
        }
        let result: [UInt32: Double] = bucket.mapValues { (oldValue) -> Double in
            let newValue = Double(oldValue) / Double(imagePixels.count)
            return newValue
        }
        return result
    }
    
    /// mean HSB Color
    ///
    /// - Parameters:
    ///   - imagePixels: image pixels with rgba8 format
    ///   - width: image width
    ///   - height: image height
    /// - Returns: HSBColor
    @objc public class func meanHSB(ofImagePixels imagePixels: [UInt32], width: Int, height: Int) -> (HSBColor) {
        let hsbPixels = imagePixels.map { (pixel) -> (CGFloat, CGFloat, CGFloat) in
            #if os(iOS) || os(watchOS) || os(tvOS)
            return UIColor(red: CGFloat(pixel.r()) / 255.0, green: CGFloat(pixel.g()) / 255.0, blue: CGFloat(pixel.b()) / 255.0, alpha: CGFloat(pixel.a()) / 255.0).hsb
            #elseif os(macOS)
            return NSColor(red: CGFloat(pixel.r()), green: CGFloat(pixel.g()), blue: CGFloat(pixel.b()), alpha: CGFloat(pixel.a())).hsb
            #endif
        }
        let result = hsbPixels.reduce((0, 0, 0)) { (result, hsb) -> (CGFloat, CGFloat, CGFloat) in
            let (h, s, b) = hsb
            return (result.0 + h, result.1 + s, result.2 + b)
        }
        let count = Double(hsbPixels.count)
        return HSBColor(hue: Double(result.0) / count, saturation: Double(result.1) / count, brightness: Double(result.2) / count)
    }
    
    @objc public class func similarity(a: Fingerprint, b: Fingerprint) -> Double {
        var ab: Double = 0
        var aa: Double = 0
        var bb: Double = 0
        for (key, value) in a {
            ab += b[key] ?? 0 * value
            aa += value * value
        }
        for (_, value) in b {
            bb += value * value
        }
        return ab / (sqrt(aa) * sqrt(bb))
    }
}

extension CGImage {
    func grayPixels() -> [Int16] {
        var pixels = [Int16](repeatElement(0, count: width * height))
        let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 16, bytesPerRow: 2 * width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        context?.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }
    
    func rgbPixels() -> [UInt32] {
        var pixels = [UInt32](repeatElement(0, count: width * height))
        // Apple's bug(Only Swift): wrong bytesPerRow. Use workaround.
        let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 4 * width, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        context?.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }
}

#if os(iOS) || os(watchOS) || os(tvOS)
extension UIColor {
    var hsb:(h: CGFloat, s: CGFloat,b: CGFloat) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        return (h: h, s: s, b: b)
    }
}
#elseif os(macOS)
extension NSColor {
    var hsb:(h: CGFloat, s: CGFloat,b: CGFloat) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: nil)
        return (h: h, s: s, b: b)
    }
}
#endif

extension UInt32 {
    func mask8() -> UInt8 {
        return UInt8(self & 0xFF)
    }
    
    func r() -> UInt8 {
        return (self >> 24).mask8()
    }
    
    func g() -> UInt8 {
        return (self >> 16).mask8()
    }
    
    func b() -> UInt8 {
        return (self >> 8).mask8()
    }
    
    func a() -> UInt8 {
        return mask8()
    }
}


extension MTLDevice {
    func supportNonuniformThreadgroupSize() -> Bool {
        #if os(iOS)
//        if #available(iOS 12.0, *) {
//            if supportsFeatureSet(.iOS_GPUFamily4_v2) {
//                return true
//            }
//            if supportsFeatureSet(.iOS_GPUFamily5_v1) {
//                return true
//            }
//        } else if supportsFeatureSet(.iOS_GPUFamily4_v1) {
//            return true
//        }
        #elseif os(macOS)
        if #available(OSX 10.14, *) {
            if supportsFeatureSet(.macOS_GPUFamily1_v4) {
                return true
            }
            if supportsFeatureSet(.macOS_GPUFamily2_v1) {
                return true
            }
        }
        else {
            if supportsFeatureSet(.macOS_GPUFamily1_v3) {
                return true
            }
        }
        #endif
        return false
    }
}
