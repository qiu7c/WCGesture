#import <AudioToolbox/AudioToolbox.h>
#include <SKP_Silk_SDK_API.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#import "Sources/API/WCGestureInternal.h"

// Recorded PCM only. The SDK and license are inherited from WCAtlas's vendor tree.
BOOL WCGestureEncodeRecordedVoice(NSURL *source, NSURL *destination, NSUInteger *durationMilliseconds) {
    *durationMilliseconds = 0;
    ExtAudioFileRef input = NULL;
    if (ExtAudioFileOpenURL((__bridge CFURLRef)source, &input) != noErr) return NO;
    AudioStreamBasicDescription format = {0};
    format.mSampleRate = 16000;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    format.mBytesPerPacket = format.mBytesPerFrame = 2;
    format.mFramesPerPacket = 1;
    format.mChannelsPerFrame = 1;
    format.mBitsPerChannel = 16;
    BOOL okay = ExtAudioFileSetProperty(input, kExtAudioFileProperty_ClientDataFormat, sizeof(format), &format) == noErr;
    SKP_int32 encoderSize = 0;
    if (okay) okay = SKP_Silk_SDK_Get_Encoder_Size(&encoderSize) == 0 && encoderSize > 0;
    void *encoder = okay ? calloc(1, (size_t)encoderSize) : NULL;
    SKP_SILK_SDK_EncControlStruct control = {0};
    if (encoder) okay = SKP_Silk_SDK_InitEncoder(encoder, &control) == 0;
    else okay = NO;
    control.API_sampleRate = control.maxInternalSampleRate = 16000;
    control.packetSize = 320;
    control.bitRate = 20000;
    control.complexity = 2;
    control.packetLossPercentage = control.useInBandFEC = control.useDTX = 0;
    NSMutableData *output = [NSMutableData dataWithBytes:"\x02#!SILK_V3" length:10];
    NSUInteger samples = 0;
    while (okay && samples < 960000) {
        int16_t pcm[320] = {0};
        UInt32 count = 320;
        AudioBufferList buffers = {0};
        buffers.mNumberBuffers = 1;
        buffers.mBuffers[0].mNumberChannels = 1;
        buffers.mBuffers[0].mDataByteSize = sizeof(pcm);
        buffers.mBuffers[0].mData = pcm;
        if (ExtAudioFileRead(input, &count, &buffers) != noErr) { okay = NO; break; }
        if (!count) break;
        samples += count;
        uint8_t packet[4096];
        SKP_int16 length = sizeof(packet);
        okay = SKP_Silk_SDK_Encode(encoder, &control, pcm, 320, packet, &length) == 0 && length > 0 && length <= (SKP_int16)sizeof(packet);
        if (okay) {
            uint8_t size[2] = {(uint8_t)(length & 255), (uint8_t)((length >> 8) & 255)};
            [output appendBytes:size length:2];
            [output appendBytes:packet length:(NSUInteger)length];
        }
    }
    ExtAudioFileDispose(input);
    free(encoder);
    if (!okay || samples < 8000) return NO;
    *durationMilliseconds = MIN(60000, samples * 1000 / 16000);
    return [output writeToURL:destination options:NSDataWritingAtomic error:nil];
}
