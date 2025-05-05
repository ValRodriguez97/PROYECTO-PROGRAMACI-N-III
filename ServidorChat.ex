#Este módulo lanza al servidor como proceso GenServer
defmodule ServidorChat do
  use GenServer

  def iniciar do
    GenServer.start_link(__MODULE__, %{
      salas: %{"general" => []},
      usuarios: %{}
    }, name: __MODULE__)
  end

  def unir_usuario(nombre_usuario, sala) do
    GenServer.call(__MODULE__, {:unir_usuario, nombre_usuario, sala})
  end

  def enviar_mensaje(sala, nombre_usuario, mensaje) do
    GenServer.cast(__MODULE__, {:enviar_mensaje, sala, nombre_usuario, mensaje})
  end

  def manejar_llamada({:unir_usuario, nombre, sala}, _origen, estado) do
    nueva_lista = Map.update(estado.salas, sala, [nombre], fn lista ->
      if nombre in lista, do: lista, else: [nombre | lista]
    end)

    nuevos_usuarios = Map.put(estado.usuarios, nombre, self())
    {:reply, :ok, %{estado | salas: nueva_lista, usuarios: nuevos_usuarios}}
  end

  def manejar_cast({:enviar_mensaje, sala, nombre, mensaje}, estado) do
    AlmacenamientoChat.guardar_mensaje(sala, nombre, mensaje)
    {:noreply, estado}
  end

  def handle_call(peticion, from, estado), do: manejar_llamada(peticion, from, estado)
  def handle_cast(peticion, estado), do: manejar_cast(peticion, estado)

  def main do
    IO.puts("Iniciando ServidorChat...")
    {:ok, _pid} = iniciar()
    Process.sleep(:infinity) # Mantiene el proceso vivo
  end
end
