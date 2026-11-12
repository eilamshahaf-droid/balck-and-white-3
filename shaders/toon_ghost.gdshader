// The same look for buildings that fade so the camera can see the hand.
// The fade is a screen-door pattern on an opaque surface, not real transparency:
// a transparent building is missing from the picture the depth of field reads, so
// it popped in and out wherever the background was blurred.
shader_type spatial;
render_mode cull_back, specular_disabled;

#define GHOST
#include "res://shaders/toon_common.gdshaderinc"
