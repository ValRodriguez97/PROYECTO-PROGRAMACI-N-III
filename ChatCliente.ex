defmodule ChatCliente do

  def main do
    iniciar("Maria", "general")
    enviar_mensaje("general", "Maria", "¡Buenas!")
  end

  def iniciar(nombre_usuario, sala) do
    IO.puts("Conectando usuario #{nombre_usuario} a la sala #{sala}...")
    SalaChat.unirse_sala(nombre_usuario, sala)
  end

  def enviar_mensaje(sala, usuario, mensaje) do
    SalaChat.enviar_mensaje(sala, usuario, mensaje)
  end
end
