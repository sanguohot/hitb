defmodule HitbWeb.PeerController do
  use HitbWeb, :controller
  alias Hitb
  @moduledoc """
    Functionality for managing peers
  """

  def add_peer(conn, peer_data) do
    %{"host" => host, "port" => port} = peer_data
    result = Peers.P2pSessionManager.connect(host, port)
    if result == :fail do
      raise Hitb.ErrorAlreadyConnected
    else
      json(conn, %{result: [host <> ":" <> port <> "节点连接成功"]})
    end
  end

  def get_all_peers(conn, _) do
    peers = :ets.tab2list(:peers)
      |> Enum.map(fn (peer_entry) ->
        peer_entry |> elem(1)
      end)
      json(conn,  %{peers: peers})
  end

  def getPeers(conn, _) do
    json(conn, %{})
  end

  def getPeer(conn, _) do
    json(conn, %{})
  end

  def version(conn, _) do
    json(conn, %{})
  end
end