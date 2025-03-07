defmodule API.Relay.SocketTest do
  use API.ChannelCase, async: true
  import API.Relay.Socket, except: [connect: 3]
  alias API.Relay.Socket
  alias Domain.Relays

  @connlib_version "0.1.1"

  @connect_info %{
    user_agent: "iOS/12.7 (iPhone) connlib/#{@connlib_version}",
    peer_data: %{address: {189, 172, 73, 001}},
    x_headers: [{"x-forwarded-for", "189.172.73.153"}],
    trace_context_headers: []
  }

  describe "connect/3" do
    test "returns error when token is missing" do
      assert connect(Socket, %{}, connect_info: @connect_info) == {:error, :missing_token}
    end

    test "creates a new relay" do
      token = Fixtures.Relays.create_token()
      encrypted_secret = Relays.encode_token!(token)

      attrs = connect_attrs(token: encrypted_secret)

      assert {:ok, socket} = connect(Socket, attrs, connect_info: @connect_info)
      assert relay = Map.fetch!(socket.assigns, :relay)

      assert relay.ipv4.address == attrs["ipv4"]
      assert relay.ipv6.address == attrs["ipv6"]
      assert relay.last_seen_user_agent == @connect_info.user_agent
      assert relay.last_seen_remote_ip.address == {189, 172, 73, 153}
      assert relay.last_seen_version == @connlib_version
    end

    test "propagates trace context" do
      token = Fixtures.Relays.create_token()
      encrypted_secret = Relays.encode_token!(token)
      attrs = connect_attrs(token: encrypted_secret)

      span_ctx = OpenTelemetry.Tracer.start_span("test")
      OpenTelemetry.Tracer.set_current_span(span_ctx)

      trace_context_headers = [
        {"traceparent", "00-a1bf53221e0be8000000000000000002-f316927eb144aa62-01"}
      ]

      connect_info = %{@connect_info | trace_context_headers: trace_context_headers}

      assert {:ok, _socket} = connect(Socket, attrs, connect_info: connect_info)
      assert span_ctx != OpenTelemetry.Tracer.current_span_ctx()
    end

    test "updates existing relay" do
      token = Fixtures.Relays.create_token()
      existing_relay = Fixtures.Relays.create_relay(token: token)
      encrypted_secret = Relays.encode_token!(token)

      attrs = connect_attrs(token: encrypted_secret, ipv4: existing_relay.ipv4)

      assert {:ok, socket} = connect(Socket, attrs, connect_info: @connect_info)
      assert relay = Repo.one(Domain.Relays.Relay)
      assert relay.id == socket.assigns.relay.id
    end

    test "returns error when token is invalid" do
      attrs = connect_attrs(token: "foo")
      assert connect(Socket, attrs, connect_info: @connect_info) == {:error, :invalid_token}
    end
  end

  describe "id/1" do
    test "creates a channel for a relay" do
      relay = Fixtures.Relays.create_relay()
      socket = socket(API.Relay.Socket, "", %{relay: relay})

      assert id(socket) == "relay:#{relay.id}"
    end
  end

  defp connect_attrs(attrs) do
    Fixtures.Relays.relay_attrs()
    |> Map.take(~w[ipv4 ipv6]a)
    |> Map.merge(Enum.into(attrs, %{}))
    |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)
  end
end
