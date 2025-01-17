defmodule WcaLive.Wca.RecordsStore do
  @moduledoc """
  A caching layer on top of `WcaLive.Wca.Records`.

  The server periodically fetches regional records from the WCA API
  and keeps them both in the memory and in a local file.
  Provides a fast way of accessing the records without
  making a web request. Also, by keeping them in a local file,
  it works even if the WCA API is down while the app gets restarted.
  """

  use GenServer

  require Logger

  alias WcaLive.Wca

  @name __MODULE__

  @type state :: %{
          records_map: Wca.Records.regional_records_map(),
          updated_at: DateTime.t()
        }

  @state_path "tmp/record-store.#{Mix.env()}.data"
  @update_interval_sec 1 * 60 * 60

  @records_key {__MODULE__, :records}
  @records_map_key {__MODULE__, :records_map}

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(@name, opts, name: @name)
  end

  @doc """
  Returns a cached version of regional records fetched from the WCA API.
  """
  @spec get_regional_records() :: list(Wca.Records.record())
  def get_regional_records() do
    :persistent_term.get(@records_key)
  end

  @doc """
  Returns a cached version of regional records map.
  """
  @spec get_regional_records_map() :: Wca.Records.records_map()
  def get_regional_records_map() do
    :persistent_term.get(@records_map_key)
  end

  # Callbacks

  @impl true
  def init(_) do
    state = get_initial_state!()

    updated_ago = DateTime.diff(DateTime.utc_now(), state.updated_at, :second)
    update_in = max(@update_interval_sec - updated_ago, 0)

    schedule_update(update_in)

    {:ok, state}
  end

  @impl true
  def handle_info(:update, state) do
    case update_state() do
      {:ok, new_state} ->
        log("Updated records.")
        schedule_update(@update_interval_sec)
        {:noreply, new_state}

      {:error, error} ->
        log("Update failed: #{error}.")
        schedule_update(@update_interval_sec)
        {:noreply, state}
    end
  end

  defp schedule_update(seconds) do
    # In 1 hour
    Process.send_after(self(), :update, seconds * 1000)
  end

  # Internal state management

  defp get_initial_state!() do
    if File.exists?(@state_path) do
      state = read_state!()
      put_state_in_persistent_term(state)
      state
    else
      case update_state() do
        {:ok, state} -> state
        {:error, message} -> raise RuntimeError, message: message
      end
    end
  end

  defp read_state!() do
    log("Reading state from file.")
    binary = File.read!(@state_path)
    :erlang.binary_to_term(binary)
  end

  defp write_state!(state) do
    log("Writing state to file.")
    File.mkdir_p!(Path.dirname(@state_path))
    binary = :erlang.term_to_binary(state)
    File.write!(@state_path, binary)
  end

  defp fetch_records() do
    log("Fetching fresh records.")
    Wca.Records.get_regional_records()
  end

  defp update_state() do
    with {:ok, records} <- fetch_records() do
      records_map = Wca.Records.records_to_map(records)

      state = %{
        records_map: records_map,
        records: records,
        updated_at: DateTime.utc_now()
      }

      put_state_in_persistent_term(state)

      write_state!(state)
      {:ok, state}
    end
  end

  defp put_state_in_persistent_term(state) do
    :persistent_term.put(@records_key, state.records)
    :persistent_term.put(@records_map_key, state.records_map)
  end

  defp log(message) do
    Logger.info("[RecordsStore] #{message}")
  end
end
