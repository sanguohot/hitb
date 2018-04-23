defmodule BlockWeb.AccountController do
  use BlockWeb, :controller
  alias Hitb
  @moduledoc """
    Functionality for managing peers
  """

  def openAccount(conn, _) do
    if(conn.params["username"])do
      [conn, user] = BlockWeb.Login.login(conn, %{username: conn.params["username"]})
      json(conn, %{login: true, user: user})
    else
      json(conn, %{login: false, user: %{}})
    end
  end

  def openAccount2(conn, _) do
    json(conn, %{})
  end

  def getBalance(conn, _) do
    user = get_session(conn, :user)
    if(user.login)do
      balance = Account.getBalance(user.username)
      u_Balance = Account.getuBalance(user.username)
      json(conn, %{balance: balance, u_Balance: u_Balance})
    else
      json(conn, %{balance: 0, u_Balance: 0})
    end
  end

  def getPublicKey(conn, _) do
    user = get_session(conn, :user)
    if(user.login)do
      json(conn, %{publicKey: user.publicKey})
    else
      json(conn, %{publicKey: ""})
    end
  end

  def generatePublicKey(conn, %{"username" => username}) do
    publicKey = Account.generatePublickey(username)
    json(conn, %{publicKey: publicKey})
  end

  def getDelegates(conn, _) do
    json(conn, %{})
  end

  def getDelegatesFee(conn, _) do
    json(conn, %{})
  end

  def addDelegates(conn, _) do
    json(conn, %{})
  end

  def getAccount(conn, %{"username" => username}) do
    account = Repos.AccountRepository.get_account(username)
    json(conn, %{account: account})
  end

  def getAccountByPublicKey(conn, %{"publicKey" => publicKey}) do
    account = Repos.AccountRepository.get_account_by_publicKey(publicKey)
    json(conn, %{account: account})
  end

  def getAccountByAddress(conn, %{"address" => address}) do
    account = Repos.AccountRepository.get_account_by_address(address)
    json(conn, %{account: account})
  end

  def newAccount(conn, %{"username" => username}) do
    case username do
      "" -> json(conn, %{success: false, user: %{username: username}, info: "用户名未填写"})
      _ ->
        account = Account.newAccount(%{username: username, balance: 0})
        case account do
          false ->
            json(conn, %{success: false, user: %{username: username}, info: "用户名重复"})
          _ ->
            Repos.AccountRepository.insert_account(account)
            user = Repos.AccountRepository.get_account(username)
            json(conn, %{success: true, user: user, info: "用户创建成功"})
        end
    end
  end

  def addSignature(conn, %{"username" => username, "password" => password}) do
    [success, id] = Account.addSignature(username, password)
    [conn, _] = BlockWeb.Login.user(conn)
    json(conn, %{success:  success, transaction: id})
  end

  def getAccountsPublicKey(conn, _params) do
    [conn, user] = BlockWeb.Login.user(conn)
    publicKeys = Repos.AccountRepository.get_all_accounts() |> Enum.map(fn x -> x.publicKey end) |> List.delete(user.publicKey)
    json conn, %{publicKeys: publicKeys}
  end
end