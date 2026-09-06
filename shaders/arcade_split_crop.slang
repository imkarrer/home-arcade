#version 450

// Display-only zoom into one player's split region. Netplay is unchanged.

layout(push_constant) uniform Push
{
   vec4 SourceSize;
   vec4 OriginalSize;
   vec4 OutputSize;
   uint FrameCount;
   float CROP_ENABLED;
   float CROP_X;
   float CROP_Y;
   float CROP_W;
   float CROP_H;
} params;

layout(std140, set = 0, binding = 0) uniform UBO
{
   mat4 MVP;
} global;

#pragma parameter CROP_ENABLED "Crop enabled" 0.0 0.0 1.0 1.0
#pragma parameter CROP_X "Crop X" 0.0 0.0 1.0 0.001
#pragma parameter CROP_Y "Crop Y" 0.0 0.0 1.0 0.001
#pragma parameter CROP_W "Crop W" 1.0 0.0 1.0 0.001
#pragma parameter CROP_H "Crop H" 1.0 0.0 1.0 0.001

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;
layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
   if (params.CROP_ENABLED < 0.5)
   {
      FragColor = vec4(texture(Source, vTexCoord).rgb, 1.0);
      return;
   }

   float w = max(params.CROP_W, 0.0001);
   float h = max(params.CROP_H, 0.0001);
   vec2 uv = vec2(
      params.CROP_X + vTexCoord.x * w,
      params.CROP_Y + vTexCoord.y * h
   );
   uv = clamp(uv, vec2(0.0), vec2(1.0));
   FragColor = vec4(texture(Source, uv).rgb, 1.0);
}
