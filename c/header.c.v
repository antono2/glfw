module c

#flag -I$env('GLFW_INCLUDE')
#flag -L$env('GLFW_LIB')
#flag linux -lglfw
#flag darwin -lglfw
#flag windows -lglfw3
#flag windows -lgdi32
#flag -DGLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>
