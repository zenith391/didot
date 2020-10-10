#version 330 core

layout (location=0) in vec3 position;
layout (location=1) in vec3 mNormal;
layout (location=2) in vec2 texcoord;

out vec3 texCoord;

uniform mat4 projection;
uniform mat4 view;

void main() {
	texCoord = position;
	gl_Position = projection * view * vec4(position, 1.0);
}
