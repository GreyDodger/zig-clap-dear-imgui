#import "../clap/include/clap/ext/gui.h"
#import <Cocoa/Cocoa.h>

#include "imgui_impl_metal.h"
#include "imgui_impl_osx.h"

NSTextView* text_view = nullptr;
uint32_t client_width = 0;
uint32_t client_height = 0;

extern "C" {


void guiCreate(){
}
void guiDestroy(){
}
void guiSetParent(const clap_window_t* window){
	NSView* main_view = (NSView*)window->cocoa;

	// This will add a simple text view to the window,
    // so we can write a test string on it.
    NSRect window_rect = NSMakeRect(0, client_height - 100, 100, 100);
    text_view = [[NSTextView alloc] initWithFrame:window_rect];
    [main_view addSubview: text_view];
    [text_view insertText:@"Hello World"];
}
void guiSetSize(uint32_t width, uint32_t height){
	client_width = width;
	client_height = height;
	if(text_view != nullptr) {
	    NSRect f = text_view.frame;
    	f.origin.y = client_height - 100;
    	text_view.frame = f;
	}

	/*
	NSAlert *alert = [[NSAlert alloc] init];
	[alert setMessageText:@"Bing Bop boop"];
	[alert setInformativeText:[NSString stringWithFormat:@"%d", width]];
	[alert addButtonWithTitle:@"OK"];
	[alert addButtonWithTitle:@"Cancel"];
	[alert runModal];
	*/
}

}