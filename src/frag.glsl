#version 150

in vec2 texCoord;
out vec4 outColor;

uniform sampler2D tex;
uniform bool useTex;

void main() {
	if (useTex) {
		outColor = texture(tex, texCoord);
	} else {
		outColor = vec4(0.7, 0.7, 0.7, 1.0);
	}
}
