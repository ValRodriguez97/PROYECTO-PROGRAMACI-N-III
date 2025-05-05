defmodule SalaChat do
  def unirse_sala(usuario, sala) do
    IO.puts("#{usuario} se ha unido a la sala #{sala}.")
  end

  def enviar_mensaje(sala, usuario, mensaje) do
    AlmacenamientoChat.guardar_mensaje(sala, usuario, mensaje)
  end

  def main do
    unirse_sala("Carlos", "soporte")
    enviar_mensaje("soporte", "Carlos", "¿Hay alguien?")
  end
end
