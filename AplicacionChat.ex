defmodule AplicacionChat do
  def main do
    iniciar()
    ChatCliente.iniciar_chat()
  end
  def iniciar do
    IO.puts("Iniciando aplicación de chat...")
    {:ok, _pid} = ServidorChat.iniciar()
    :ok
  end
end
AplicacionChat.main()
