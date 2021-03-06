defmodule Block.P2pSessionManager do
  @moduledoc """
  Oversees clients for each p2p session, using them to send messages.
  """
  alias Block.P2pClientHandler
  # @query_latest_block Repos.P2pMessage.query_latest_block
  # @query_all_blocks   Repos.P2pMessage.query_all_blocks
  # @update_block_chain Repos.P2pMessage.update_block_chain
  # @add_peer_request   Repos.P2pMessage.add_peer_request

  def connect(host, port) do
    _already_connected = :ets.tab2list(:peers) |> Enum.reduce(false, fn(record, acc) ->
        if acc == false do
          peer_map = record |> elem(1)
          if peer_map[:host] == host && peer_map[:port] == port do
            true
          else
            false
          end
        end
      end)
    {:ok, pid} = P2pClientHandler.start_link(host, port)
    :ets.insert(:peers, {pid, %{host: host, port: port}})
    :ok
  end

  def broadcast(message) do
    :ets.tab2list(:peers)
    |> Enum.each(fn(peer_entry) ->
      pid = peer_entry |> elem(0)
      Process.send(pid, message, [])
    end)
  end

  def terminate_session(pid) do
    :ets.delete(:peers, pid)
    GenServer.stop(pid)
  end
end
