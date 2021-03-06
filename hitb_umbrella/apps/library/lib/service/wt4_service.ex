defmodule Library.Wt4Service do
  # import Ecto
  import Ecto.Query
  alias Hitb.Repo
  alias Hitb.Page
  alias Hitb.Library.Wt4

  def wt4(page) do
    skip = Page.skip(page, 15)
    result = from(w in Wt4)
      |> limit([w], 15)
      |> offset([w], ^skip)
      |> order_by([w], [asc: w.id])
      |> Repo.all
    count = hd(Repo.all(from p in Wt4, select: count(p.id)))
    [page_num, page_list, _count] = Page.page_list(page, count, 15)
    %{wt4: result, page_num: page_num, page_list: page_list, num: count, org_num: 0, time_num: 0, drg_num: 0}
  end

  def stat_wt4(time, org, drg, page) do
    skip = Page.skip(page, 15)
    query = from(w in Wt4) |> where([w], w.year_time == ^time or w.half_year == ^time or w.month_time == ^time or w.season_time == ^time)
    query = if(drg == "")do query else query |> where([w], w.drg == ^drg) end
    query = if(org == "")do query else query |> where([w], w.org == ^org) end
    count = query |> select([w], count(w.id)) |> Repo.all |> List.first
    result = query
      |> limit([w], 15)
      |> offset([w], ^skip)
      |> order_by([w], [asc: w.id])
      |> Repo.all
      |> Enum.map(fn x -> Map.drop(x, [:id, :__meta__, :__struct__]) end)
    result = Enum.map(result, fn x ->
        Enum.map([:b_wt4_v1_id, :disease_code, :diags_code, :opers_code, :acctual_days, :drg, :total_expense, :gender, :age], fn k -> if(k in [:diags_code, :opers_code])do Enum.join(Map.get(x, k), "-") else Map.get(x, k) end end)
      end)
    result = if(result == [])do [] else [["病案ID", "主要诊断", "其他诊断", "手术/操作", "住院天数", "病种", "费用", "性别", "年龄"]] end ++ result
    [page_num, page_list, page_count] = Page.page_list(page, count, 15)
    %{wt4: result, page: page_num, page_list: page_list, count: page_count, num: count, org_num: 0, time_num: 0, drg_num: 0}
  end
end
