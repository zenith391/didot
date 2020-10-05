#version 330 core

in vec3 texCoord;
out vec4 outColor;

uniform samplerCube skybox;

void main() {
	outColor = texture(skybox, texCoord);
}
