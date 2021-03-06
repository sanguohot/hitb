defmodule HitbserverWeb.ClientController do
  use HitbserverWeb, :controller
  plug HitbserverWeb.Access
  alias Stat.ClientSaveService
  alias Stat.Key

  def stat_create(conn, %{"data" => data, "username" => username}) do
    result = ClientSaveService.stat_create(data, username)
    json conn, result
  end

  def stat_client(conn, _params) do
    %{"page" => page, "page_type" => page_type, "type" => type, "tool_type" => tool_type, "org" => org, "time" => time, "drg" => drg, "order" => order, "order_type" => order_type, "username" => username, "rows" => rows, "server_type" => server_type} = Map.merge(%{"page" => "1", "type" => "org", "tool_type" => "total", "org" => "", "time" => "", "drg" => "", "order" => "机构", "page_type" => "base", "order_type" => "asc", "username" => "", "rows" => 13, "server_type" => "server"}, conn.params)
    [time, org] =
      [time, org]
      |>Enum.map(fn x ->
          if(x == "全部")do "" else x end
        end)
    # [type, drg] =
    #   cond do
    #     type != "org" and drg == "全部" -> [type, ""]
    #     type == "org" and drg == "全部" -> ["drg", ""]
    #     type != "org" and drg == "-" -> ["org", ""]
    #     type == "org" and drg == "-" -> ["org", ""]
    #   end
    [type, drg] =
      case drg do
        "全部" -> ["drg", ""]
        "-" -> ["org", ""]
        _ -> [type, drg]
      end
    order = Key.enkey(order)
    result = ClientSaveService.stat_client(page, page_type, type, tool_type, org, time, drg, order, order_type, username, rows, server_type)
    json conn, result
  end

  def stat_info(conn, %{"username" => username}) do
    %{"page" => page, "page_type" => page_type, "type" => type, "tool_type" => tool_type, "org" => org, "time" => time, "drg" => drg, "order" => order, "order_type" => order_type, "server_type" => server_type} = Map.merge(%{"page" => "1", "type" => "org", "tool_type" => "total", "org" => "", "time" => "", "drg" => "", "order" => "机构", "page_type" => "base", "order_type" => "asc", "server_type" => "server"}, conn.params)
    order = Key.enkey(order)
    result = ClientSaveService.stat_info(page, type, tool_type, drg, order, order_type, page_type, org, time, username, server_type)
    json conn, result
  end

  def stat_file(conn, _params) do
    %{"name" => name, "username" => username, "server_type" => server_type} = Map.merge(%{"name" => "", "server_type" => "server"}, conn.params)
    result = ClientSaveService.stat_file(name, username, server_type)
    json conn, result
  end

  def download_client(conn, _params)do
    %{"page" => page, "page_type" => page_type, "type" => type, "tool_type" => tool_type, "org" => org, "time" => time, "drg" => drg, "order" => order, "order_type" => order_type, "username" => username} = Map.merge(%{"page" => "1", "type" => "org", "tool_type" => "total", "org" => "", "time" => "", "drg" => "", "order" => "机构", "page_type" => "base", "order_type" => "asc", "username" => ""}, conn.params)
    order = Key.enkey(order)
    result = ClientSaveService.clinet_download(page, page_type, type, tool_type, org, time, drg, order, order_type, username)
    json conn, %{stat: result}
  end

  def custom(conn, _params) do
    %{"custom" => custom, "username" => username}  = Map.merge(%{"custom" => "", "username" => ""}, conn.params)
    ClientSaveService.custom(custom, username)
    json conn, %{result: "自定义指标保存成功"}
  end
  def custom_select(conn, _params) do
    %{"username" => username, "tableName" => tableName}  = Map.merge(%{"username" => "", "tableName" => ""}, conn.params)
    ClientSaveService.custom_select(username, tableName)
    json conn, %{result: "自定义指标保存成功"}
  end


end
