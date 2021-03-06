defmodule Block.P2pClientHandler do
  @moduledoc """
  Receives and handles messages over websocket.
  Responsible for keeping the block chain in sync.
  """
  require Logger
  # import Ecto.Query
  # alias Block.PeerRepository
  alias Block.AccountRepository
  alias Block.BlockService
  alias Block.BlockRepository
  alias Phoenix.Channels.GenSocketClient
  alias Block.SyncService
  alias Block.P2pSessionManager
  alias Block.TransactionRepository
  alias Block.Stat.StatOrg, as: BlockStatOrg
  alias Block.Stat.StatCda, as: BlockStatCda
  alias Block.Edit.Cda, as: BlockCda
  alias Block.Edit.CdaFile, as: BlockCdaFIle
  alias Block.Library.Cdh, as: BlockCdh
  alias Block.Library.ChineseMedicinePatent, as: BlockChineseMedicinePatent
  alias Block.Library.ChineseMedicine, as: BlockChineseMedicine
  alias Block.Library.RuleMdc, as: BlockRuleMdc
  alias Block.Library.RuleAdrg, as: BlockRuleAdrg
  alias Block.Library.RuleDrg, as: BlockRuleDrg
  alias Block.Library.RuleIcd9, as: BlockRuleIcd9
  alias Block.Library.RuleIcd10, as: BlockRuleIcd10
  alias Block.Library.LibWt4, as: BlockLibWt4
  alias Block.Library.Wt4, as: BlockWt4



  @behaviour GenSocketClient

  # can't inherit attributes and use them inside matches, so this is necessary
  @sync_block     Block.P2pMessage.sync_block
  @query_all_accounts   Block.P2pMessage.query_all_accounts
  @query_latest_block     Block.P2pMessage.query_latest_block
  @query_all_blocks       Block.P2pMessage.query_all_blocks
  @query_all_transactions   Block.P2pMessage.query_all_transactions
  # @update_block_chain Peers.P2pMessage.update_block_chain
  @add_peer_request   Block.P2pMessage.add_peer_request
  @connection_error   Block.P2pMessage.connection_error
  @connection_success Block.P2pMessage.connection_success

  def start_link(host, port) do
    GenSocketClient.start_link(
          __MODULE__,
          Phoenix.Channels.GenSocketClient.Transport.WebSocketClient,
          "ws://#{host}:#{port}/p2p/websocket"
        )
  end

  def init(url) do
    {:connect, url, [], %{}}
  end

  def join(_transport, _topic, _payload \\ %{}) do

  end

  def handle_connected(transport, state) do
    case :ets.lookup(:client, :transport) do
      [] -> :ets.insert(:client, {:transport, [transport]})
      transports ->
        :ets.insert(:client, {:transport, [transport] ++ transports |> hd |> elem(1)})
    end
    Logger.info("connected")
    GenSocketClient.join(transport, "p2p")
    {:ok, state}
  end

  def handle_disconnected(reason, state) do
    Logger.error("disconnected: #{inspect reason}. 20 minutes later attempting to reconnect...")
    {:ok, state}
  end

  def handle_joined(topic, _payload, transport, state) do
    Logger.info("joined the topic #{topic}.")
    GenSocketClient.push(transport, "p2p", @query_all_accounts, %{})
    {:ok, state}
  end

  def handle_join_error(topic, payload, _transport, state) do
    Logger.error("join error on the topic #{topic}: #{inspect payload}")
    {:ok, state}
  end

  def handle_channel_closed(topic, payload, _transport, state) do
    Logger.error("disconnected from the topic #{topic}: #{inspect payload}. Attempting to rejoin...")
    Process.send_after(self(), {:join, topic}, :timer.seconds(20000))
    {:ok, state}
  end

  def handle_message(topic, event, payload, _transport, state) do
    Logger.info("message on topic #{topic}: #{event} #{inspect payload}")
    {:ok, state}
  end

  def handle_reply("p2p", _ref, %{"response" => %{"type" => @connection_success}} = payload, _transport, state) do
    Logger.info("server ack ##{inspect payload["response"]}")
    {:ok, state}
  end

  def handle_reply("p2p", _ref, %{"response" => %{"type" => @connection_error}} = _payload, _transport, state) do
    Logger.info("connection to server failed...")
    P2pSessionManager.terminate_session(self())
    {:ok, state}
  end

  def handle_reply(_topic, _ref, payload, transport, state) do
    type = payload["response"]["type"]
    response = payload["response"]["data"]
    case type do
      "sync_block" ->
        if(Map.get(response, "hash") != Map.get(BlockService.get_latest_block, :hash))do
          GenSocketClient.push(transport, "p2p", @query_all_blocks, %{})
        end
      "get_latest_block" ->
        if(BlockService.get_latest_block == nil or Map.get(response, "hash") != Map.get(BlockService.get_latest_block, :hash))do
          GenSocketClient.push(transport, "p2p", @query_all_blocks, %{})
        else
          GenSocketClient.push(transport, "p2p", @query_all_transactions, %{})
        end
      "get_all_blocks" ->
        block_hashs = BlockRepository.get_all_block_hashs
        blocks = response
        |> Enum.reject(fn x -> x["hash"] in block_hashs end)
        #区块不全后同步其他部分
        if(blocks != [] and blocks != nil)do
          blocks|> Enum.each(fn x -> BlockRepository.insert_block(x) end)
          GenSocketClient.push(transport, "p2p", @query_all_transactions, %{})
        end
      "get_all_accounts" ->
        usernames = AccountRepository.get_all_usernames()
        response
        |> Enum.reject(fn x -> x["username"] in usernames end)
        |> Enum.each(fn x -> AccountRepository.insert_account(x) end)
        GenSocketClient.push(transport, "p2p", @query_latest_block, %{})
      "query_all_transactions" ->
        transactios_id = TransactionRepository.get_all_transactions_id()
        response
        |> Enum.reject(fn x -> x["transaction_id"] in transactios_id end)
        |> Enum.each(fn x -> TransactionRepository.insert_transaction(x) end)
        GenSocketClient.push(transport, "p2p", "other_sync",
          %{
            statorg_hash: SyncService.get_statorg_hash(),
            statcda_hash: SyncService.get_stat_cda_hash(),
            cda_hash: SyncService.get_cda_hash(),
            cda_file_hash: SyncService.get_cda_file_hash(),
            cdh_hash: SyncService.get_cah_hash(),
            ruleadrg_hash: SyncService.get_ruleadrg_hash(),
            cmp_hash: SyncService.get_cmp_hash(),
            cm_hash: SyncService.get_cm_hash(),
            ruledrg_hash: SyncService.get_ruledrg_hash(),
            ruleicd9_hash: SyncService.get_ruleicd9_hash(),
            ruleicd10_hash: SyncService.get_ruleicd10_hash(),
            rulemdc_hash: SyncService.get_rulemdc_hash(),
            libwt4_hash: SyncService.get_libwt4_hash(),
            wt4_hash: SyncService.get_wt4_hash()})
      "other_sync" ->
        Map.keys(response)
        |>Enum.each(fn k ->
            Enum.each(Map.get(response, k), fn x ->
              case k do
                "statorg_hash" ->
                  %BlockStatOrg{}
                  |>BlockStatOrg.changeset(x)
                "statcda_hash" ->
                  %BlockStatCda{}
                  |>BlockStatCda.changeset(x)
                "cda_hash" ->
                  %BlockCda{}
                  |>BlockCda.changeset(x)
                "cda_file_hash" ->
                  %BlockCdaFIle{}
                  |>BlockCdaFIle.changeset(x)
                "cdh_hash" ->
                  %BlockCdh{}
                  |>BlockCdh.changeset(x)
                "ruleadrg_hash" ->
                  %BlockRuleAdrg{}
                  |>BlockRuleAdrg.changeset(x)
                "cmp_hash" ->
                  %BlockChineseMedicinePatent{}
                  |>BlockChineseMedicinePatent.changeset(x)
                "cm_hash" ->
                  %BlockChineseMedicine{}
                  |>BlockChineseMedicine.changeset(x)
                "ruledrg_hash" ->
                  %BlockRuleDrg{}
                  |>BlockRuleDrg.changeset(x)
                "ruleicd9_hash" ->
                  %BlockRuleIcd9{}
                  |>BlockRuleIcd9.changeset(x)
                "ruleicd10_hash" ->
                  %BlockRuleIcd10{}
                  |>BlockRuleIcd10.changeset(x)
                "rulemdc_hash" ->
                  %BlockRuleMdc{}
                  |>BlockRuleMdc.changeset(x)
                "libwt4_hash" ->
                  %BlockLibWt4{}
                  |>BlockLibWt4.changeset(x)
                "wt4_hash" ->
                  %BlockWt4{}
                  |>BlockWt4.changeset(x)
              end
              |>Block.Repo.insert
            end)
        end)
        :timer.send_interval(10000, :ping)
    end
    {:ok, state}
  end

  def handle_info(:connect, _transport, state) do
    Logger.info("connecting")
    {:connect, state}
  end

  def handle_info(:ping, transport, state) do
    GenSocketClient.push(transport, "p2p", @sync_block, %{})
    {:ok, state}
  end

  def handle_info({:join, topic}, transport, state) do
    Logger.info("joining the topic #{topic}")
    case GenSocketClient.join(transport, topic) do
      {:error, reason} ->
        Logger.error("error joining the topic #{topic}: #{inspect reason}. Attempting to rejoin...")
        Process.send_after(self(), {:join, topic}, :timer.seconds(1))
      {:ok, _ref} -> :ok
    end

    {:ok, state}
  end

  def handle_info(@query_latest_block, transport, state) do
    Logger.info("quering for latest blocks")
    GenSocketClient.push(transport, "p2p", @query_latest_block, %{})
    {:ok, state}
  end

  def handle_info(@query_all_blocks, transport, state) do
    Logger.info("querying for all blocks")
    GenSocketClient.push(transport, "p2p", @query_all_blocks, %{})
    {:ok, state}
  end

  def handle_info(@add_peer_request, transport, state) do
    Logger.info("sending request to add me as a peer")
    local_server_host = Application.get_env(:oniichain, BlockWeb.Endpoint)[:url][:host]
    local_server_port = Application.get_env(:oniichain, BlockWeb.Endpoint)[:http][:port]
    GenSocketClient.push(transport, "p2p", @add_peer_request, %{host: local_server_host, port: local_server_port})
    {:ok, state}
  end

  def handle_info(message, _transport, state) do
    Logger.warn("Unhandled message #{inspect message}")
    {:ok, state}
  end

  def handle_call(_message, _arg1, _transport, _callback_state) do
    reply = :reply
    new_state = :new_state
    {:reply, reply, new_state}
  end
end
