defmodule AlmacenamientoChat do
  def guardar_mensaje(sala, usuario, mensaje) do
    IO.puts("[#{sala}] #{usuario}: #{mensaje}")
  end

  def main do
    IO.puts("Probando AlmacenamientoChat...")
    guardar_mensaje("general", "Juan", "¡Hola a todos!")
  end
end
