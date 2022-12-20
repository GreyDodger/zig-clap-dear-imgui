#import "../clap/include/clap/ext/gui.h"
#import <Cocoa/Cocoa.h>

#include "imgui_impl_metal.h"
#include "imgui_impl_osx.h"

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

extern "C" {

void imGuiFrame();

}

uint32_t client_width = 0;
uint32_t client_height = 0;
bool parented = false;
ImVec4 clear_color = ImVec4(0.45f, 0.55f, 0.60f, 1.00f);

id <MTLDevice> _device;
id <MTLCommandQueue> _commandQueue;

@interface MyMTKViewDelegate : NSObject<MTKViewDelegate>
- (void)drawInMTKView:(MTKView *)view;
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size;
@end

@implementation MyMTKViewDelegate
- (void)drawInMTKView:(MTKView *)view{

    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize.x = view.bounds.size.width;
    io.DisplaySize.y = view.bounds.size.height;

#if TARGET_OS_OSX
    CGFloat framebufferScale = view.window.screen.backingScaleFactor ?: NSScreen.mainScreen.backingScaleFactor;
#else
    CGFloat framebufferScale = view.window.screen.scale ?: UIScreen.mainScreen.scale;
#endif
    io.DisplayFramebufferScale = ImVec2(framebufferScale, framebufferScale);

    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];

    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor == nil)
    {
        [commandBuffer commit];
		return;
    }

    // Start the Dear ImGui frame
    ImGui_ImplMetal_NewFrame(renderPassDescriptor);
#if TARGET_OS_OSX
    ImGui_ImplOSX_NewFrame(view);
#endif

    imGuiFrame();

    ImDrawData* draw_data = ImGui::GetDrawData();

    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(clear_color.x * clear_color.w, clear_color.y * clear_color.w, clear_color.z * clear_color.w, clear_color.w);
    id <MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    [renderEncoder pushDebugGroup:@"Dear ImGui rendering"];
    ImGui_ImplMetal_RenderDrawData(draw_data, commandBuffer, renderEncoder);
    [renderEncoder popDebugGroup];
    [renderEncoder endEncoding];

	// Present
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {

}
@end

MTKView* mtk_view = nullptr;

extern "C" {

bool guiCreate(const clap_plugin_t* plugin, const char* api, bool is_floating) {
    _device = MTLCreateSystemDefaultDevice();
    _commandQueue = [_device newCommandQueue];

    if (!_device)
    {
        NSLog(@"Metal is not supported");
        abort();
    }

    // Setup Dear ImGui context
    // FIXME: This example doesn't have proper cleanup...
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); (void)io;
    //io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;     // Enable Keyboard Controls
    //io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;      // Enable Gamepad Controls

    // Setup Dear ImGui style
    ImGui::StyleColorsDark();
    //ImGui::StyleColorsLight();

    // Setup Renderer backend
    ImGui_ImplMetal_Init(_device);

    // Load Fonts
    // - If no fonts are loaded, dear imgui will use the default font. You can also load multiple fonts and use ImGui::PushFont()/PopFont() to select them.
    // - AddFontFromFileTTF() will return the ImFont* so you can store it if you need to select the font among multiple.
    // - If the file cannot be loaded, the function will return NULL. Please handle those errors in your application (e.g. use an assertion, or display an error and quit).
    // - The fonts will be rasterized at a given size (w/ oversampling) and stored into a texture when calling ImFontAtlas::Build()/GetTexDataAsXXXX(), which ImGui_ImplXXXX_NewFrame below will call.
    // - Use '#define IMGUI_ENABLE_FREETYPE' in your imconfig file to use Freetype for higher quality font rendering.
    // - Read 'docs/FONTS.md' for more instructions and details.
    // - Remember that in C/C++ if you want to include a backslash \ in a string literal you need to write a double backslash \\ !
    //io.Fonts->AddFontDefault();
    //io.Fonts->AddFontFromFileTTF("c:\\Windows\\Fonts\\segoeui.ttf", 18.0f);
    //io.Fonts->AddFontFromFileTTF("../../misc/fonts/DroidSans.ttf", 16.0f);
    //io.Fonts->AddFontFromFileTTF("../../misc/fonts/Roboto-Medium.ttf", 16.0f);
    //io.Fonts->AddFontFromFileTTF("../../misc/fonts/Cousine-Regular.ttf", 15.0f);
    //ImFont* font = io.Fonts->AddFontFromFileTTF("c:\\Windows\\Fonts\\ArialUni.ttf", 18.0f, NULL, io.Fonts->GetGlyphRangesJapanese());
    //IM_ASSERT(font != NULL);

    mtk_view = [[MTKView alloc] initWithFrame: CGRectMake(0,0,client_width,client_height) device: _device];
    mtk_view.delegate = [MyMTKViewDelegate alloc];
    return true;
}
void guiDestroy(const clap_plugin_t* plugin){
    ImGui_ImplMetal_Shutdown();
    ImGui_ImplOSX_Shutdown();
    ImGui::DestroyContext();
}
void guiSetParent(const clap_plugin_t* plugin, const clap_window_t* window){
	NSView* main_view = (NSView*)window->cocoa;
	[main_view addSubview: mtk_view];
    ImGui_ImplOSX_Init(mtk_view);
    parented = true;
}
bool guiSetSize(const clap_plugin_t* plugin, uint32_t width, uint32_t height){
	client_width = width;
	client_height = height;

	if(mtk_view != nullptr && parented) {
	    NSRect f = mtk_view.frame;
	    f.size.width = client_width;
	    f.size.height = client_height;
    	mtk_view.frame = f;
	}
    
    return true;
}
bool guiGetSize(const clap_plugin_t* plugin, uint32_t* width, uint32_t* height){
    return true;
}

}
