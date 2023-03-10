#include "../clap/include/clap/ext/gui.h"

#include "imgui_impl_opengl3.h"
#include "imgui_impl_win32.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <assert.h>
#include <gl/gl.h>

#include <stdio.h>

static HINSTANCE global_hinstance = 0;

struct GuiData
{
	ImVec4 clear_color = ImVec4(0.45f, 0.55f, 0.60f, 1.00f);
	HWND window = 0;
	HDC win32_device_context = 0;
	uint32_t window_width = 600;
	uint32_t window_height = 400;
	const clap_plugin_t* plugin = nullptr;
	bool timer_active = false;
};	

ImVector<GuiData*> gui_datas;

extern IMGUI_IMPL_API LRESULT ImGui_ImplWin32_WndProcHandler(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

// NOTE(michael): the following is from
// https://www.opengl.org/registry/api/GL/glcorearb.h and
// https://www.opengl.org/registry/api/GL/wglext.h

// NOTE(michel): opengl tookens
#define GL_SHADING_LANGUAGE_VERSION       0x8B8C
#define GL_VERTEX_SHADER                  0x8B31
#define GL_FRAGMENT_SHADER                0x8B30
#define GL_ARRAY_BUFFER                   0x8892
#define GL_STATIC_DRAW                    0x88E4

// NOTE(michael): Windows specific opengl tokens
#define WGL_CONTEXT_MAJOR_VERSION_ARB           0x2091
#define WGL_CONTEXT_MINOR_VERSION_ARB           0x2092
#define WGL_CONTEXT_LAYER_PLANE_ARB             0x2093
#define WGL_CONTEXT_FLAGS_ARB                   0x2094
#define WGL_CONTEXT_PROFILE_MASK_ARB            0x9126

#define WGL_CONTEXT_DEBUG_BIT_ARB               0x0001
#define WGL_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB  0x0002

#define WGL_CONTEXT_CORE_PROFILE_BIT_ARB        0x00000001
#define WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB 0x00000002

// NOTE(michael): opengl functions / types
typedef char GLchar;
typedef ptrdiff_t GLsizeiptr;
typedef HGLRC Type_wglCreateContextAttribsARB(HDC hDC, HGLRC hShareContext, const int *attribList);

HDC initOpenGL(HWND window) {
	HDC win32_device_context = GetDC(window);
    
	{
		// NOTE(michael): set pixel format
        
		PIXELFORMATDESCRIPTOR pixel_format_we_desire = {};
		pixel_format_we_desire.nSize = sizeof(PIXELFORMATDESCRIPTOR);
		pixel_format_we_desire.nVersion = 1;
		pixel_format_we_desire.dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER;
		pixel_format_we_desire.iPixelType = PFD_TYPE_RGBA;
		pixel_format_we_desire.cColorBits = 32;
		pixel_format_we_desire.cDepthBits = 8;
		pixel_format_we_desire.iLayerType = PFD_MAIN_PLANE;
        
		int chosen_pixel_format_index = ChoosePixelFormat(win32_device_context, &pixel_format_we_desire);
		SetPixelFormat(win32_device_context, chosen_pixel_format_index, &pixel_format_we_desire);
        
		PIXELFORMATDESCRIPTOR chosen_pixel_format;
		DescribePixelFormat(win32_device_context, chosen_pixel_format_index, sizeof(PIXELFORMATDESCRIPTOR), &chosen_pixel_format);
	}
    
	HGLRC opengl_render_context = wglCreateContext(win32_device_context);
	if(wglMakeCurrent(win32_device_context, opengl_render_context))
	{
		Type_wglCreateContextAttribsARB* wglCreateContextAttribsARB =
			(Type_wglCreateContextAttribsARB*)wglGetProcAddress("wglCreateContextAttribsARB");
        
		if(wglCreateContextAttribsARB)
		{
			int attribs[] = 
			{
				WGL_CONTEXT_MAJOR_VERSION_ARB, 3,
				WGL_CONTEXT_MINOR_VERSION_ARB, 0,
				WGL_CONTEXT_FLAGS_ARB, 
				0		
#if DEBUG
				| WGL_CONTEXT_DEBUG_BIT_ARB
#endif 
				,
				WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB,
				0,
			};
            
			HGLRC share_context = 0;
			HGLRC modern_context = wglCreateContextAttribsARB(win32_device_context, share_context, attribs);

			if(modern_context)
			{
				if(wglMakeCurrent(win32_device_context, modern_context)) 
				{
					wglDeleteContext(opengl_render_context);
					opengl_render_context = modern_context;
				}
			}
		}
		else
		{
			assert(false);
		}
	}
	else
	{
		assert(false);
	}

	return win32_device_context;
}


extern "C" {

void imGuiFrame(const clap_plugin_t* plugin);

}

void renderFrame(GuiData* gui_data) {
    // Start the Dear ImGui frame
    ImGui_ImplOpenGL3_NewFrame();
    ImGui_ImplWin32_NewFrame();

    imGuiFrame(gui_data->plugin);

    ImGuiIO& io = ImGui::GetIO(); (void)io;
    glViewport(0, 0, (int)io.DisplaySize.x, (int)io.DisplaySize.y);
    ImVec4 clear_color = gui_data->clear_color;
    glClearColor(clear_color.x * clear_color.w, clear_color.y * clear_color.w, clear_color.z * clear_color.w, clear_color.w); 
    glClear(GL_COLOR_BUFFER_BIT);

    ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());

	SwapBuffers(gui_data->win32_device_context);
}

