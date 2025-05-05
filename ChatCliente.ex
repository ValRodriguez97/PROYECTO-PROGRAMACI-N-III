#Este ejecuta el cliente interactivo con el servidor corriendo
defmodule ChatCliente do
  def iniciar_chat do
    IO.puts("Bienvenido, por favor ingrese su usuario:")
    usuario = IO.gets("> ") |> String.trim()

    IO.puts("Ahora por favor Ingrese el nombre de la sala a la que desea unirse:")
    sala = IO.gets("> ") |> String.trim()

    ServidorChat.unir_usuario(usuario, sala)
    ciclo_entrada(usuario, sala)
  end

  defp ciclo_entrada(usuario, sala) do
    entrada = IO.gets("> ") |> String.trim()

    case entrada do
      "/historial" ->
        AlmacenamientoChat.ver_historial(sala)
        ciclo_entrada(usuario, sala)

      "/salir" ->
        IO.puts("Sesión finalizada.")

      mensaje ->
        ServidorChat.enviar_mensaje(sala, usuario, mensaje)
        ciclo_entrada(usuario, sala)
    end
  end

  def main do
    iniciar_chat()
  end
end
