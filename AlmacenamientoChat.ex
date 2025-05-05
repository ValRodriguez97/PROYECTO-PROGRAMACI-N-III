#Este módulo permite guardar y ver mensajes como prueba
defmodule AlmacenamientoChat do
  def guardar_mensaje(sala, usuario, mensaje) do
    File.write!("historial_#{sala}.txt", "[#{usuario}] #{mensaje}\n", [:append])
  end

  def ver_historial(sala) do
    case File.read("historial_#{sala}.txt") do
      {:ok, contenido} -> IO.puts(contenido)
      {:error, _} -> IO.puts("No hay historial para la sala #{sala}")
    end
  end

  def main do
    IO.puts("Probando AlmacenamientoChat...")
    guardar_mensaje("general", "Juan", "¡Hola a todos!")
    ver_historial("general")
  end
end
