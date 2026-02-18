package com.example.myapp

import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

object AudioUtils {

    const val SAMPLE_RATE = 16_000
    private const val CHANNELS = 1
    private const val BITS_PER_SAMPLE = 16

    fun shortArrayToLittleEndianBytes(data: ShortArray, length: Int): ByteArray {
        val count = length.coerceIn(0, data.size)
        val buffer = ByteBuffer.allocate(count * 2).order(ByteOrder.LITTLE_ENDIAN)
        for (i in 0 until count) {
            buffer.putShort(data[i])
        }
        return buffer.array()
    }

    fun shortArrayToWavBytes(data: ShortArray): ByteArray {
        val audioBytes = shortArrayToLittleEndianBytes(data, data.size)
        val header = createWavHeader(
            audioLength = audioBytes.size.toLong(),
            sampleRate = SAMPLE_RATE,
            channels = CHANNELS,
            bitsPerSample = BITS_PER_SAMPLE
        )
        return ByteArrayOutputStream(header.size + audioBytes.size).apply {
            write(header)
            write(audioBytes)
        }.toByteArray()
    }

    private fun createWavHeader(
        audioLength: Long,
        sampleRate: Int,
        channels: Int,
        bitsPerSample: Int
    ): ByteArray {
        val totalDataLen = audioLength + 36
        val byteRate = sampleRate * channels * bitsPerSample / 8
        val header = ByteArray(44)
        val buffer = ByteBuffer.wrap(header).order(ByteOrder.LITTLE_ENDIAN)
        buffer.put("RIFF".toByteArray())
        buffer.putInt(totalDataLen.toInt())
        buffer.put("WAVE".toByteArray())
        buffer.put("fmt ".toByteArray())
        buffer.putInt(16) // PCM chunk size
        buffer.putShort(1) // audio format = PCM
        buffer.putShort(channels.toShort())
        buffer.putInt(sampleRate)
        buffer.putInt(byteRate)
        buffer.putShort((channels * bitsPerSample / 8).toShort())
        buffer.putShort(bitsPerSample.toShort())
        buffer.put("data".toByteArray())
        buffer.putInt(audioLength.toInt())
        return header
    }
}
