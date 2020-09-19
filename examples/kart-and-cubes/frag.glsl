#version 150

in vec2 texCoord;
in vec3 normal;
in vec3 fragPos;
out vec4 outColor;


struct PointLight {
	vec3 position;
	vec3 color;
};
uniform PointLight light;

uniform vec3 ambient;
uniform vec3 diffuse;
uniform vec3 viewPos;
uniform sampler2D tex;
uniform bool useTex;

void main() {
	vec3 result = vec3(1.0);
	if (!useTex) {
		result = ambient;
	}

	result = result * light.color;

	vec3 norm = normalize(normal);
	vec3 lightDir = normalize(light.position - fragPos);

	// diffuse
	float diff = max(dot(norm, lightDir), 0.0);
	vec3 diffuse = diff * diffuse * light.color;
	result = result + diffuse;

	// specular
	float specularStrength = 0.5;
	vec3 viewDir = normalize(viewPos - fragPos);
	vec3 reflectDir = reflect(-lightDir, norm);
	float spec = pow(max(dot(viewDir, reflectDir), 0.0), 32);
	vec3 specular = specularStrength * spec * light.color;
	result = result + specular;

	if (useTex) {
		outColor = texture(tex, texCoord) * vec4(result, 1.0);
	} else {
		outColor = vec4(result, 1.0);
	}
}
