/*
  ==============================================================================

   YUP Template - the application window.

  ==============================================================================
*/

#pragma once

#include <yup_gui/yup_gui.h>

//==============================================================================
/** The main window of the standalone application.

    A minimal document window that paints a greeting with the theme default font.
    Replace the paint method (or add child components in the constructor) with
    your own interface.
*/
class MainWindow final : public yup::DocumentWindow
{
public:
    MainWindow()
        : font (yup::ApplicationTheme::getGlobalTheme()->getDefaultFont().withAxisValue ("slnt", -10.0f))
    {
        setTitle (YupApp_Name);
    }

    //==============================================================================
    void paint (yup::Graphics& g) override
    {
        g.setFillColor (0xff2a2a28);
        g.fillAll();

        g.setFillColor (yup::Colors::white);
        g.fillFittedText ("Hello, YUP!", font.withHeight (24.0f), getLocalBounds());
    }

    void userTriedToCloseWindow() override
    {
        yup::YUPApplication::getInstance()->systemRequestedQuit();
    }

private:
    yup::Font font;

    YUP_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (MainWindow)
};
