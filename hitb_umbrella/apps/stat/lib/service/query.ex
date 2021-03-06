defmodule Stat.Query do
  import Ecto.Query
  alias Stat.Key
  alias Stat.Convert
  alias Hitb.Repo, as: HitbRepo
  alias Block.Repo, as: BlockRepo
  alias Hitb.Stat.StatOrg, as: HitbStatOrg
  alias Hitb.Stat.StatDrg, as: HitbStatDrg
  alias Hitb.Stat.StatWt4, as: HitbStatWt4
  alias Hitb.Stat.StatOrgHeal, as: HitbStatOrgHeal
  alias Block.Stat.StatOrg, as: BlockStatOrg
  alias Block.Stat.StatDrg, as: BlockStatDrg
  alias Block.Stat.StatWt4, as: BlockStatWt4
  alias Block.Stat.StatOrgHeal, as: BlockStatOrgHeal
  #自定义取数据库
  def getstat(username, page, type, tool_type, org, time, drg, order, order_type, page_type, rows_num, stat_type, server_type) do
    repo = if(server_type == "server")do HitbRepo else BlockRepo end
    #获取各种keys
    key = Key.key(username, drg, type, tool_type, page_type) #英文key
    cnkey = Enum.map(key, fn x -> Key.cnkey(x) end) #中文key
    thkey = Enum.map(key, fn x -> %{cnkey: Key.cnkey(x), key: x} end) #表头key
    #取缓存stat
    cache_key = [page, type, org, time, drg, order, order_type, key, rows_num, Hitb.Time.sdata_date()]
    #分析获得
    [list, count, _skip, stat] =
      cond do
        stat_type == "download" ->
          order = String.to_atom(order)
          #获取query
          query = query(type, org, time, drg, server_type)
          stat =
            case order_type do
              "asc" -> order_by(query, [p], [asc: field(p, ^order)])|>repo.all
              "desc" -> order_by(query, [p], [desc: field(p, ^order)])|>repo.all
            end
          stat = [[cnkey]] ++ Convert.map2list(stat, key)
          [[], 0, 15, stat]
        Hitb.ets_get(:stat, cache_key) == nil ->
          order = String.to_atom(order)
          #获取左侧list
          list = list(type, org, time, server_type)
          #获取query
          query = query(type, org, time, drg, server_type)
          #取总数
          count = select(query, [p], count(p.id))|>repo.all([timeout: 1500000])|>List.last
          #求本页stat
          skip = Hitb.Page.skip(page, rows_num)
          stat =
            case order_type do
              "asc" -> order_by(query, [p], [asc: field(p, ^order)])|>limit([p], ^rows_num)|>offset([p], ^skip)|>repo.all
              "desc" -> order_by(query, [p], [desc: field(p, ^order)])|>limit([p], ^rows_num)|>offset([p], ^skip)|>repo.all
            end
          #缓存
          Hitb.ets_insert(:stat_drg, "defined_url_" <> username, [page, type, tool_type, drg, to_string(order), order_type, page_type, org, time])
          Hitb.ets_insert(:stat, cache_key, [list, count, skip, stat])
          [list, count, skip, stat]
        true ->
          Hitb.ets_get(:stat, cache_key)
      end
    # #求分页列表
    [page_num, page_list, count_page] = Hitb.Page.page_list(page, count, rows_num)
    # #按照字段取值
    # #如果有下载任务,进行下载查询
    # # stat = if(stat_type == "download")do stat else [] end
    # # 返回结果(分析结果, 列表, 页面工具, 页码列表, 当前页码, 字段, 中文字段, 表头字段)
    [stat, list, [], page_list, page_num, count_page, key, cnkey, thkey]
  end

  def info(username) do
    [_page, type, tool_type, drg, _order, _order_type, page_type, _org, _time] =
      case Hitb.ets_get(:stat_drg, "defined_url_" <> username) do
        nil -> ["1", "org", "total", "", "org", "asc", "base", "", ""]
        _ -> Hitb.ets_get(:stat_drg, "defined_url_" <> username)
      end
    case Hitb.ets_get(:stat_drg, "comx_" <> username) do
      nil -> [[], []]
      [] -> [[], []]
      _ ->
        stat = Hitb.ets_get(:stat_drg, "comx_" <> username)|>List.last
        mm_time = Convert.mm_time(stat.time)
        yy_time = Convert.yy_time(stat.time)
        #取缓存stat
        key = Key.key(username, drg, type, tool_type, page_type)
        #记录转换
        mm_record =
          case HitbRepo.get_by(Map.get(stat, :__struct__), time: mm_time, org: stat.org) do
            nil -> []
            x -> Map.merge(%{info_type: "环比记录"}, x)
          end
        yy_record =
          case HitbRepo.get_by(Map.get(stat, :__struct__), time: yy_time, org: stat.org) do
            nil -> []
            x -> Map.merge(%{info_type: "同比记录"}, x)
          end
        stat = [Map.merge(%{info_type: "当前记录"}, stat), mm_record, yy_record]|>Enum.reject(fn x -> x == [] end)
        #去除多余的key
        stat
        |>Enum.map(fn x ->
            Enum.map(["info_type"]++key, fn y -> String.to_atom(y) end)
            |>Enum.reduce(%{}, fn y, acc ->
                cond do
                  Map.get(x, y) == nil -> acc
                  is_float(Map.get(x, y)) -> Map.put(acc, y, Float.round(Map.get(x, y), 4))
                  true -> Map.put(acc, y, Map.get(x, y))
                end
            end)
          end)
    end
  end

  #左侧list
  def list(type, org, time, server_type) do
    repo = if(server_type == "server")do HitbRepo else BlockRepo end
    cache = Hitb.ets_get(:stat_list, [type, org, time, server_type])
    case cache do
      nil ->
        list =
          cond do
            type == "org" ->
              if(server_type == "server")do from(p in HitbStatOrg) else from(p in BlockStatOrg) end
              |>where([p], p.org_type == "org")|>select([p], fragment("distinct ?", p.org))
            type == "heal" ->
              if(server_type == "server")do from(p in HitbStatOrgHeal) else from(p in BlockStatOrgHeal) end
              |>department_where(org)|>select([p], fragment("distinct ?", p.org))
            type == "department" ->
              if(server_type == "server")do from(p in HitbStatOrg) else from(p in BlockStatOrg) end
              |>department_where(org)|>where([p], p.org_type == "department")|>select([p], fragment("distinct ?", p.org))
            type in ["mdc", "adrg", "drg"] ->
              if(server_type == "server")do from(p in HitbStatDrg) else from(p in BlockStatDrg) end
              |>mywhere(type, org, time)|>where([p], p.etype == ^type)|>select([p], p.drg2)|>group_by([p], p.drg2)
            type == "case" and String.contains? org, "_" ->
              query_org = hd(String.split(org, "_")) <> "_%"
              if(server_type == "server")do from(p in HitbStatWt4) else from(p in BlockStatWt4) end
              |>where([p], like(p.org, ^query_org))|>select([p], fragment("distinct ?", p.org))
            type == "case" ->
              if(server_type == "server")do from(p in HitbStatWt4) else from(p in BlockStatWt4) end
              |>where([p], p.org_type == "org")|>select([p], fragment("distinct ?", p.org))
            type == "time" ->
              if(server_type == "server")do from(p in HitbStatOrg) else from(p in BlockStatOrg) end
              |>select([p], fragment("distinct ?", p.time))
            type == "drg2" ->
              if(server_type == "server")do from(p in HitbStatDrg) else from(p in BlockStatDrg) end
              |>select([p], p.drg2)|>group_by([p], p.drg2)
            type in ["year_time", "month_time", "season_time", "half_year"] ->
              if(server_type == "server")do from(p in HitbStatOrg) else from(p in BlockStatOrg) end
              |>where([p], p.time_type == ^type)|>select([p], fragment("distinct ?", p.time))
            end
          |>repo.all
          |>Enum.sort
        Hitb.ets_insert(:stat_list, [type, org, time, server_type], list)
        list
      _ ->
      cache
    end
  end

  #生成查询语句
  defp query(type, org, time, drg, server_type) do
    cond do
      type in ["mdc", "adrg", "drg"] ->
        drg = if(type == "mdc")do String.split(drg, "-")|>List.first else drg end
        case server_type do
          "server" ->
            from(p in HitbStatDrg)
          "block" ->
            from(p in BlockStatDrg)
        end
        |>mywhere(type, org, time)
        |>where([p], p.etype == ^type)
        |>drgwhere(type, drg)
      type == "heal" ->
        myfrom(drg, server_type)|>mywhere(type, org, time)
      type == "case" ->
        case server_type do
          "server" ->
            from(p in HitbStatWt4)
          "block" ->
            from(p in BlockStatWt4)
        end
        |>mywhere(type, org, time)
      true ->
        cond do
          drg == "" and server_type == "server" -> from(p in HitbStatOrg)
          drg != "" and server_type == "server" -> from(p in HitbStatDrg)|>drgwhere(type, drg)
          drg == "" and server_type == "block" -> from(p in BlockStatOrg)
          drg != "" and server_type == "block" -> from(p in BlockStatDrg)|>drgwhere(type, drg)
        end
        |>mywhere(type, org, time)
    end
  end

  #表判断
  defp myfrom(drg, server_type) do
    cond do
      drg == "" and server_type == "server" -> from(p in HitbStatOrgHeal)
      drg == "" and server_type == "block" -> from(p in BlockStatOrgHeal)
      server_type == "server" -> from(p in HitbStatOrgHeal)
      server_type == "block" -> from(p in BlockStatOrgHeal)
    end
  end

  #科室排除查询
  defp department_where(w, org) do
    cond do
      org == "" -> w
      true ->
        org = if(String.contains? org, "_")do hd(String.split(org, "_")) <> "_%" else org <> "_%" end
        where(w, [p], like(p.org, ^org))
    end
  end

  #drg排除查询
  defp drgwhere(w, type, code) do
    case code do
      "" -> w
      "全部" -> w
      _ ->
        code = if(String.contains? code, "-")do String.split(code, "-")|>hd else code end
        case type do
          "heal" ->
            code = code <> "%"
            where(w, [p], like(p.drg, ^code))
           _ ->
            cond do
              type in ["drg", "adrg", "mdc"] ->
                where(w, [p], p.drg == ^code and p.etype == ^type)
              true ->
                where(w, [p], p.drg == ^code)
            end
        end
    end
  end

  #排除查询
  defp mywhere(w, type, org, time) do
    w =
      case org do
        "" ->
          cond do
            type in ["org", "department"] -> where(w, [p], p.org_type == ^type)
            true -> where(w, [p], p.org_type == "org")
          end
        _ ->
          case type do
            "org" ->
              case String.contains? org, "_" do
                true -> where(w, [p], p.org_type == "org")
                false -> where(w, [p], p.org_type == "org" and p.org == ^org)
              end
            "department" ->
              query_org = if(String.contains? org, "_")do org else org <> "_%" end
              where(w, [p], p.org_type == "department" and like(p.org, ^query_org))
            _ ->
              case String.contains? org, "_" do
                true -> where(w, [p], p.org_type == "department" and like(p.org, ^org))
                false -> where(w, [p], p.org_type == "org" and p.org == ^org)
              end
          end
      end
    case time do
      "" ->
        cond do
          type in ["year_time", "half_year", "season_time", "month_time"] ->
            where(w, [p], p.time_type == ^type)
          true ->
            w
        end
      _ ->
        case type in ["year_time", "half_year", "season_time", "month_time"] do
          true ->  where(w, [p], p.time == ^time and p.time_type == ^type)
          false -> where(w, [p], p.time == ^time)
        end
    end
  end

end
