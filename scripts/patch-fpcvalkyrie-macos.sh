#!/usr/bin/env bash
set -euo pipefail

valkyrie_root="${1:-${FPCVALKYRIE_ROOT:-../fpcvalkyrie}}"

if [[ ! -d "$valkyrie_root/libs" ]]; then
  echo "fpcvalkyrie libs directory not found: $valkyrie_root/libs" >&2
  exit 1
fi

sdl_lib="$valkyrie_root/libs/vsdl3library.pas"
sdl_image_lib="$valkyrie_root/libs/vsdl3imagelibrary.pas"
sdl_mixer_lib="$valkyrie_root/libs/vsdl3mixerlibrary.pas"
gl_lib="$valkyrie_root/libs/vgl3library.pas"
sdl_io="$valkyrie_root/src/vsdlio.pas"
sprite_engine="$valkyrie_root/src/vspriteengine.pas"
quad_arrays="$valkyrie_root/src/vglquadarrays.pas"

for file in "$sdl_lib" "$sdl_image_lib" "$sdl_mixer_lib" "$gl_lib" "$sdl_io" "$sprite_engine" "$quad_arrays"; do
  if [[ ! -f "$file" ]]; then
    echo "Required fpcvalkyrie file not found: $file" >&2
    exit 1
  fi
done

perl -0pi -e "s/SDL3DefaultPath = 'SDL3\\.framework\\/SDL3';\\n\\s*\\{\\\$linklib SDLmain\\}\\n\\s*\\{\\\$linkframework Cocoa\\}\\n\\s*\\{\\\$linkframework SDL\\}\\n\\s*\\{\\\$PASCALMAINNAME SDL_main\\}/SDL3DefaultPath = 'libSDL3.dylib';\\n    {\\\$linkframework Cocoa}/" "$sdl_lib"
perl -0pi -e "s/SDL3ImageDefaultPath = 'SDL3_image\\.framework\\/SDL_image';/SDL3ImageDefaultPath = 'libSDL3_image.dylib';/" "$sdl_image_lib"
perl -0pi -e "s/SDL3MixerDefaultPath = 'SDL3_mixer\\.framework\\/SDL3_mixer';\\n\\s*\\{\\\$linklib SDLmain\\}\\n\\s*\\{\\\$linkframework Cocoa\\}\\n\\s*\\{\\\$linkframework SDL\\}\\n\\s*\\{\\\$PASCALMAINNAME SDL_main\\}/SDL3MixerDefaultPath = 'libSDL3_mixer.dylib';\\n    {\\\$linkframework Cocoa}/" "$sdl_mixer_lib"

if ! grep -q 'DarwinGLGetProcAddress' "$gl_lib"; then
  perl -0pi -e 's/implementation\n\nuses math;/implementation\n\nuses math\n  {\$IFDEF DARWIN}, vsdl3library {\$ENDIF};\n\n{\$IFDEF DARWIN}\nfunction DarwinGLGetProcAddress( name : PGLchar ) : PGLvoid; cdecl;\nbegin\n  Exit( SDL_GL_GetProcAddress( name ) );\nend;\n{\$ENDIF}/' "$gl_lib"
  perl -0pi -e "s/\\{\\\$IFDEF UNIX\\}\\n  Pointer\\( glExtLoader \\) := GetSymbol\\( 'glXGetProcAddress' \\);\\n\\{\\\$ELSE\\}\\n  Pointer\\( glExtLoader \\) := GetSymbol\\( 'wglGetProcAddress' \\);\\n\\{\\\$ENDIF\\}/{\\\$IFDEF DARWIN}\\n  Pointer( glExtLoader ) := \\@DarwinGLGetProcAddress;\\n{\\\$ELSE}\\n{\\\$IFDEF UNIX}\\n  Pointer( glExtLoader ) := GetSymbol( 'glXGetProcAddress' );\\n{\\\$ELSE}\\n  Pointer( glExtLoader ) := GetSymbol( 'wglGetProcAddress' );\\n{\\\$ENDIF}\\n{\\\$ENDIF}/" "$gl_lib"
fi

perl -0pi -e 's/iLast  := -1;\n  i      := 0;\n  while iModes\[i\] <> nil do\n  begin\n    iMode := iModes\[i\];/iLast := -1;\n  for i := 0 to iCount - 1 do\n  begin\n    iMode := iModes[i];\n    if iMode = nil then Continue;/' "$sdl_io"
perl -0pi -e 's/\n    Inc\( i \);//' "$sdl_io"

# FPC 3.2.x on macOS/ARM64 can mis-pass the large packed quad color record by
# value, shifting following arguments so texture coordinates receive color data.
perl -0pi -e 's/(; )aColorQuad : TGLQVec4f/$1const aColorQuad : TGLQVec4f/g; s/(; )aColorQuad: TGLQVec4f/$1const aColorQuad: TGLQVec4f/g' "$sprite_engine" "$quad_arrays"

if grep -R -n -E 'linklib SDLmain|linkframework SDL|PASCALMAINNAME SDL_main' "$sdl_lib" "$sdl_mixer_lib"; then
  echo "macOS SDL3 patch did not remove obsolete SDL framework link directives." >&2
  exit 1
fi

if grep -q 'glXGetProcAddress' "$gl_lib" && ! grep -q 'DarwinGLGetProcAddress' "$gl_lib"; then
  echo "macOS OpenGL loader patch was not applied." >&2
  exit 1
fi

if grep -R -n -E '; aColorQuad ?: TGLQVec4f' "$sprite_engine" "$quad_arrays"; then
  echo "macOS ARM64 quad ABI patch was not applied." >&2
  exit 1
fi

echo "Patched fpcvalkyrie macOS SDL3/OpenGL compatibility in $valkyrie_root"
