/*
  ==============================================================================

   YUP Template - the application entry point.

  ==============================================================================
*/

#include <yup_gui/yup_gui.h>

#include "MainWindow.h"

#include <memory>

//==============================================================================
/** The standalone application.

    Creates the main window on startup and tears it down on shutdown. The name and
    the version are injected by CMake, so the project configuration stays the single
    source of truth.
*/
struct Application final : yup::YUPApplication
{
    Application() = default;

    //==============================================================================
    yup::String getApplicationName() override
    {
        return YupApp_Name;
    }

    yup::String getApplicationVersion() override
    {
        return YupApp_Version;
    }

    //==============================================================================
    void initialise (const yup::String& commandLineParameters) override
    {
        YUP_PROFILE_START();

        window = std::make_unique<MainWindow>();
        window->centreWithSize ({ 800, 600 });
        window->setVisible (true);
        window->toFront (true);
    }

    void shutdown() override
    {
        window.reset();

        YUP_PROFILE_STOP();
    }

private:
    std::unique_ptr<MainWindow> window;
};

//==============================================================================

START_YUP_APPLICATION (Application)
