// The toon look for meshes coloured per vertex or per instance (the MultiMesh crowd).
shader_type spatial;
render_mode cull_back, specular_disabled;

#define VERTEX_TINT
#include "res://shaders/toon_common.gdshaderinc"
