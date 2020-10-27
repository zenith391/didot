#version 150

in vec2 texCoord;
in vec3 normal;
in vec3 fragPos;
out vec4 outColor;

struct PointLight {
	vec3 position;
	vec3 color;

	float constant;
	float linear;
	float quadratic;
};

struct Material {
	vec3 ambient;
	vec3 diffuse;
	vec3 specular;
    float shininess;
};

uniform PointLight light;
uniform Material material;

uniform vec3 viewPos;
uniform sampler2D tex;
uniform bool useTex;
uniform bool useLight;

vec3 computeLight(vec3 norm, vec3 viewDir, PointLight light) {
	vec3 lightDir = normalize(light.position - fragPos);
	float distance = length(light.position - fragPos);
	float attenuation = 1.0 / 
		(light.constant + 
		light.quadratic * (distance*distance) +
		light.linear * distance);

	// diffuse
	float diff = max(dot(norm, lightDir), 0.0);
	vec3 diffuse = diff * material.diffuse * light.color * attenuation;

	// specular
	float specularStrength = 0.5;
	vec3 reflectDir = reflect(-lightDir, norm);
	float spec = specularStrength * pow(max(dot(viewDir, reflectDir), 0.0), material.shininess);
	vec3 specular = spec * material.specular * light.color * attenuation;
	return (diffuse + specular) * light.color;
}

void main() {
	vec3 result = material.ambient;

	if (useLight) {
		vec3 norm = normalize(normal);
		vec3 viewDir = normalize(viewPos - fragPos);
		result += computeLight(norm, viewDir, light);
	} else {
		result = material.ambient + material.diffuse;
	}

	if (useTex) {
		outColor = texture(tex, texCoord) * vec4(result, 1.0);
	} else {
		outColor = vec4(result, 1.0);
	}
}
