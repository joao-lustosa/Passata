import Foundation

// Generates a 0.62-second, mono 44.1 kHz PCM chime: two soft notes (880 Hz and
// 1174.66 Hz) with short attacks, exponential decay, and a slight overlap.
let sampleRate = 44_100
let firstNoteDuration = 0.31
let secondNoteStart = 0.27
let secondNoteDuration = 0.35
let outputDuration = secondNoteStart + secondNoteDuration
let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let waveURL = outputURL.deletingPathExtension().appendingPathExtension("wav")

func noteSample(frequency: Double, time: Double, duration: Double, amplitude: Double) -> Double {
    guard time >= 0, time < duration else { return 0 }
    let attack = min(1, time / 0.012)
    let decay = exp(-5.5 * time / duration)
    return sin(2 * .pi * frequency * time) * attack * decay * amplitude
}

func appendUInt16(_ value: UInt16, to data: inout Data) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
}

func appendUInt32(_ value: UInt32, to data: inout Data) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
}

let sampleCount = Int(Double(sampleRate) * outputDuration)
var pcm = Data(capacity: sampleCount * MemoryLayout<Int16>.size)
for sampleIndex in 0..<sampleCount {
    let time = Double(sampleIndex) / Double(sampleRate)
    let first = noteSample(frequency: 880, time: time, duration: firstNoteDuration, amplitude: 0.16)
    let second = noteSample(
        frequency: 1_174.66,
        time: time - secondNoteStart,
        duration: secondNoteDuration,
        amplitude: 0.13
    )
    let value = Int16((max(-1, min(1, first + second)) * Double(Int16.max)).rounded())
    appendUInt16(UInt16(bitPattern: value), to: &pcm)
}

var wave = Data()
wave.append(contentsOf: "RIFF".utf8)
appendUInt32(UInt32(36 + pcm.count), to: &wave)
wave.append(contentsOf: "WAVEfmt ".utf8)
appendUInt32(16, to: &wave)
appendUInt16(1, to: &wave)
appendUInt16(1, to: &wave)
appendUInt32(UInt32(sampleRate), to: &wave)
appendUInt32(UInt32(sampleRate * MemoryLayout<Int16>.size), to: &wave)
appendUInt16(UInt16(MemoryLayout<Int16>.size), to: &wave)
appendUInt16(16, to: &wave)
wave.append(contentsOf: "data".utf8)
appendUInt32(UInt32(pcm.count), to: &wave)
wave.append(pcm)
try wave.write(to: waveURL)

let converter = Process()
converter.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
converter.arguments = ["-f", "caff", "-d", "LEI16@44100", waveURL.path, outputURL.path]
try converter.run()
converter.waitUntilExit()
try FileManager.default.removeItem(at: waveURL)
guard converter.terminationStatus == 0 else {
    throw NSError(domain: "CompletionChimeGenerator", code: Int(converter.terminationStatus))
}
print("Generated \(outputURL.path) (\(outputDuration)s, mono PCM CAF)")
