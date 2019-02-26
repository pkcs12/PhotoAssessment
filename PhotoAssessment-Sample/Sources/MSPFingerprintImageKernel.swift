//
//  MSPFingerprintImageKernel.swift
//  PhotoAssessment
//
//  Created by 杨萧玉 on 2019/2/24.
//  Copyright © 2019 杨萧玉. All rights reserved.
//

import MetalPerformanceShaders
import Metal

class MSPFingerprintImageKernel: MPSUnaryImageKernel {
    
    let computePipelineState: MTLComputePipelineState?
    let threadGroupSize: MTLSize?
    
    override init(device: MTLDevice) {
        let library = device.makeDefaultLibrary()
        let functionName = device.supportNonuniformThreadgroupSize() ? "fingerprintKernelNonuniform" : "fingerprintKernel"
        if let function = library?.makeFunction(name: functionName) {
            do {
                try computePipelineState = device.makeComputePipelineState(function: function)
            } catch {
                computePipelineState = nil
                print("Failed to create ComputePipelineState: \(error.localizedDescription)")
            }
        }
        else {
            computePipelineState = nil
            print("missing metal function")
        }
        if let computePipelineState = computePipelineState {
            let w = computePipelineState.threadExecutionWidth;
            let h = computePipelineState.maxTotalThreadsPerThreadgroup / w;
            threadGroupSize = MTLSize(width: w, height: h, depth: 1);
        }
        else {
            threadGroupSize = nil
        }
        super.init(device: device)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func fingerprintSize() -> Int {
        // 4 channels. 4 Bytes per channel.
        let bufferLength = 8192
        return bufferLength
    }
    
    func encode(commandBuffer: MTLCommandBuffer, sourceTexture: MTLTexture, fingerprint buffer: MTLBuffer?) {
        guard let computePipelineState = computePipelineState else {
            print("Failed to create ComputePipelineState")
            return
        }
        guard let threadGroupSize = threadGroupSize else {
            print("Failed to create threadGroupSize")
            return
        }
        let encoder = commandBuffer.makeComputeCommandEncoder()
        encoder?.pushDebugGroup("fingerprint")
        encoder?.setComputePipelineState(computePipelineState)
        encoder?.setTexture(sourceTexture, index: 0)
        encoder?.setBuffer(buffer, offset: 0, index: 0)

        if device.supportNonuniformThreadgroupSize() {
            let threadsPerGrid = MTLSize(width: sourceTexture.width, height: sourceTexture.height, depth: 1);
            encoder?.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadGroupSize)
        }
        else {
            let w = threadGroupSize.width;
            let h = threadGroupSize.height;
            let threadgroupsPerGrid = MTLSize(width: (sourceTexture.width + w - 1) / w, height: (sourceTexture.height + h - 1) / h, depth: 1);
            encoder?.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadGroupSize)
        }
        
        encoder?.popDebugGroup()
        encoder?.endEncoding()
    }
}
