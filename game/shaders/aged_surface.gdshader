shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 tint : source_color = vec4(0.6,0.64,0.60,1.0);
uniform sampler2D color_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_map : filter_linear_mipmap, repeat_enable;
uniform bool textured = false;
uniform float roughness_base = 0.8;
uniform float wear = 0.35;
uniform float metallic_base = 0.0;
varying vec3 world_pos;
float hash3(vec3 p){p=fract(p*.1031);p+=dot(p,p.yzx+33.33);return fract((p.x+p.y)*p.z);}
float noise3(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 base=tint.rgb;
 float coarse=noise3(world_pos*2.4);
 float fine=noise3(world_pos*120.0);
 float streak=noise3(world_pos*vec3(22.,1.1,22.));
 float patina=smoothstep(.40,.82,coarse)*(.5+streak*.5);
 base*=1.-wear*patina;
 base*=.95+.08*fine;
 if(textured){base*=texture(color_map,UV).rgb;NORMAL_MAP=texture(normal_map,UV).rgb;NORMAL_MAP_DEPTH=.45;}
 ALBEDO=base;
 ROUGHNESS=clamp(roughness_base+(coarse-.5)*.20,.15,1.);
 if(textured){ROUGHNESS=clamp(texture(rough_map,UV).r*.5+roughness_base*.5,.2,1.);}
 METALLIC=metallic_base;
}
