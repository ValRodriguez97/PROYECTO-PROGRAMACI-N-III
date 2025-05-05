defmodule AplicacionChat do
  def iniciar do
    IO.puts("Iniciando aplicación de chat...")
    ServidorChat.iniciar()
    :ok
  end

  def main do
    iniciar()
  end
end
