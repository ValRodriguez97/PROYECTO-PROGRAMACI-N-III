# ChatApp - Aplicación de Chat Distribuido

Proyecto final del curso **Programación III**  
Universidad del Quindío – Facultad de Ingeniería

Grupo:
Raquel López Aristizábal
Valentina Rodríguez Castro
Leidy Vanesa Muñoz Bolaños

--- 

## Descripción

**ChatApp** es una aplicación de mensajería en tiempo real desarrollada en Elixir bajo un modelo cliente-servidor. Permite la conexión concurrente de múltiples usuarios, el uso de salas de conversación, la persistencia de mensajes y la ejecución de comandos desde terminal.

---

## Funcionalidades principales

- Conexión simultánea de múltiples usuarios.
- Creación, unión y abandono de salas de chat.
- Envío y recepción de mensajes en tiempo real.
- Historial de conversaciones persistente.
- Comandos del sistema:
  - `/list` → listar usuarios conectados
  - `/create <sala>` → crear una sala
  - `/join <sala>` → unirse a una sala
  - `/history` → consultar historial de la sala
  - `/exit` → salir del chat

---

## Estructura del proyecto

chat_app/
├── lib/
│ ├── ChatApp.ex
│ ├── application.ex
│ ├── chat_server.ex
│ ├── chat_session.ex
│ ├── chat_user.ex
│ ├── chat_persistence.ex
│ └── chat_utils.ex
├── iniciar_servidor.sh
├── iniciar_cliente.sh
├── mix.exs

