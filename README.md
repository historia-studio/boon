# Boon

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Cloudflare Tunnel On Windows

`cloudflared` can expose the local Phoenix app without opening inbound ports on your router.

### Quick temporary tunnel

Use this when you want a fast test URL and do not care if the hostname changes:

```powershell
start.bat
cloudflared tunnel --url http://localhost:4000
```

Or use the helper script in this repo:

```powershell
start-cloudflared-quick.bat
```

Cloudflare will print a temporary `https://...trycloudflare.com` URL.

### Stable named tunnel

Use this when you want a fixed hostname such as `boon.example.com`.

1. Pick a hostname that is already managed in your Cloudflare account.
2. Authenticate `cloudflared` with your browser:

```powershell
cloudflared tunnel login
```

3. Create a tunnel:

```powershell
cloudflared tunnel create boon
```

4. Copy `cloudflared/config.example.yml` to `cloudflared/config.yml`.
5. Fill in:
	* your tunnel UUID
	* your credentials file path
	* your public hostname
6. Create the DNS route:

```powershell
cloudflared tunnel route dns boon YOUR_HOSTNAME
```

7. Start the Phoenix app and then run the tunnel:

```powershell
start.bat
start-cloudflared-named.bat
```

### Notes

* The local Phoenix dev endpoint already listens on `0.0.0.0:4000`, so the tunnel can reach it directly.
* For a long-lived deployment, a production release is better than `mix phx.server`, but the tunnel works with the current dev setup for controlled access.
* If you switch to a production release later, set `PHX_HOST` to the public hostname served by Cloudflare.

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
