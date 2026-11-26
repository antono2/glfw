// Selects GLFW headers, Vulkan declarations and platform linker flags for the binding.
// GLFW_INCLUDE and GLFW_LIB must identify matching installed headers and libraries.
module c

#flag -I$env('GLFW_INCLUDE')
#flag -L$env('GLFW_LIB')
#flag linux -I/usr/include
#flag darwin -I/usr/local/include
#flag darwin -I/opt/homebrew/include
#flag darwin -L/usr/local/lib
#flag darwin -L/opt/homebrew/lib
#flag linux -lglfw
#flag darwin -lglfw
#flag windows -lglfw3
#flag windows -lgdi32
#flag windows -lshell32
// GLFW's Vulkan declarations need VK_VERSION_1_0; Volk needs no prototypes.
#flag -DVK_NO_PROTOTYPES
#flag -DGLFW_INCLUDE_NONE
#flag -DGLFW_INCLUDE_VULKAN
#include <GLFW/glfw3.h>
