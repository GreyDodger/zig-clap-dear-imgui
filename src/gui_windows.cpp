#include "../clap/include/clap/ext/gui.h"

#include "imgui_impl_opengl3.h"
#include "imgui_impl_win32.h"

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <assert.h>
#include <gl/gl.h>

#include <stdio.h>

static bool show_demo_window = true;
static bool show_another_window = false;
static ImVec4 clear_color = ImVec4(0.45f, 0.55f, 0.60f, 1.00f);
static HINSTANCE global_hinstance = 0;
static HWND global_hwnd = 0;
static HDC global_hdc = 0;
static uint32_t window_width = 600;
static uint32_t window_height = 400;

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

void initOpenGL(HWND window) {
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

	ReleaseDC(window, win32_device_context);
}

void renderFrame() {
    // Start the Dear ImGui frame
    ImGui_ImplOpenGL3_NewFrame();
    ImGui_ImplWin32_NewFrame();
   	ImGui::NewFrame();

    // 1. Show the big demo window (Most of the sample code is in ImGui::ShowDemoWindow()! You can browse its code to learn more about Dear ImGui!).
    if (show_demo_window)
        ImGui::ShowDemoWindow(&show_demo_window);

    // 2. Show a simple window that we create ourselves. We use a Begin/End pair to create a named window.
        {
            static float f = 0.0f;
            static int counter = 0;

            ImGui::Begin("Hello, world!");                          // Create a window called "Hello, world!" and append into it.

            ImGui::Text("This is some useful text.");               // Display some text (you can use a format strings too)
            ImGui::Checkbox("Demo Window", &show_demo_window);      // Edit bools storing our window open/close state
            ImGui::Checkbox("Another Window", &show_another_window);

            ImGui::SliderFloat("float", &f, 0.0f, 1.0f);            // Edit 1 float using a slider from 0.0f to 1.0f
            //ImGui::ColorEdit3("clear color", (float*)&clear_color); // Edit 3 floats representing a color

            if (ImGui::Button("Button"))                            // Buttons return true when clicked (most widgets return true when edited/activated)
                counter++;
            ImGui::SameLine();
            ImGui::Text("counter = %d", counter);

            ImGui::Text("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / ImGui::GetIO().Framerate, ImGui::GetIO().Framerate);
            ImGui::End();
        }

        // 3. Show another simple window.
        if (show_another_window)
        {
            ImGui::Begin("Another Window", &show_another_window);   // Pass a pointer to our bool variable (the window will have a closing button that will clear the bool when clicked)
            ImGui::Text("Hello from another window!");
            if (ImGui::Button("Close Me"))
                show_another_window = false;
            ImGui::End();
        }

        // Rendering
        ImGui::Render();

    	ImGuiIO& io = ImGui::GetIO(); (void)io;
    	printf("Display Size %f %f\n", io.DisplaySize.x, io.DisplaySize.y);
        glViewport(0, 0, (int)io.DisplaySize.x, (int)io.DisplaySize.y);
        glClearColor(clear_color.x * clear_color.w, clear_color.y * clear_color.w, clear_color.z * clear_color.w, clear_color.w);
        glClear(GL_COLOR_BUFFER_BIT);

        ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());

		SwapBuffers(GetDC(global_hwnd));
}

// Win32 message handler
// You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear imgui wants to use your inputs.
// - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application, or clear/overwrite your copy of the mouse data.
// - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main application, or clear/overwrite your copy of the keyboard data.
// Generally you may always pass all inputs to dear imgui, and hide them from your application based on those two flags.
LRESULT WINAPI WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    if (ImGui_ImplWin32_WndProcHandler(hWnd, msg, wParam, lParam))
        return true;

	switch(msg)
	{
		case WM_PAINT:
			renderFrame();
			break;
	}

    return ::DefWindowProc(hWnd, msg, wParam, lParam);
}

extern "C" {

void guiCreate()
{

}

void guiDestroy()
{
	
}
void guiSetParent(const clap_window_t* window)
{
	HWND parent_window = (HWND)window->win32;

    // Create application window
    //ImGui_ImplWin32_EnableDpiAwareness();
    WNDCLASSEXW wc = { sizeof(wc), 0, WndProc, 0L, 0L, global_hinstance, NULL, NULL, NULL, NULL, L"ImGui Example", NULL };
    ::RegisterClassExW(&wc);
    global_hwnd = ::CreateWindowW(wc.lpszClassName, L"Dear ImGui DirectX11 Example", WS_CHILD | WS_VISIBLE, 0, 0, window_width, window_height, parent_window, NULL, wc.hInstance, NULL);
    if(global_hwnd == 0) {
    	assert(false);
    }

	initOpenGL(global_hwnd);

    // Setup Dear ImGui context
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); (void)io;
    //io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;     // Enable Keyboard Controls
    //io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;      // Enable Gamepad Controls

    // Setup Dear ImGui style
    ImGui::StyleColorsDark();
    //ImGui::StyleColorsLight();

	ImGui_ImplWin32_Init(global_hwnd);
	ImGui_ImplOpenGL3_Init();
}
void guiSetSize(uint32_t width, uint32_t height)
{
	window_width = width;
	window_height = height;
    if(global_hwnd != 0) {
        SetWindowPos(global_hwnd, nullptr, 0, 0, width, height, 0);
        renderFrame();
    }
}
void guiGetSize(uint32_t* width, uint32_t* height)
{
	(*width) = window_width;
	(*height) = window_height;
}

void myDLLMain(HINSTANCE hInstance, DWORD fdwReason) {
    if (fdwReason == 1) {
        global_hinstance = hInstance;
    }
}

}
