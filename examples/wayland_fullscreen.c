#define GLAD_GL_IMPLEMENTATION
#include <glad/gl.h>
#define GLFW_INCLUDE_NONE
#include <GLFW/glfw3.h>

#define GLFW_EXPOSE_NATIVE_WAYLAND
#include <GLFW/glfw3native.h>

#include <stdio.h>
#include <stdlib.h>

struct State {
    int fullscreen;
};

void keyFn(GLFWwindow *window, int key, int scancode, int action, int mods) {
    (void)scancode, (void)mods;

    struct State *state = glfwGetWindowUserPointer(window);

    if(key == GLFW_KEY_F && action == GLFW_PRESS) {
        printf("Toggling fullscreen!\n");

        state->fullscreen = !state->fullscreen;
        glfwSetWaylandWindowFullscreen(window, state->fullscreen);
    }
}

int main(int argc, char **argv) {
    const char *description;
    struct State state = {0};

    if(!glfwInit()) {
        glfwGetError(&description);
        fprintf(stderr, "Error: %s\n", description);
        exit(EXIT_FAILURE);
    }

    int platform = glfwGetPlatform();
    if(platform != GLFW_PLATFORM_WAYLAND) {
        printf("GLFW platform isn't wayland. This example won't work as intended.\n");
        glfwTerminate();
        exit(EXIT_SUCCESS);
    }

    GLFWwindow *window = glfwCreateWindow(1280, 720, "Fullscreen Window", NULL, NULL);

    glfwMakeContextCurrent(window);
    gladLoadGL(glfwGetProcAddress);
    glClearColor(1.0, 1.0, 1.0, 1.0);

    glfwSetWindowUserPointer(window, &state);
    glfwSetKeyCallback(window, keyFn);

    for(;;) {
        glfwPollEvents();

        glClear(GL_COLOR_BUFFER_BIT);
        glfwSwapBuffers(window);

        if(glfwWindowShouldClose(window) || glfwGetKey(window, GLFW_KEY_ESCAPE)) {
            break;
        }
    }

    glfwDestroyWindow(window);

    glfwTerminate();
    exit(1);
}
