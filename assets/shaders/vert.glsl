#version 330

layout (location=0) in vec3 position;
layout (location=1) in vec3 mNormal;
layout (location=2) in vec2 texcoord;

out vec2 texCoord;
out vec3 normal;
out vec3 fragPos;

uniform mat4 projMatrix;
uniform mat4 viewMatrix;
uniform mat4 modelMatrix;

void main() {
	gl_Position = projMatrix * viewMatrix * modelMatrix * vec4(position, 1.0);
	fragPos = vec3(modelMatrix * vec4(position, 1.0));

	texCoord = texcoord;
	normal = mNormal;
}
