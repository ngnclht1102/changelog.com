defmodule ChangelogWeb.NewsItemController do
  use ChangelogWeb, :controller

  alias Changelog.{Hashid, NewsItem, NewsSponsorship}
  alias ChangelogWeb.NewsItemView

  plug RequireAdmin, "before preview" when action in [:preview]

  def index(conn, params) do
    pinned =
      NewsItem
      |> NewsItem.published
      |> NewsItem.pinned
      |> NewsItem.newest_first
      |> NewsItem.preload_all
      |> Repo.all
      |> Enum.map(&NewsItem.load_object/1)

    page =
      NewsItem
      |> NewsItem.published
      |> NewsItem.unpinned
      |> NewsItem.newest_first
      |> NewsItem.preload_all
      |> Repo.paginate(Map.put(params, :page_size, 15))

    ads =
      Timex.today
      |> NewsSponsorship.week_of
      |> NewsSponsorship.preload_all
      |> Repo.all
      |> Enum.take_random(2)
      |> Enum.map(&NewsSponsorship.ad_for_index/1)
      |> Enum.reject(&is_nil/1)

    items =
      page.entries
      |> Enum.map(&NewsItem.load_object/1)

    render(conn, :index, ads: ads, pinned: pinned, items: items, page: page)
  end

  def show(conn, %{"id" => slug}) do
    hashid = slug |> String.split("-") |> List.last
    item = hashid |> item_from_hashid |> NewsItem.preload_all |> NewsItem.load_object

    if slug == hashid do
      redirect(conn, to: news_item_path(conn, :show, NewsItemView.slug(item)))
    else
      render(conn, :show, item: item)
    end
  end

  def impress(conn, %{"items" => hashids}) do
    hashids
    |> String.split(",")
    |> Enum.each(fn(hashid) ->
      hashid |> item_from_hashid |> NewsItem.track_impression
    end)

    send_resp(conn, 200, "")
  end

  def visit(conn, %{"id" => hashid}) do
    item = item_from_hashid(hashid)
    NewsItem.track_click(item)
    redirect(conn, external: item.url)
  end

  def preview(conn, %{"id" => id}) do
    item =
      NewsItem
      |> Repo.get_by!(id: id)
      |> NewsItem.preload_all
      |> NewsItem.load_object

    render(conn, :show, item: item)
  end

  defp item_from_hashid(hashid) do
    NewsItem.published
    |> Repo.get_by!(id: Hashid.decode(hashid))
  end
end
