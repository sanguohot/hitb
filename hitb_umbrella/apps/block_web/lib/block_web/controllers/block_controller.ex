defmodule BlockWeb.BlockController do
  use BlockWeb, :controller
  plug BlockWeb.Access
  alias Block
  alias BlockWeb.Login
  alias Block.BlockService
  alias Block.BlockRepository
  alias Block.TransactionRepository
  alias Repos
  @moduledoc """
    Functionality related to blocks in the block chain
  """

  def add_block(conn, payload) do
    [conn, user] = Login.user(conn)
    block = BlockService.create_next_block(payload["data"], user.username)
    BlockService.add_block(block)
    json(conn, %{})
  end

  def get_all_blocks(conn, _) do
    all_blocks =
    BlockRepository.get_all_blocks()
      |>Enum.map(fn x ->
          Map.put(x, :transactions, length(TransactionRepository.get_transactions_by_blockIndex(x.index)))
        end)
    all_blocks = Enum.map(all_blocks, fn x ->
      Map.drop(x, [:__meta__, :__struct__])
    end)
    json(conn,  %{blocks: all_blocks})
  end

  def getBlock(conn, %{"index" => index}) do
    block = BlockRepository.get_block(index)
    json(conn, %{block: block})
  end

  def getBlockByHash(conn, %{"hash" => hash}) do
    block = BlockRepository.get_block_by_hash(hash)
    json(conn, %{block: block})
  end

  def getFullBlock(conn, _) do
    json(conn, %{})
  end

  def getBlocks(conn, _) do
    json(conn, %{})
  end

  def getHeight(conn, _) do
    height = BlockRepository.get_all_blocks() |> List.last |> Map.get(:index)
    json(conn, %{height: height})
  end

  def getFee(conn, _) do
    json(conn, %{})
  end

  def getMilestone(conn, _) do
    json(conn, %{})
  end

  def getReward(conn, _) do
    json(conn, %{})
  end

  def getSupply(conn, _) do
    json(conn, %{})
  end

  def getStatus(conn, _) do
    json(conn, %{})
  end
end
