// Scorio's liquid glass lens: what a floating glass control does to the
// screen behind it, in one pass over the (already frosted) backdrop.
//
// The optics follow iOS 26 Liquid Glass. The control is a slab with a
// rounded bevel along its edge, so light passing near the edge is bent
// inward: the content behind is pulled toward the centre and squeezed into
// the rim. The flat middle passes the backdrop straight through. A thin specular rim
// catches a light from the top left, with a softer reflection on the far
// side, and the glass lifts colour so the frost never looks grey.
//
// Applied as a BackdropFilter's ImageFilter.shader (Impeller only), so
// uSize and uTexture are filled in by Flutter: the backdrop and its size.

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;     // 0-1   the backdrop texture, in physical px
uniform vec4 uRect;     // 2-5   the glass: origin xy, size zw, in that space
uniform float uRadius;  // 6     corner radius, px
uniform float uBevel;   // 7     width of the curved edge, px
uniform float uBend;    // 8     how strongly the edge bends (refractive index - 1)
uniform vec4 uTint;     // 9-12  glass colour: rgb, and how much of it
uniform float uShade;   // 13    how much the body darkens (dark glass)
uniform float uSat;     // 14    colour lift
uniform float uRim;     // 15    rim light strength
uniform float uPx;      // 16    physical px per logical px
uniform float uDark;    // 17    1 on dark glass, 0 on light

uniform sampler2D uTexture;

out vec4 fragColor;

vec4 sampleAt(vec2 frag) {
  vec2 uv = clamp(frag / uSize, vec2(0.0), vec2(1.0));
#if defined(IMPELLER_TARGET_OPENGLES) && \
    !defined(IMPELLER_OPENGLES_UNFLIPPED_DEPRECATED)
  uv.y = 1.0 - uv.y;
#endif
  return texture(uTexture, uv);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 halfSize = uRect.zw * 0.5;
  vec2 p = frag - (uRect.xy + halfSize);
  float r = min(uRadius, min(halfSize.x, halfSize.y));

  // Rounded-rect distance: negative inside, 0 on the edge.
  vec2 q = abs(p) - halfSize + r;
  float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
  float inset = max(-d, 0.0);

  // The outward normal of the nearest edge.
  vec2 s = vec2(p.x < 0.0 ? -1.0 : 1.0, p.y < 0.0 ? -1.0 : 1.0);
  vec2 n;
  if (q.x > 0.0 && q.y > 0.0) {
    n = normalize(q) * s;
  } else if (q.x > q.y) {
    n = vec2(s.x, 0.0);
  } else {
    n = vec2(0.0, s.y);
  }

  // The bevel: a quarter circle, steepest at the edge, flat after uBevel.
  float t = clamp(inset / max(uBevel, 1.0), 0.0, 1.0);
  float slope = 1.0 - t;
  float bend = slope * slope;

  // Paraxial refraction: sample from further in, so the edge shows content
  // squeezed in from under the glass. Never past the middle of the shape.
  vec2 offset = -n * bend * uBend * uBevel * 6.0;
  float reach = 0.5 * min(uRect.z, uRect.w);
  float len = length(offset);
  if (len > reach) offset *= reach / len;

  // A trace of dispersion in the curve only, as real glass does.
  vec3 col;
  vec4 mid = sampleAt(frag + offset);
  col.r = sampleAt(frag + offset * 1.03).r;
  col.g = mid.g;
  col.b = sampleAt(frag + offset * 0.97).b;
  // Inside a fade the backdrop is the fade's own layer, empty where nothing
  // has been drawn yet. Glass over nothing is clear, not white: keep the
  // backdrop's coverage, so the card fades in with the rest of the page.
  float cover = mid.a;
  col /= max(cover, 0.001);

  // Colour lift, then the glass's own colour and shade.
  float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
  col = mix(vec3(luma), col, uSat);
  col *= 1.0 - uShade;
  col = mix(col, uTint.rgb, uTint.a);

  // Light from the top left; the far side catches a weaker reflection.
  vec2 light = normalize(vec2(-0.55, -0.83));
  float lit = max(dot(n, light), 0.0);
  float opp = max(dot(n, -light), 0.0);
  float lobe = lit * lit * lit + 0.85 * opp * opp * opp;

  // A hairline of specular right on the edge, bright where it faces the
  // light and the far side, faint along the sides.
  float px = uPx;
  float rimBand = exp(-inset / (mix(0.45, 0.75, uDark) * px));
  // On light glass the rim is only a whisper: white on a pale body reads
  // bold fast, and iOS light glass shows just a faint brighter line.
  col += vec3(uRim * rimBand * (0.16 + 0.10 * lobe) * mix(0.3, 1.0, uDark));

  // On light glass a faint shadow line under the highlight gives the edge
  // its definition against a light page.
  float shadeLine = (1.0 - uDark) *
      (1.0 - smoothstep(0.0, 0.9 * px, inset)) * (1.0 - 0.6 * lobe);
  col *= 1.0 - 0.035 * uRim * shadeLine;

  fragColor = vec4(clamp(col, 0.0, 1.0) * cover, cover);
}
