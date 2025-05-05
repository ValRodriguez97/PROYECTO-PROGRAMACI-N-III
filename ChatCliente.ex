defmodule ChatCliente do
  def main do
    iniciar()
  end

  defp iniciar do
    IO.puts("Señor Usuario, sea Bienvenido a su chat, por favor escriba su nombre: ")
    nombre=IO.gets(">") |> String.trim()
    ServidorChat.connect_user(self(), nombre)
    loop(nombre)
  end


end
