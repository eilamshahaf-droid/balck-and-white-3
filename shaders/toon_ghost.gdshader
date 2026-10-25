// The same look for buildings that fade so the camera can see the hand.
shader_type spatial;
render_mode cull_back, specular_disabled, blend_mix, depth_draw_always;

#define GHOST
#include "res://shaders/toon_common.gdshaderinc"