// Win32 message handler
// You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear imgui wants to use your inputs.
// - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application, or clear/overwrite your copy of the mouse data.
// - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main application, or clear/overwrite your copy of the keyboard data.
// Generally you may always pass all inputs to dear imgui, and hide them from your application based on those two flags.
LRESULT WINAPI WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	if(msg == WM_LBUTTONDOWN)
		SetFocus(hWnd);

    if (ImGui_ImplWin32_WndProcHandler(hWnd, msg, wParam, lParam))
        return true;

	switch(msg)
	{
		case WM_TIMER:
			for(int i = 0; i < gui_datas.Size; i++)
			{
				if(gui_datas[i]->window == hWnd)
					renderFrame(gui_datas[i]);
			}
			break;
	}

    return ::DefWindowProc(hWnd, msg, wParam, lParam);
}

extern "C" {


void platformGuiCreate(const void** gui_data, const clap_plugin_t* plugin, uint32_t init_width, uint32_t init_height)
{
	GuiData* ptr = (GuiData*)malloc(sizeof(GuiData));
	(*ptr) = GuiData{};
	ptr->plugin = plugin;
	if(init_width != 0) {
		ptr->window_width = init_width;
	}
	if(init_height != 0) {
		ptr->window_height = init_height;
	}

	(*gui_data) = (void*)ptr;

	gui_datas.push_back(ptr);

    ImGui_ImplWin32_EnableDpiAwareness();
    WNDCLASSEXW wc = { sizeof(wc), 0, WndProc, 0L, 0L, global_hinstance, NULL, NULL, NULL, NULL, L"ImGui Example", NULL };
    ::RegisterClassExW(&wc);
}

void platformGuiDestroy(void* void_gui_data)
{
	GuiData* gui_data = (GuiData*)void_gui_data;

	gui_datas.find_erase_unsorted(gui_data);

	ImGui_ImplOpenGL3_Shutdown();
	ImGui_ImplWin32_Shutdown();
    ImGui::DestroyContext();

	if(gui_data->timer_active)
		KillTimer(gui_data->window, 1);

    ReleaseDC(gui_data->window, gui_data->win32_device_context);
    ::UnregisterClassW(L"ImGui Example", global_hinstance);
	DestroyWindow(gui_data->window);

	free(void_gui_data);
}

void platformGuiSetParent(const void* void_gui_data, const clap_window_t* window)
{
	GuiData* gui_data = (GuiData*)void_gui_data;

	HWND parent_window = (HWND)window->win32;

    // Create application window
    gui_data->window = ::CreateWindowW(L"ImGui Example", L"Dear ImGui DirectX11 Example", WS_CHILD | WS_VISIBLE, 0, 0, 
    	gui_data->window_width, gui_data->window_height, parent_window, NULL, global_hinstance, NULL);
    if(gui_data->window == 0) {
    	assert(false);
    }

	gui_data->win32_device_context = initOpenGL(gui_data->window);

    // Setup Dear ImGui context
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); (void)io;
    //io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;     // Enable Keyboard Controls
    //io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;      // Enable Gamepad Controls

    // Setup Dear ImGui style
    ImGui::StyleColorsDark();
    //ImGui::StyleColorsLight();

	ImGui_ImplWin32_Init(gui_data->window);
	ImGui_ImplOpenGL3_Init();
}
void platformGuiSetSize(const void* void_gui_data, uint32_t width, uint32_t height)
{
	GuiData* gui_data = (GuiData*)void_gui_data;
	gui_data->window_width = width;
	gui_data->window_height = height;
    if(gui_data->window != 0) {
        SetWindowPos(gui_data->window, nullptr, 0, 0, width, height, 0);
    }
}
bool platformGuiGetSize(const void* void_gui_data, uint32_t* width, uint32_t* height)
{
	GuiData* gui_data = (GuiData*)void_gui_data;
	(*width) = gui_data->window_width;
	(*height) = gui_data->window_height;
	return true;
}
void platformGuiShow(const void* void_gui_data)
{
	GuiData* gui_data = (GuiData*)void_gui_data;
	if(!gui_data->timer_active)
 	{
		SetTimer(gui_data->window, 1, 1, NULL);
		gui_data->timer_active = true;
	}
}
void platformGuiHide(const void* void_gui_data)
{
	GuiData* gui_data = (GuiData*)void_gui_data;
	if(gui_data->timer_active)
 	{
		KillTimer(gui_data->window, 1);
		gui_data->timer_active = false;
	}
}

void myDLLMain(HINSTANCE hInstance, DWORD fdwReason) {
    if (fdwReason == 1) {
        global_hinstance = hInstance;
    }
}

}
