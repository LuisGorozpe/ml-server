c = get_config()  # noqa

c.JupyterHub.bind_url = "http://0.0.0.0:8888"

# Abrir JupyterLab (no el notebook clásico) al entrar
c.Spawner.default_url = "/lab"

# Obligatorio en JupyterHub >= 5: sin esto, nadie puede entrar
c.Authenticator.allowed_users = {"datalab"}
c.Authenticator.admin_users = {"datalab"}

# Variables que los usuarios spawneados necesitan y que
# el spawner no hereda por sí solo:
c.Spawner.environment = {
    # ':' inicial = "mi depot personal primero, luego el compartido"
    "JULIA_DEPOT_PATH": ":/opt/julia-depot",
    "RUSTUP_HOME": "/opt/rustup",
}