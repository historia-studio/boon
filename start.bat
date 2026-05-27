cd C:\Users\jesse\dev\boon
if "%PHX_PUBLIC_HOST%"=="" set PHX_PUBLIC_HOST=boon.historia.studio
if "%PHX_PUBLIC_SCHEME%"=="" set PHX_PUBLIC_SCHEME=https
if "%PHX_PUBLIC_PORT%"=="" set PHX_PUBLIC_PORT=443
mix compile
mix phx.server