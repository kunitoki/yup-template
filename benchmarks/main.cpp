/*
  ==============================================================================

   YUP Template - DSP micro-benchmarks.

   The benchmarks link the plugin core when the plugin is built, so they can
   measure the real processor as well as the header-only sound engine
   (source/shared/dsp). Run them with `just bench` (or build the
   `*_benchmarks_run` target of any build folder).

  ==============================================================================
*/

#include <benchmark/benchmark.h>

#if BENCHMARKS_USE_PLUGIN_CORE
#include <yup_events/yup_events.h>
#endif

int main (int argc, char** argv)
{
#if BENCHMARKS_USE_PLUGIN_CORE
    // The processor uses the message manager, which has to outlive every benchmark.
    yup::ScopedYupInitialiser_GUI yupInitialiser;
#endif

    benchmark::Initialize (&argc, argv);
    if (benchmark::ReportUnrecognizedArguments (argc, argv))
        return 1;

    benchmark::RunSpecifiedBenchmarks();
    benchmark::Shutdown();

    return 0;
}
