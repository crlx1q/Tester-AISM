package com.example.myapp

import java.nio.ShortBuffer

/**
 * Ring buffer хранящий последние N семплов (16-bit PCM mono).
 */
class CircularAudioBuffer(capacity: Int) {

    private val buffer = ShortArray(capacity)
    private var writePosition = 0
    private var size = 0

    fun write(data: ShortArray, length: Int) {
        val count = length.coerceAtMost(data.size)
        var remaining = count
        var offset = 0
        while (remaining > 0) {
            val chunk = minOf(remaining, buffer.size - writePosition)
            System.arraycopy(data, offset, buffer, writePosition, chunk)
            writePosition = (writePosition + chunk) % buffer.size
            offset += chunk
            remaining -= chunk
        }
        size = minOf(buffer.size, size + count)
    }

    fun snapshot(): ShortArray {
        if (size == 0) return ShortArray(0)
        val result = ShortArray(size)
        val start = (writePosition - size + buffer.size) % buffer.size
        val firstChunk = minOf(size, buffer.size - start)
        System.arraycopy(buffer, start, result, 0, firstChunk)
        if (firstChunk < size) {
            System.arraycopy(buffer, 0, result, firstChunk, size - firstChunk)
        }
        return result
    }
}
