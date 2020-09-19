#version 150

in vec2 texCoord;
in vec3 normal;
in vec3 fragPos;
out vec4 outColor;

struct PointLight {
	vec3 position;
	vec3 color;
};

uniform vec3 ambient;
uniform vec3 diffuse;
uniform sampler2D tex;
uniform bool useTex;
uniform PointLight light;

void main() {
	vec4 result = vec4(1.0);
	if (!useTex) {
		result = vec4(ambient, 1.0);
	}

	result = result * vec4(light.color, 1);

	vec3 norm = normalize(normal);
	vec3 lightDir = normalize(light.position - fragPos);
	float diff = max(dot(norm, lightDir), 0.0);
	vec3 diffuse = diff * diffuse * light.color;

	result = result + vec4(diffuse, 1.0);

	if (useTex) {
		outColor = texture(tex, texCoord) * result;
	} else {
		outColor = result;
	}
}
