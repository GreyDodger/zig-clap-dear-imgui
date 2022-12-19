#import "../clap/include/clap/ext/gui.h"
#import <Cocoa/Cocoa.h>

extern "C" {

void guiCreate(){
}
void guiDestroy(){

}
void guiSetParent(const clap_window_t* window){
    NSRect frame = [(NSView*)window->cocoa frame];

	/*
	NSAlert *alert = [[NSAlert alloc] init];
	[alert setMessageText:@"Bing Bop boop"];
	[alert setInformativeText:[NSString stringWithFormat:@"%d", NSWidth(frame)]];
	[alert addButtonWithTitle:@"OK"];
	[alert addButtonWithTitle:@"Cancel"];
	[alert runModal];
	*/

	NSView* main_view = (NSView*)window->cocoa;
	// This will add a simple text view to the window,
    // so we can write a test string on it.
    NSRect windowRect = NSMakeRect(0, 0, 100, 100);
    NSTextView* textView = [[NSTextView alloc] initWithFrame:windowRect];
    [main_view addSubview: textView];
    [textView insertText:@"Hello World"];
}

}