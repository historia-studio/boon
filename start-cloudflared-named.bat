@echo off
cd /d C:\Users\jesse\dev\boon

if not exist cloudflared/config.yml (
  echo Missing cloudflared/config.yml
  echo Copy cloudflared/config.example.yml to cloudflared/config.yml and fill in the tunnel details first.
  exit /b 1
)

cloudflared tunnel --config cloudflared/config.yml run