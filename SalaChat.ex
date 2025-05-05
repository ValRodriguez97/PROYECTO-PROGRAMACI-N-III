defmodule SalaChat do

  def main do
    IO.puts("Prueba de SalaChat...")
    unirse_sala("Vanesa", "soporte")
    enviar_mensaje("soporte", "Vanesa", "¿Hay alguien ahí?")
  end
  def unirse_sala(usuario, sala) do
    ServidorChat.unir_usuario(usuario, sala)
  end

  def enviar_mensaje(sala, usuario, mensaje) do
    ServidorChat.enviar_mensaje(sala, usuario, mensaje)
  end

end
