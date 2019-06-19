alias Updates.QueryAnalyzer.Types.Quad, as: Quad

defmodule Delta do
  require Logger
  require ALog

  @type insert_type :: :update | :delete
  @type delta :: [{insert_type, [Quad.t()]}]

  @moduledoc """
  This service consumes altered triples and sends them to interested
  clients.  It runs in a separate thread and will always run *after*
  the response has been supplied to the client.
  """

  @doc """
  Publishes the updated quads.  The array is expected to contain
  tuples of form {insert_type, quads} in which insert_type is one of
  :insert or :delete.
  """
  @spec publish_updates(delta, [any], Plug.Conn.t()) :: delta
  def publish_updates(delta, authorization_groups, conn) do
    origin =
      conn
      |> Map.get(:remote_ip)
      |> Tuple.to_list()
      |> Enum.join(".")

    get_json_array_header = fn conn, header ->
      case Plug.Conn.get_req_header(conn, header) do
        [] ->
          []

        [value | _] ->
          # ignore extra values for now, they should not happen, but
          # if they do we don't want to crash either
          Poison.decode!(value)
      end
    end

    mu_call_id_trail =
      get_json_array_header.(conn, "mu-call-id-trail")
      |> Kernel.++(Plug.Conn.get_req_header(conn, "mu-call-id"))
      |> Poison.encode!()

    delta
    |> Delta.Message.construct(authorization_groups, origin)
    |> Logging.EnvLog.inspect(:log_delta_messages, label: "Constructed body for clients")
    |> Delta.Messenger.inform_clients(mu_call_id_trail: mu_call_id_trail)

    delta
  end
end
