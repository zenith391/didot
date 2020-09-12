#version 150

in vec3 position;
in vec2 texcoord;
out vec2 texCoord;

uniform mat4 projMatrix;
uniform mat4 viewMatrix;
uniform mat4 modelMatrix;

void main() {
	gl_Position = projMatrix * viewMatrix * modelMatrix * vec4(position, 1.0);
	texCoord = texcoord;
}
