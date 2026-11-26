/*
  ==============================================================================

   YUP Template - DSP micro-benchmarks.

   These benchmarks exercise the real plugin processor, compiled once in the
   plugin core that the benchmark executable links. They are only built when
   the plugin is (BUILD_PLUGIN).

  ==============================================================================
*/

#include <benchmark/benchmark.h>

#include "PluginProcessor.h"

namespace
{
constexpr float sampleRate = 48000.0f;

//==============================================================================
void BM_PluginProcessorProcessBlock (benchmark::State& state)
{
    const auto blockSize = static_cast<int> (state.range (0));

    PluginProcessor processor;
    processor.prepareToPlay (yup::AudioSpec (sampleRate, blockSize));

    yup::AudioBuffer<float> audio (2, blockSize);
    yup::MidiBuffer midi;
    yup::ParameterChangeBuffer params;

    for (int note = 48; note < 64; ++note)
        midi.addEvent (yup::MidiMessage::noteOn (1, note, 0.8f), 0);

    {
        yup::AudioProcessContext<float> context { audio, midi, params };
        processor.processBlock (context);
    }

    midi.clear();

    for (auto _ : state)
    {
        audio.clear();

        yup::AudioProcessContext<float> context { audio, midi, params };
        processor.processBlock (context);

        benchmark::DoNotOptimize (audio.getReadPointer (0));
    }

    state.SetItemsProcessed (state.iterations() * static_cast<yup::int64> (blockSize));
}

BENCHMARK (BM_PluginProcessorProcessBlock)->RangeMultiplier (4)->Range (64, 4096);

} // namespace
