defmodule ChatServer do
  @moduledoc """
  Módulo que implementa el servidor de chat.
  Gestiona usuarios, salas y mensajes.
  """
  use GenServer
  require Logger

  # Nombre global para el registro del servidor
  @nombre_servidor :chat_servidor

  # Archivos para persistencia
  @archivo_mensajes "datos_chat/historial_mensajes.dat"
  @archivo_salas "datos_chat/salas.dat"
  @archivo_usuarios "datos_chat/usuarios.dat"

  # API PÚBLICA

  @doc """
  Inicia el servidor de chat.
  """
  def iniciar do
    # Usar un timeout más grande para inicialización
    {:ok, _servidor_pid} = GenServer.start_link(ChatServer, :ok, name: {:global, :chat_servidor})
  end


  @doc """
  Registra un nuevo usuario.
  """
  def registrar_usuario(username, password, client_pid, client_node) do
    GenServer.call({:global, @nombre_servidor}, {:registrar_usuario, username, password, client_pid, client_node})
  end

  @doc """
  Autentica a un usuario.
  """
  def autenticar(username, password, client_pid, client_node) do
    GenServer.call({:global, @nombre_servidor}, {:autenticar, username, password, client_pid, client_node})
  end

  @doc """
  Da de baja a un usuario (desconexión).
  """
  def dar_baja_usuario(username) do
    GenServer.cast({:global, @nombre_servidor}, {:dar_baja, username})
  end

  @doc """
  Crea una nueva sala de chat.
  """
  def crear_sala(username, nombre_sala) do
    GenServer.call({:global, @nombre_servidor}, {:crear_sala, username, nombre_sala})
  end

  @doc """
  Une a un usuario a una sala existente.
  """
  def unirse_sala(username, nombre_sala) do
    GenServer.call({:global, @nombre_servidor}, {:unirse_sala, username, nombre_sala})
  end

  @doc """
  Envía un mensaje a una sala.
  """
  def enviar_mensaje(username, nombre_sala, mensaje) do
    GenServer.cast({:global, @nombre_servidor}, {:enviar_mensaje, username, nombre_sala, mensaje})
  end

  @doc """
  Lista los usuarios conectados.
  """
  def listar_usuarios do
    GenServer.call({:global, @nombre_servidor}, :listar_usuarios)
  end

  @doc """
  Lista las salas disponibles.
  """
  def listar_salas do
    GenServer.call({:global, @nombre_servidor}, :listar_salas)
  end

  @doc """
  Obtiene el historial de mensajes de una sala.
  """
  def obtener_historial_sala(nombre_sala) do
    GenServer.call({:global, @nombre_servidor}, {:obtener_historial, nombre_sala}, 10000)  # Timeout extendido
  end

  # CALLBACKS DEL GENSERVER

  @impl true
  def init(:ok) do
    Logger.info("Servidor de chat iniciado en nodo #{Node.self()}")
    Process.flag(:trap_exit, true)

    # Crear directorio para datos si no existe
    File.mkdir_p!("datos_chat")

    # Cargar datos guardados
    mensajes = cargar_mensajes_desde_archivo()
    salas = cargar_salas_desde_archivo()
    usuarios = cargar_usuarios_desde_archivo()

    # Inicializar salas si no existen
    salas = if map_size(salas) == 0 do
      %{}
    else
      salas
    end

    # Verificar que cada sala tenga una entrada en mensajes
    mensajes = Enum.reduce(Map.keys(salas), mensajes, fn nombre_sala, acc ->
      if not Map.has_key?(acc, nombre_sala) do
        Map.put(acc, nombre_sala, [])
      else
        acc
      end
    end)

    # Limpiar usuarios_conectados al inicio para evitar conexiones fantasma
    estado = %{
      usuarios_conectados: %{},  # %{username => {pid, node}}
      salas: salas,              # %{nombre_sala => %{creador: username, miembros: [username]}}
      mensajes: mensajes,        # %{nombre_sala => [{from, message, timestamp}]}
      usuarios: usuarios         # %{username => password_hash}
    }

    # Asegurar que el servidor esté registrado globalmente
    :global.register_name(@nombre_servidor, self())

    # Configurar monitor de nodos para detectar desconexiones
    :net_kernel.monitor_nodes(true)

    {:ok, estado}
  end

  @impl true
  def handle_call({:registrar_usuario, username, password, client_pid, client_node}, _from, estado) do
    Logger.info("Registrando nuevo usuario: #{username} desde #{client_node}")

    # Verificar si el usuario ya existe
    if Map.has_key?(estado.usuarios, username) do
      {:reply, {:error, :usuario_existente}, estado}
    else
      # Hashear la contraseña
      password_hash = :crypto.hash(:sha256, password) |> Base.encode16()

      # Añadir usuario a la base de datos
      nuevos_usuarios = Map.put(estado.usuarios, username, password_hash)

      # Añadir el usuario a los conectados
      monitor_ref = Process.monitor(client_pid)
      nuevos_conectados = Map.put(estado.usuarios_conectados, username, {client_pid, client_node, monitor_ref})

      # Actualizar estado
      nuevo_estado = %{estado |
        usuarios: nuevos_usuarios,
        usuarios_conectados: nuevos_conectados
      }

      # Persistir cambios
      guardar_usuarios_en_archivo(nuevo_estado.usuarios)

      # Notificar a todos los usuarios conectados
      broadcast_mensaje_sistema("#{username} se ha registrado y unido al chat", nuevo_estado)

      {:reply, {:ok, username}, nuevo_estado}
    end
  end

  @impl true
  def handle_call({:autenticar, username, password, client_pid, client_node}, _from, estado) do
    Logger.info("Intentando autenticar usuario: #{username} desde #{client_node}")

    # Hashear la contraseña proporcionada
    password_hash = :crypto.hash(:sha256, password) |> Base.encode16()

    # Verificar credenciales
    if Map.has_key?(estado.usuarios, username) && estado.usuarios[username] == password_hash do
      # Si el usuario ya está conectado, desconectar la sesión anterior
      nuevo_estado = if Map.has_key?(estado.usuarios_conectados, username) do
        {old_pid, _old_node, old_ref} = estado.usuarios_conectados[username]
        Process.demonitor(old_ref)
        # Intentar notificar al cliente anterior que ha sido desconectado
        try do
          send(old_pid, {:desconexion_forzada, "Tu sesión ha sido iniciada en otra terminal"})
        catch
          :exit, _ -> :ok  # Ignorar si el proceso ya no existe
        end
        Logger.info("Usuario #{username} ya conectado, desconectando sesión anterior")
      else
        estado
      end

      # Monitorear el proceso cliente para detectar desconexiones
      monitor_ref = Process.monitor(client_pid)

      # Actualizar la información de conexión
      nuevos_conectados = Map.put(nuevo_estado.usuarios_conectados, username, {client_pid, client_node, monitor_ref})
      nuevo_estado = %{nuevo_estado | usuarios_conectados: nuevos_conectados}

      broadcast_mensaje_sistema("#{username} se ha unido al chat", nuevo_estado)

      {:reply, {:ok, username}, nuevo_estado}
    else
      {:reply, {:error, :auth_fallida}, estado}
    end
  end

  @impl true
  def handle_call({:crear_sala, username, nombre_sala}, _from, estado) do
    Logger.info("Creando sala: #{nombre_sala} por usuario #{username}")

    # Verificar si la sala ya existe
    if Map.has_key?(estado.salas, nombre_sala) do
      {:reply, {:error, :sala_existente}, estado}
    else
      # Crear la sala
      sala = %{creador: username, miembros: [username]}
      nuevas_salas = Map.put(estado.salas, nombre_sala, sala)
      nuevos_mensajes = Map.put(estado.mensajes, nombre_sala, [])

      # Actualizar estado
      nuevo_estado = %{estado | salas: nuevas_salas, mensajes: nuevos_mensajes}

      # Persistir cambios
      guardar_salas_en_archivo(nuevo_estado.salas)
      guardar_mensajes_en_archivo(nuevo_estado.mensajes)

      # Notificar a todos los usuarios
      broadcast_mensaje_sistema("Nueva sala creada: #{nombre_sala}", nuevo_estado)

      {:reply, :ok, nuevo_estado}
    end
  end

  @impl true
  def handle_call({:unirse_sala, username, nombre_sala}, _from, estado) do
    Logger.info("Usuario #{username} uniéndose a sala #{nombre_sala}")

    # Verificar si la sala existe
    if not Map.has_key?(estado.salas, nombre_sala) do
      {:reply, {:error, :sala_no_encontrada}, estado}
    else
      sala = estado.salas[nombre_sala]

      # Verificar si el usuario ya está en la sala
      if username in sala.miembros do
        {:reply, :ok, estado}  # Ya está en la sala, sin error
      else
        # Añadir usuario a la sala
        miembros_actualizados = [username | sala.miembros]
        sala_actualizada = %{sala | miembros: miembros_actualizados}
        nuevas_salas = Map.put(estado.salas, nombre_sala, sala_actualizada)

        # Actualizar estado
        nuevo_estado = %{estado | salas: nuevas_salas}

        # Persistir cambios
        guardar_salas_en_archivo(nuevo_estado.salas)

        # Notificar a los miembros de la sala
        notificar_miembros_sala(nombre_sala, "#{username} se ha unido a la sala", nuevo_estado)

        {:reply, :ok, nuevo_estado}
      end
    end
  end

  @impl true
  def handle_call(:listar_usuarios, _from, estado) do
    {:reply, Map.keys(estado.usuarios_conectados), estado}
  end

  @impl true
  def handle_call(:listar_salas, _from, estado) do
    {:reply, Map.keys(estado.salas), estado}
  end

  @impl true
  def handle_call({:obtener_historial, nombre_sala}, _from, estado) do
    mensajes = if Map.has_key?(estado.mensajes, nombre_sala) do
      # Invertir para tener los mensajes en orden cronológico
      Enum.reverse(estado.mensajes[nombre_sala])
    else
      []
    end

    {:reply, mensajes, estado}
  end

  @impl true
  def handle_cast({:enviar_mensaje, username, nombre_sala, mensaje}, estado) do
    Logger.debug("Mensaje en #{nombre_sala} de #{username}: #{mensaje}")

    # Verificar si la sala existe
    if not Map.has_key?(estado.salas, nombre_sala) do
      {:noreply, estado}
    else
      sala = estado.salas[nombre_sala]

      # Verificar si el usuario está en la sala
      nuevo_estado = if username not in sala.miembros do
        # Si el usuario no está en la sala, añadirlo automáticamente
        miembros_actualizados = [username | sala.miembros]
        sala_actualizada = %{sala | miembros: miembros_actualizados}
        nuevas_salas = Map.put(estado.salas, nombre_sala, sala_actualizada)
        %{estado | salas: nuevas_salas}
      else
        estado
      end

      # Guardar el mensaje
      timestamp = :os.system_time(:millisecond)
      mensajes_sala = if Map.has_key?(nuevo_estado.mensajes, nombre_sala) do
        [{username, mensaje, timestamp} | nuevo_estado.mensajes[nombre_sala]]
      else
        [{username, mensaje, timestamp}]
      end

      nuevos_mensajes = Map.put(nuevo_estado.mensajes, nombre_sala, mensajes_sala)

      # Actualizar estado
      nuevo_estado = %{nuevo_estado | mensajes: nuevos_mensajes}

      # Persistir mensajes periódicamente (no en cada mensaje para mejorar rendimiento)
      if :rand.uniform(10) == 1 do
        guardar_mensajes_en_archivo(nuevo_estado.mensajes)
      end

      # Enviar mensaje a todos los miembros de la sala, incluido el remitente
      sala = nuevo_estado.salas[nombre_sala]
      Enum.each(sala.miembros, fn miembro ->
        case Map.get(nuevo_estado.usuarios_conectados, miembro) do
          {pid, _, _} ->
            try do
              send(pid, {:mensaje_chat, nombre_sala, username, mensaje, timestamp})
            catch
              :exit, _ -> Logger.warning("Error al enviar mensaje a #{miembro} - proceso no disponible")
              _ -> Logger.warning("Error al enviar mensaje a #{miembro}")
            end
          _ -> :ok
        end
      end)

      {:noreply, nuevo_estado}
    end
  end

  @impl true
  def handle_cast({:dar_baja, username}, estado) do
    Logger.info("Usuario #{username} desconectado")

    # Limpiar monitor si existe
    if Map.has_key?(estado.usuarios_conectados, username) do
      {_, _, ref} = estado.usuarios_conectados[username]
      Process.demonitor(ref)
    end

    # Eliminar usuario de la lista de conectados
    {_, nuevos_conectados} = Map.pop(estado.usuarios_conectados, username)

    # No eliminar usuario de las salas para mantener el historial
    # Solo anunciar que se ha desconectado
    broadcast_mensaje_sistema("#{username} ha salido del chat", %{estado | usuarios_conectados: nuevos_conectados})

    {:noreply, %{estado | usuarios_conectados: nuevos_conectados}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, reason}, estado) do
    # Buscar el usuario correspondiente al PID caído
    username = Enum.find_value(estado.usuarios_conectados, fn {username, {client_pid, _, client_ref}} ->
      if client_pid == pid or client_ref == ref, do: username, else: nil
    end)

    if username do
      Logger.info("Detectada caída de proceso para usuario #{username}: #{inspect(reason)}")
      handle_cast({:dar_baja, username}, estado)
    else
      {:noreply, estado}
    end
  end

  @impl true
  def handle_info({:nodedown, node}, estado) do
    Logger.warning("Nodo desconectado: #{node}")

    # Identificar usuarios conectados desde ese nodo
    usuarios_a_desconectar = Enum.filter(estado.usuarios_conectados, fn {_, {_, client_node, _}} ->
      client_node == node
    end)
    |> Enum.map(fn {username, _} -> username end)

    # Dar de baja a todos los usuarios de ese nodo
    nuevo_estado = Enum.reduce(usuarios_a_desconectar, estado, fn username, acc_estado ->
      {_, _, ref} = acc_estado.usuarios_conectados[username]
      Process.demonitor(ref)
      {_, nuevos_conectados} = Map.pop(acc_estado.usuarios_conectados, username)
      %{acc_estado | usuarios_conectados: nuevos_conectados}
    end)

    if usuarios_a_desconectar != [] do
      nombres = Enum.join(usuarios_a_desconectar, ", ")
      broadcast_mensaje_sistema("Los usuarios #{nombres} han sido desconectados debido a la caída del nodo #{node}", nuevo_estado)
    end

    {:noreply, nuevo_estado}
  end

  @impl true
  def handle_info({:nodeup, node}, estado) do
    Logger.info("Nodo conectado: #{node}")
    {:noreply, estado}
  end

  @impl true
  def terminate(reason, estado) do
    Logger.info("Servidor terminando: #{inspect(reason)}")
    # Guardar estado al terminar
    guardar_mensajes_en_archivo(estado.mensajes)
    guardar_salas_en_archivo(estado.salas)
    guardar_usuarios_en_archivo(estado.usuarios)
    :ok
  end

  # FUNCIONES PRIVADAS

  # Busca un usuario por su PID
  defp encontrar_usuario_por_pid(pid, usuarios_conectados) do
    Enum.find_value(usuarios_conectados, fn {username, {client_pid, _, _}} ->
      if client_pid == pid, do: username, else: nil
    end)
  end

  # Envía un mensaje a todos los usuarios conectados
  defp broadcast_mensaje_sistema(mensaje, estado) do
    Enum.each(estado.usuarios_conectados, fn {_, {pid, _, _}} ->
      try do
        send(pid, {:mensaje_sistema, mensaje})
      catch
        :exit, _ -> :ok  # Ignorar si el proceso ya no existe
        _ -> :ok  # Ignorar otros errores
      end
    end)
  end

  # Envía un mensaje a todos los miembros de una sala
  defp notificar_miembros_sala(nombre_sala, mensaje, estado) do
    if Map.has_key?(estado.salas, nombre_sala) do
      Enum.each(estado.salas[nombre_sala].miembros, fn miembro ->
        case Map.get(estado.usuarios_conectados, miembro) do
          {pid, _, _} ->
            try do
              send(pid, {:mensaje_sistema, "[#{nombre_sala}] #{mensaje}"})
            catch
              :exit, _ -> :ok  # Ignorar si el proceso ya no existe
              _ -> :ok  # Ignorar otros errores
            end
          _ -> :ok
        end
      end)
    end
  end

  # Persistencia de mensajes
  defp guardar_mensajes_en_archivo(mensajes) do
    try do
      File.write!(@archivo_mensajes, :erlang.term_to_binary(mensajes))
    rescue
      e ->
        Logger.error("Error al guardar mensajes: #{inspect(e)}")
        :error
    end
  end

  defp cargar_mensajes_desde_archivo do
    try do
      case File.read(@archivo_mensajes) do
        {:ok, binary} -> :erlang.binary_to_term(binary)
        {:error, _} -> %{}  # Archivo no existe, retornar mapa vacío
      end
    rescue
      e ->
        Logger.error("Error al cargar mensajes: #{inspect(e)}")
        %{}
    end
  end

  # Persistencia de salas
  defp guardar_salas_en_archivo(salas) do
    try do
      File.write!(@archivo_salas, :erlang.term_to_binary(salas))
    rescue
      e ->
        Logger.error("Error al guardar salas: #{inspect(e)}")
        :error
    end
  end

  defp cargar_salas_desde_archivo do
    try do
      case File.read(@archivo_salas) do
        {:ok, binary} -> :erlang.binary_to_term(binary)
        {:error, _} -> %{}  # Archivo no existe, retornar mapa vacío
      end
    rescue
      e ->
        Logger.error("Error al cargar salas: #{inspect(e)}")
        %{}
    end
  end

  # Persistencia de usuarios
  defp guardar_usuarios_en_archivo(usuarios) do
    try do
      File.write!(@archivo_usuarios, :erlang.term_to_binary(usuarios))
    rescue
      e ->
        Logger.error("Error al guardar usuarios: #{inspect(e)}")
        :error
    end
  end

  defp cargar_usuarios_desde_archivo do
    try do
      case File.read(@archivo_usuarios) do
        {:ok, binary} -> :erlang.binary_to_term(binary)
        {:error, _} ->
          # Crear usuarios predeterminados
          %{
            "raque" => :crypto.hash(:sha256, "2820") |> Base.encode16(),
            "valen" => :crypto.hash(:sha256, "poseidon") |> Base.encode16(),
            "vane" => :crypto.hash(:sha256, "1419") |> Base.encode16()
          }
      end
    rescue
      e ->
        Logger.error("Error al cargar usuarios: #{inspect(e)}")
        # Usuarios predeterminados
        %{
          "raque" => :crypto.hash(:sha256, "2820") |> Base.encode16(),
          "valen" => :crypto.hash(:sha256, "poseidon") |> Base.encode16(),
          "vane" => :crypto.hash(:sha256, "1419") |> Base.encode16()
        }
    end
  end
end
