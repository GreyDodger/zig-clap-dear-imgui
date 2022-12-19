#import "../src/macos.h"
#import <Cocoa/Cocoa.h>

void guiCreate(){
	NSAlert *alert = [[NSAlert alloc] init];
	[alert setMessageText:@"Bing Bop boop"];
	[alert setInformativeText:@"I don't know"];
	[alert addButtonWithTitle:@"OK"];
	[alert addButtonWithTitle:@"Cancel"];
	[alert setAlertStyle:NSWarningAlertStyle];
	[alert runModal];
}
void guiDestroy(){

}
void guiSetParent(const clap_window_t* window){

}