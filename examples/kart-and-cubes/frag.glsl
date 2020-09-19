#version 150

in vec2 texCoord;
in vec3 normal;
in vec3 fragPos;
out vec4 outColor;

struct PointLight {
	vec3 position;
	vec3 color;
};

struct Material {
	vec3 ambient;
	vec3 diffuse;
	vec3 specular;
};

uniform PointLight light;
uniform Material material;

uniform vec3 viewPos;
uniform sampler2D tex;
uniform bool useTex;

void main() {
	vec3 result = material.ambient;

	result = result * light.color;

	vec3 norm = normalize(normal);
	vec3 lightDir = normalize(light.position - fragPos);
	float distance = length(light.position - fragPos);
	float attenuation = 1.0 / (1.0 + 0.032 * (distance*distance) + 0.09 * distance);

	// diffuse
	float diff = max(dot(norm, lightDir), 0.0);
	vec3 diffuse = diff * material.diffuse * light.color * attenuation;
	result = result + diffuse;

	// specular
	float specularStrength = 0.5;
	vec3 viewDir = normalize(viewPos - fragPos);
	vec3 reflectDir = reflect(-lightDir, norm);
	float spec = specularStrength * pow(max(dot(viewDir, reflectDir), 0.0), 32);
	vec3 specular = spec * material.specular * light.color * attenuation;
	result = result + specular;

	if (useTex) {
		outColor = texture(tex, texCoord) * vec4(result, 1.0);
	} else {
		outColor = vec4(result, 1.0);
	}
}
